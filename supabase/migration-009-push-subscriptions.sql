-- Aura 67: dispositivos autorizados para Web Push.
-- Execute no ambiente de TESTE depois da migration 008.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth_key text not null,
  user_agent text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user_active_idx on public.push_subscriptions(user_id,active);
alter table public.push_subscriptions enable row level security;
drop policy if exists "Usuário vê seus dispositivos de notificação" on public.push_subscriptions;
drop policy if exists "Usuário registra seu dispositivo de notificação" on public.push_subscriptions;
drop policy if exists "Usuário atualiza seu dispositivo de notificação" on public.push_subscriptions;
drop policy if exists "Usuário remove seu dispositivo de notificação" on public.push_subscriptions;
create policy "Usuário vê seus dispositivos de notificação" on public.push_subscriptions for select to authenticated using((select auth.uid())=user_id);
create policy "Usuário registra seu dispositivo de notificação" on public.push_subscriptions for insert to authenticated with check((select auth.uid())=user_id);
create policy "Usuário atualiza seu dispositivo de notificação" on public.push_subscriptions for update to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Usuário remove seu dispositivo de notificação" on public.push_subscriptions for delete to authenticated using((select auth.uid())=user_id);
grant select,insert,update,delete on public.push_subscriptions to authenticated;

create or replace function public.register_push_subscription(p_endpoint text,p_p256dh text,p_auth_key text,p_user_agent text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'É necessário entrar para ativar notificações'; end if;
  if coalesce(length(p_endpoint),0)<20 or coalesce(length(p_p256dh),0)<20 or coalesce(length(p_auth_key),0)<8 then raise exception 'Assinatura de notificação inválida'; end if;
  insert into public.push_subscriptions(user_id,endpoint,p256dh,auth_key,user_agent,active,updated_at)
  values(v_user,p_endpoint,p_p256dh,p_auth_key,left(p_user_agent,500),true,now())
  on conflict(endpoint) do update set user_id=v_user,p256dh=excluded.p256dh,auth_key=excluded.auth_key,user_agent=excluded.user_agent,active=true,updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.register_push_subscription(text,text,text,text) from public,anon;
grant execute on function public.register_push_subscription(text,text,text,text) to authenticated;
