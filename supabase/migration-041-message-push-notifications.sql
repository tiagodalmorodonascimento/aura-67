-- Aura 67: tokens nativos e controle de entrega para notificações de mensagens.
-- Execute depois da migration 040.

create table if not exists public.mobile_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android' check (platform in ('android','ios')),
  device_info text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mobile_push_tokens_user_active_idx
  on public.mobile_push_tokens(user_id,active);

create table if not exists public.message_push_deliveries (
  id bigint generated always as identity primary key,
  message_id bigint not null references public.direct_messages(id) on delete cascade,
  token_id uuid not null references public.mobile_push_tokens(id) on delete cascade,
  status text not null check (status in ('sent','failed')),
  provider_response text,
  created_at timestamptz not null default now(),
  unique(message_id,token_id)
);

alter table public.mobile_push_tokens enable row level security;
alter table public.message_push_deliveries enable row level security;
revoke all on public.mobile_push_tokens,public.message_push_deliveries from anon,authenticated;

drop policy if exists "Usuário vê seus tokens móveis" on public.mobile_push_tokens;
drop policy if exists "Usuário remove seus tokens móveis" on public.mobile_push_tokens;
create policy "Usuário vê seus tokens móveis" on public.mobile_push_tokens
  for select to authenticated using ((select auth.uid())=user_id);
create policy "Usuário remove seus tokens móveis" on public.mobile_push_tokens
  for delete to authenticated using ((select auth.uid())=user_id);
grant select,delete on public.mobile_push_tokens to authenticated;

create or replace function public.register_mobile_push_token(
  p_token text,
  p_platform text default 'android',
  p_device_info text default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();v_id uuid;
begin
  if v_user is null then raise exception 'Sessão necessária';end if;
  if coalesce(length(trim(p_token)),0)<32 then raise exception 'Token de notificação inválido';end if;
  if p_platform not in ('android','ios') then raise exception 'Plataforma inválida';end if;
  insert into public.mobile_push_tokens(user_id,token,platform,device_info,active,updated_at)
  values(v_user,trim(p_token),p_platform,left(p_device_info,500),true,now())
  on conflict(token) do update set user_id=v_user,platform=excluded.platform,device_info=excluded.device_info,active=true,updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.register_mobile_push_token(text,text,text) from public,anon;
grant execute on function public.register_mobile_push_token(text,text,text) to authenticated;
