-- Aura 67: Fogos sociais nos perfis.
-- Execute depois da migration 021.

create table if not exists public.profile_fireworks (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  fire_count bigint not null default 0 check (fire_count >= 0),
  last_sent_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (profile_id, sender_id),
  check (profile_id <> sender_id)
);

create index if not exists profile_fireworks_total_idx on public.profile_fireworks(profile_id);
alter table public.profile_fireworks enable row level security;
revoke all on public.profile_fireworks from anon, authenticated;

create or replace function public.get_profile_firework_stats(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
  'fire_count',coalesce(sum(f.fire_count),0),
  'people_count',count(f.sender_id),
  'is_own_profile',p_profile_id=auth.uid()
) from public.profile_fireworks f where f.profile_id=p_profile_id;
$$;

create or replace function public.send_profile_firework(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_sender uuid:=auth.uid(); v_last timestamptz; v_fires bigint; v_people bigint;
begin
  if v_sender is null then raise exception 'Entre na Aura para enviar Fogos'; end if;
  if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Perfil não encontrado'; end if;
  if v_sender=p_profile_id then return public.get_profile_firework_stats(p_profile_id); end if;

  select last_sent_at into v_last from public.profile_fireworks
  where profile_id=p_profile_id and sender_id=v_sender for update;
  if v_last is not null and v_last>now()-interval '3 seconds' then
    raise exception 'Espere alguns segundos antes de enviar outro Fogo';
  end if;

  insert into public.profile_fireworks(profile_id,sender_id,fire_count,last_sent_at)
  values(p_profile_id,v_sender,1,now())
  on conflict(profile_id,sender_id) do update
    set fire_count=public.profile_fireworks.fire_count+1,last_sent_at=now();

  select coalesce(sum(fire_count),0),count(sender_id) into v_fires,v_people
  from public.profile_fireworks where profile_id=p_profile_id;
  return jsonb_build_object('fire_count',v_fires,'people_count',v_people,'is_own_profile',false);
end;
$$;

revoke all on function public.get_profile_firework_stats(uuid) from public,anon;
revoke all on function public.send_profile_firework(uuid) from public,anon;
grant execute on function public.get_profile_firework_stats(uuid) to authenticated;
grant execute on function public.send_profile_firework(uuid) to authenticated;
