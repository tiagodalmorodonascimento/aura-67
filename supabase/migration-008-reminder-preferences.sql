-- Aura 67: preferências do Companheiro Aura.
-- Execute no ambiente de TESTE depois da migration 007.

create table if not exists public.reminder_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  enabled boolean not null default false,
  wake_time time not null default '07:00',
  sleep_time time not null default '22:30',
  max_per_day smallint not null default 4 check (max_per_day between 1 and 8),
  categories text[] not null default array['water','food','movement','rest','focus'],
  weekdays smallint[] not null default array[1,2,3,4,5,6,7],
  personalized boolean not null default true,
  timezone text not null default 'America/Sao_Paulo',
  updated_at timestamptz not null default now(),
  check (categories <@ array['water','food','movement','rest','focus','sleep','mental','social']::text[]),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (cardinality(categories) > 0),
  check (cardinality(weekdays) > 0)
);

alter table public.reminder_preferences enable row level security;
drop policy if exists "Usuário vê suas preferências de lembrete" on public.reminder_preferences;
drop policy if exists "Usuário cria suas preferências de lembrete" on public.reminder_preferences;
drop policy if exists "Usuário atualiza suas preferências de lembrete" on public.reminder_preferences;

create policy "Usuário vê suas preferências de lembrete"
  on public.reminder_preferences for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Usuário cria suas preferências de lembrete"
  on public.reminder_preferences for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Usuário atualiza suas preferências de lembrete"
  on public.reminder_preferences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.reminder_preferences to authenticated;
