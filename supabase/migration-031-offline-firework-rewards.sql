-- Aura 67: recebimento de Fogos enviados enquanto a pessoa estava offline.
-- Execute depois da migration 030.

alter table public.profile_fireworks
  add column if not exists last_rewarded_on date;

create table if not exists public.profile_firework_events (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  aura_reward integer not null default 0 check (aura_reward between 0 and 5),
  honor_reward integer not null default 0 check (honor_reward between 0 and 1),
  created_at timestamptz not null default now(),
  received_at timestamptz,
  check (profile_id <> sender_id)
);

create index if not exists profile_firework_events_pending_idx
  on public.profile_firework_events(profile_id, created_at)
  where received_at is null;

alter table public.profile_firework_events enable row level security;
revoke all on public.profile_firework_events from anon, authenticated;

create or replace function public.send_profile_firework(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_sender uuid:=auth.uid();
  v_last timestamptz;
  v_last_rewarded date;
  v_today date:=(timezone('America/Sao_Paulo',now()))::date;
  v_aura integer:=0;
  v_honor integer:=0;
  v_fires bigint;
  v_people bigint;
begin
  if v_sender is null then raise exception 'Entre na Aura para enviar Fogos'; end if;
  if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Perfil não encontrado'; end if;
  if v_sender=p_profile_id then return public.get_profile_firework_stats(p_profile_id); end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_profile_id::text||':'||v_sender::text,0)
  );

  select last_sent_at,last_rewarded_on into v_last,v_last_rewarded
  from public.profile_fireworks
  where profile_id=p_profile_id and sender_id=v_sender for update;

  if v_last is not null and v_last>now()-interval '3 seconds' then
    raise exception 'Espere alguns segundos antes de enviar outro Fogo';
  end if;

  if v_last_rewarded is distinct from v_today then
    v_aura:=5;
    v_honor:=1;
  end if;

  insert into public.profile_fireworks(profile_id,sender_id,fire_count,last_sent_at,last_rewarded_on)
  values(p_profile_id,v_sender,1,now(),case when v_aura>0 then v_today else v_last_rewarded end)
  on conflict(profile_id,sender_id) do update set
    fire_count=public.profile_fireworks.fire_count+1,
    last_sent_at=now(),
    last_rewarded_on=case when v_aura>0 then v_today else public.profile_fireworks.last_rewarded_on end;

  insert into public.profile_firework_events(profile_id,sender_id,aura_reward,honor_reward)
  values(p_profile_id,v_sender,v_aura,v_honor);

  select coalesce(sum(fire_count),0),count(sender_id) into v_fires,v_people
  from public.profile_fireworks where profile_id=p_profile_id;
  return jsonb_build_object('fire_count',v_fires,'people_count',v_people,'is_own_profile',false);
end;
$$;

create or replace function public.claim_my_offline_fireworks()
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid();
  v_fires bigint:=0;
  v_aura bigint:=0;
  v_honor bigint:=0;
  v_total_aura bigint:=0;
  v_total_honor bigint:=0;
begin
  if v_user is null then raise exception 'Entre na Aura para receber seus Fogos'; end if;

  with pending as (
    select aura_reward,honor_reward
    from public.profile_firework_events
    where profile_id=v_user and received_at is null
    for update
  )
  select count(*),coalesce(sum(aura_reward),0),coalesce(sum(honor_reward),0)
  into v_fires,v_aura,v_honor from pending;

  if v_fires=0 then
    return jsonb_build_object('fire_count',0,'aura_earned',0,'honor_earned',0);
  end if;

  update public.profile_firework_events
  set received_at=now()
  where profile_id=v_user and received_at is null;

  update public.profiles
  set aura_points=aura_points+v_aura,
      honor_points=honor_points+v_honor
  where id=v_user
  returning aura_points,honor_points into v_total_aura,v_total_honor;

  return jsonb_build_object(
    'fire_count',v_fires,
    'aura_earned',v_aura,
    'honor_earned',v_honor,
    'total_aura',v_total_aura,
    'total_honor',v_total_honor
  );
end;
$$;

revoke all on function public.claim_my_offline_fireworks() from public,anon;
grant execute on function public.claim_my_offline_fireworks() to authenticated;
