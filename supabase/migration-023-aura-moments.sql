-- Aura 67: Feed público de Momentos de Aura com publicação voluntária.
-- Execute depois da migration 022.

create table if not exists public.aura_moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  source_type text not null check(source_type in ('action','project')),
  source_id text not null,
  title text not null check(char_length(title) between 2 and 100),
  icon text not null default '✦',
  dimension text not null check(dimension in ('acao','constancia','coragem','impacto')),
  verification text not null check(verification in ('registrada','comprovada','sistema')),
  points_snapshot integer not null default 0 check(points_snapshot between 0 and 500),
  created_at timestamptz not null default now(),
  unique(user_id,source_type,source_id)
);
create index if not exists aura_moments_feed_idx on public.aura_moments(created_at desc);

create table if not exists public.aura_moment_fires (
  moment_id uuid not null references public.aura_moments(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(moment_id,sender_id)
);
create index if not exists aura_moment_fires_moment_idx on public.aura_moment_fires(moment_id);

alter table public.aura_moments enable row level security;
alter table public.aura_moment_fires enable row level security;
revoke all on public.aura_moments,public.aura_moment_fires from anon,authenticated;

create or replace function public.publish_aura_moment(p_source_type text,p_source_id text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_id uuid;v_title text;v_icon text:='✦';v_dimension text;v_verification text;v_points integer:=0;v_action_id bigint;v_action_date date;v_project_id uuid;v_project public.user_projects%rowtype;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if p_source_type='action' then
  begin v_action_id:=split_part(p_source_id,':',1)::bigint;v_action_date:=split_part(p_source_id,':',2)::date;exception when others then raise exception 'Ação inválida';end;
  select a.title,a.icon,case when a.category='social' then 'impacto' when a.difficulty in ('hard','special') then 'coragem' else 'acao' end,
   case when exists(select 1 from public.action_proofs pr where pr.user_id=v_user and pr.action_id=a.id and pr.submitted_on=c.completed_on and pr.status='approved') then 'comprovada' else 'registrada' end,
   c.base_xp+c.bonus_xp
  into v_title,v_icon,v_dimension,v_verification,v_points
  from public.action_completions c join public.actions_catalog a on a.id=c.action_id
  where c.user_id=v_user and c.action_id=v_action_id and c.completed_on=v_action_date order by c.created_at desc limit 1;
  if not found then raise exception 'Conclua a ação antes de publicar';end if;
 elsif p_source_type='project' then
  begin v_project_id:=p_source_id::uuid;exception when others then raise exception 'Projeto inválido';end;
  select * into v_project from public.user_projects where id=v_project_id and user_id=v_user and status='completed';
  if not found then raise exception 'Somente projetos concluídos podem virar Momentos';end if;
  v_title:='Concluiu o projeto “'||left(v_project.title,72)||'”';v_icon:='🏆';v_dimension:='constancia';v_verification:='sistema';
  select coalesce(sum(points),0)::integer into v_points from public.project_point_events where project_id=v_project_id;
 else raise exception 'Tipo de Momento inválido';end if;
 insert into public.aura_moments(user_id,source_type,source_id,title,icon,dimension,verification,points_snapshot)
 values(v_user,p_source_type,p_source_id,v_title,v_icon,v_dimension,v_verification,least(v_points,500))
 on conflict(user_id,source_type,source_id) do update set title=excluded.title
 returning id into v_id;
 return v_id;
end;$$;

create or replace function public.get_aura_moments(p_limit integer default 20,p_before timestamptz default null)
returns table(id uuid,user_id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,theme_color text,aura_points bigint,member_number bigint,title text,icon text,dimension text,verification text,points_snapshot integer,created_at timestamptz,fire_count bigint,viewer_fired boolean)
language sql stable security definer set search_path='' as $$
 select m.id,m.user_id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,p.aura_points,p.member_number,m.title,m.icon,m.dimension,m.verification,m.points_snapshot,m.created_at,
  (select count(*) from public.aura_moment_fires f where f.moment_id=m.id),
  exists(select 1 from public.aura_moment_fires f where f.moment_id=m.id and f.sender_id=auth.uid())
 from public.aura_moments m join public.profiles p on p.id=m.user_id
 where p_before is null or m.created_at<p_before order by m.created_at desc limit least(greatest(coalesce(p_limit,20),1),50);
$$;

create or replace function public.toggle_aura_moment_fire(p_moment_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_owner uuid;v_active boolean;v_total bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select user_id into v_owner from public.aura_moments where id=p_moment_id;if not found then raise exception 'Momento não encontrado';end if;
 if v_owner=v_user then select count(*) into v_total from public.aura_moment_fires where moment_id=p_moment_id;return jsonb_build_object('active',false,'fire_count',v_total,'own_moment',true);end if;
 if exists(select 1 from public.aura_moment_fires where moment_id=p_moment_id and sender_id=v_user) then
  delete from public.aura_moment_fires where moment_id=p_moment_id and sender_id=v_user;v_active:=false;
 else
  insert into public.aura_moment_fires(moment_id,sender_id) values(p_moment_id,v_user);v_active:=true;
 end if;
 select count(*) into v_total from public.aura_moment_fires where moment_id=p_moment_id;
 return jsonb_build_object('active',v_active,'fire_count',v_total,'own_moment',v_owner=v_user);
end;$$;

create or replace function public.delete_aura_moment(p_moment_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin delete from public.aura_moments where id=p_moment_id and user_id=auth.uid();return found;end;$$;

revoke all on function public.publish_aura_moment(text,text) from public,anon;
revoke all on function public.get_aura_moments(integer,timestamptz) from public,anon;
revoke all on function public.toggle_aura_moment_fire(uuid) from public,anon;
revoke all on function public.delete_aura_moment(uuid) from public,anon;
grant execute on function public.publish_aura_moment(text,text) to authenticated;
grant execute on function public.get_aura_moments(integer,timestamptz) to authenticated;
grant execute on function public.toggle_aura_moment_fire(uuid) to authenticated;
grant execute on function public.delete_aura_moment(uuid) to authenticated;
