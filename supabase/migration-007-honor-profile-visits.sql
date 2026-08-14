-- Aura 67: identidade pública, sistema inicial de Honra e visitas protegidas.
-- Execute no ambiente de TESTE depois da migration 006.

alter table public.profiles
  add column if not exists honor_points bigint not null default 0 check (honor_points >= 0),
  add column if not exists profile_visit_count bigint not null default 0 check (profile_visit_count >= 0);

revoke update (honor_points, profile_visit_count) on public.profiles from authenticated;

create table if not exists public.honor_categories (
  id text primary key, name text not null, description text not null,
  icon text not null, display_order smallint not null default 0
);

insert into public.honor_categories (id, name, description, icon, display_order) values
  ('inspirador', 'Inspirador', 'Incentiva outras pessoas a evoluírem.', '✦', 1),
  ('prestativo', 'Prestativo', 'Ajuda a comunidade de forma genuína.', '🤝', 2),
  ('confiavel', 'Confiável', 'Age com consistência e cumpre sua palavra.', '◆', 3),
  ('respeitoso', 'Respeitoso', 'Trata as pessoas com empatia e respeito.', '♡', 4),
  ('encorajador', 'Encorajador', 'Reconhece o esforço de quem está ao redor.', '↑', 5)
on conflict (id) do update set name=excluded.name, description=excluded.description,
  icon=excluded.icon, display_order=excluded.display_order;

create table if not exists public.honor_endorsements (
  id bigint generated always as identity primary key,
  giver_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  category_id text not null references public.honor_categories(id),
  period_start date not null,
  created_at timestamptz not null default now(),
  check (giver_id <> receiver_id),
  unique (giver_id, receiver_id, category_id, period_start)
);
create index if not exists honor_endorsements_receiver_idx on public.honor_endorsements(receiver_id, created_at desc);
create index if not exists honor_endorsements_giver_period_idx on public.honor_endorsements(giver_id, period_start);

create table if not exists public.profile_visits (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  visited_on date not null,
  created_at timestamptz not null default now(),
  check (profile_id <> visitor_id),
  unique (profile_id, visitor_id, visited_on)
);
create index if not exists profile_visits_profile_date_idx on public.profile_visits(profile_id, visited_on desc);

alter table public.honor_categories enable row level security;
alter table public.honor_endorsements enable row level security;
alter table public.profile_visits enable row level security;
drop policy if exists "Categorias de honra são públicas" on public.honor_categories;
create policy "Categorias de honra são públicas" on public.honor_categories for select to anon, authenticated using (true);
revoke all on public.honor_endorsements, public.profile_visits from anon, authenticated;
grant select on public.honor_categories to anon, authenticated;

create or replace function public.honor_level(p_points bigint)
returns text language sql immutable set search_path='' as $$
  select case when coalesce(p_points,0)>=500 then 'Honra Lendária'
    when coalesce(p_points,0)>=200 then 'Honra Exemplar'
    when coalesce(p_points,0)>=75 then 'Honra Elevada'
    when coalesce(p_points,0)>=20 then 'Honra Reconhecida'
    else 'Honra Inicial' end;
$$;

create or replace function public.record_profile_visit(p_profile_id uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_visitor uuid:=auth.uid(); v_inserted integer:=0; v_total bigint;
begin
  if v_visitor is null then raise exception 'É necessário entrar para registrar uma visita'; end if;
  if p_profile_id=v_visitor then select profile_visit_count into v_total from public.profiles where id=p_profile_id; return coalesce(v_total,0); end if;
  if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Perfil não encontrado'; end if;
  insert into public.profile_visits(profile_id,visitor_id,visited_on)
  values(p_profile_id,v_visitor,timezone('UTC',now())::date) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=1 then
    update public.profiles set profile_visit_count=profile_visit_count+1 where id=p_profile_id returning profile_visit_count into v_total;
  else select profile_visit_count into v_total from public.profiles where id=p_profile_id;
  end if;
  return coalesce(v_total,0);
end;
$$;

create or replace function public.give_honor(p_receiver_id uuid,p_category_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_giver uuid:=auth.uid(); v_period date:=(date_trunc('week',timezone('UTC',now())))::date; v_used integer; v_total bigint;
begin
  if v_giver is null then raise exception 'É necessário entrar para conceder Honra'; end if;
  if v_giver=p_receiver_id then raise exception 'Você não pode conceder Honra a si mesmo'; end if;
  if not exists(select 1 from public.profiles where id=p_receiver_id) then raise exception 'Perfil não encontrado'; end if;
  if not exists(select 1 from public.honor_categories where id=p_category_id) then raise exception 'Categoria de Honra inválida'; end if;
  select count(*) into v_used from public.honor_endorsements where giver_id=v_giver and period_start=v_period;
  if v_used>=3 then raise exception 'Você já utilizou suas 3 Honras desta semana'; end if;
  insert into public.honor_endorsements(giver_id,receiver_id,category_id,period_start) values(v_giver,p_receiver_id,p_category_id,v_period);
  update public.profiles set honor_points=honor_points+1 where id=p_receiver_id returning honor_points into v_total;
  return jsonb_build_object('honor_points',v_total,'honor_level',public.honor_level(v_total),'remaining_this_week',2-v_used);
exception when unique_violation then raise exception 'Você já concedeu esta Honra para essa pessoa nesta semana';
end;
$$;

create or replace function public.public_profile_identity(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
 'profile',jsonb_build_object('id',p.id,'full_name',p.full_name,'username',p.username,'bio',p.bio,'avatar_url',p.avatar_url,'cover_url',p.cover_url,'theme_color',p.theme_color,'aura_points',p.aura_points,'honor_points',p.honor_points,'honor_level',public.honor_level(p.honor_points),'profile_visit_count',p.profile_visit_count,'member_number',p.member_number),
 'achievements',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'description',a.description,'icon',a.icon,'rarity',a.rarity,'awarded_at',ua.awarded_at) order by ua.awarded_at desc) from public.user_achievements ua join public.achievements a on a.id=ua.achievement_id where ua.user_id=p.id),'[]'::jsonb),
 'honors',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'icon',c.icon,'count',h.total) order by c.display_order) from (select category_id,count(*)::bigint total from public.honor_endorsements where receiver_id=p.id group by category_id) h join public.honor_categories c on c.id=h.category_id),'[]'::jsonb)
) from public.profiles p where p.id=p_profile_id;
$$;

create or replace function public.honor_ranking(p_limit integer default 50,p_offset integer default 0)
returns table(id uuid,full_name text,username text,avatar_url text,theme_color text,honor_points bigint,honor_level text,ranking_position bigint)
language sql stable security definer set search_path='' as $$
 select p.id,p.full_name,p.username,p.avatar_url,p.theme_color,p.honor_points,public.honor_level(p.honor_points),rank() over(order by p.honor_points desc,p.created_at asc)::bigint
 from public.profiles p order by p.honor_points desc,p.created_at asc
 limit least(greatest(coalesce(p_limit,50),1),100) offset greatest(coalesce(p_offset,0),0);
$$;

revoke all on function public.record_profile_visit(uuid) from public,anon;
revoke all on function public.give_honor(uuid,text) from public,anon;
revoke all on function public.public_profile_identity(uuid) from public;
revoke all on function public.honor_ranking(integer,integer) from public;
grant execute on function public.record_profile_visit(uuid) to authenticated;
grant execute on function public.give_honor(uuid,text) to authenticated;
grant execute on function public.public_profile_identity(uuid) to anon,authenticated;
grant execute on function public.honor_ranking(integer,integer) to anon,authenticated;
