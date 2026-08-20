-- Aura 67: pessoas seguidas, feed pessoal e contagem coerente de Fogos.
-- Execute depois da migration 033.

create table if not exists public.profile_follows(
 follower_id uuid not null references public.profiles(id) on delete cascade,
 followed_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(follower_id,followed_id),check(follower_id<>followed_id)
);
create index if not exists profile_follows_followed_idx on public.profile_follows(followed_id,created_at desc);
alter table public.profile_follows enable row level security;
revoke all on public.profile_follows from anon,authenticated;

create or replace function public.get_profile_follow_state(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('following',exists(select 1 from public.profile_follows where follower_id=auth.uid() and followed_id=p_profile_id),
  'followers',(select count(*) from public.profile_follows where followed_id=p_profile_id),
  'following_count',(select count(*) from public.profile_follows where follower_id=p_profile_id),
  'is_own_profile',p_profile_id=auth.uid());
$$;

create or replace function public.toggle_profile_follow(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_following boolean;v_followers bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if v_user=p_profile_id then raise exception 'Você não pode seguir o próprio perfil';end if;
 if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Perfil não encontrado';end if;
 if exists(select 1 from public.profile_follows where follower_id=v_user and followed_id=p_profile_id) then delete from public.profile_follows where follower_id=v_user and followed_id=p_profile_id;v_following:=false;
 else insert into public.profile_follows(follower_id,followed_id) values(v_user,p_profile_id);v_following:=true;end if;
 select count(*) into v_followers from public.profile_follows where followed_id=p_profile_id;
 return jsonb_build_object('following',v_following,'followers',v_followers);
end;$$;

create or replace function public.get_profile_firework_stats(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 with direct as(select coalesce(sum(f.fire_count),0)::bigint fires from public.profile_fireworks f where f.profile_id=p_profile_id),
 moments as(select count(*)::bigint fires from public.aura_moment_fires f join public.aura_moments m on m.id=f.moment_id where m.user_id=p_profile_id),
 people as(select sender_id from public.profile_fireworks where profile_id=p_profile_id and fire_count>0 union select f.sender_id from public.aura_moment_fires f join public.aura_moments m on m.id=f.moment_id where m.user_id=p_profile_id)
 select jsonb_build_object('fire_count',(select fires from direct)+(select fires from moments),'people_count',(select count(*) from people),'is_own_profile',p_profile_id=auth.uid());
$$;

create or replace function public.get_aura_moments(p_limit integer default 20,p_before timestamptz default null)
returns table(id uuid,user_id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,theme_color text,aura_points bigint,member_number bigint,title text,icon text,dimension text,verification text,points_snapshot integer,created_at timestamptz,fire_count bigint,viewer_fired boolean)
language sql stable security definer set search_path='' as $$
 select m.id,m.user_id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,p.aura_points,p.member_number,m.title,m.icon,m.dimension,m.verification,m.points_snapshot,m.created_at,
  (select count(*) from public.aura_moment_fires f where f.moment_id=m.id),exists(select 1 from public.aura_moment_fires f where f.moment_id=m.id and f.sender_id=auth.uid())
 from public.aura_moments m join public.profiles p on p.id=m.user_id
 where (m.user_id=auth.uid() or exists(select 1 from public.profile_follows pf where pf.follower_id=auth.uid() and pf.followed_id=m.user_id))
 and (p_before is null or m.created_at<p_before) order by m.created_at desc limit least(greatest(coalesce(p_limit,20),1),50);
$$;

create or replace function public.toggle_aura_moment_fire(p_moment_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_owner uuid;v_active boolean;v_total bigint;v_last_rewarded date;v_today date:=timezone('America/Sao_Paulo',now())::date;v_aura integer:=0;v_honor integer:=0;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select user_id into v_owner from public.aura_moments where id=p_moment_id;if not found then raise exception 'Momento não encontrado';end if;
 if v_owner=v_user then select count(*) into v_total from public.aura_moment_fires where moment_id=p_moment_id;return jsonb_build_object('active',false,'fire_count',v_total,'own_moment',true);end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text||':'||v_user::text,0));
 if exists(select 1 from public.aura_moment_fires where moment_id=p_moment_id and sender_id=v_user) then delete from public.aura_moment_fires where moment_id=p_moment_id and sender_id=v_user;v_active:=false;
 else
  insert into public.aura_moment_fires(moment_id,sender_id) values(p_moment_id,v_user);v_active:=true;
  select last_rewarded_on into v_last_rewarded from public.profile_fireworks where profile_id=v_owner and sender_id=v_user for update;
  if v_last_rewarded is distinct from v_today then v_aura:=5;v_honor:=1;end if;
  insert into public.profile_fireworks(profile_id,sender_id,fire_count,last_sent_at,last_rewarded_on) values(v_owner,v_user,0,now(),case when v_aura>0 then v_today else v_last_rewarded end)
  on conflict(profile_id,sender_id) do update set last_sent_at=now(),last_rewarded_on=case when v_aura>0 then v_today else public.profile_fireworks.last_rewarded_on end;
  if v_aura>0 then insert into public.profile_firework_events(profile_id,sender_id,aura_reward,honor_reward) values(v_owner,v_user,v_aura,v_honor);end if;
 end if;
 select count(*) into v_total from public.aura_moment_fires where moment_id=p_moment_id;
 return jsonb_build_object('active',v_active,'fire_count',v_total,'own_moment',false);
end;$$;

revoke all on function public.get_profile_follow_state(uuid),public.toggle_profile_follow(uuid) from public,anon;
grant execute on function public.get_profile_follow_state(uuid),public.toggle_profile_follow(uuid) to authenticated;
