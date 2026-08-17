create table if not exists public.notification_dismissals (
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_key text not null,
  dismissed_at timestamptz not null default now(),
  primary key (user_id,notification_key)
);
alter table public.notification_dismissals enable row level security;
drop policy if exists "Usuário gerencia notificações dispensadas" on public.notification_dismissals;
create policy "Usuário gerencia notificações dispensadas" on public.notification_dismissals for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
grant select,insert,delete on public.notification_dismissals to authenticated;
