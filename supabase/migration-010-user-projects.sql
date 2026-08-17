create table if not exists public.user_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 80),
  goal text not null check (char_length(goal) between 3 and 180),
  next_step text not null check (char_length(next_step) between 3 and 180),
  progress integer not null default 0 check (progress between 0 and 100),
  status text not null default 'active' check (status in ('active','paused','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists user_projects_owner_idx on public.user_projects(user_id,updated_at desc);
alter table public.user_projects enable row level security;
drop policy if exists "Usuário gerencia seus projetos" on public.user_projects;
create policy "Usuário gerencia seus projetos" on public.user_projects for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
grant select,insert,update,delete on public.user_projects to authenticated;
