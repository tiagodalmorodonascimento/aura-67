-- Aura 67: esquema inicial. Execute no SQL Editor do projeto de TESTE primeiro.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 80),
  username text unique,
  avatar_url text,
  bio text check (char_length(bio) <= 280),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Perfis autenticados podem ser visualizados"
on public.profiles for select to authenticated using (true);

create policy "Usuário atualiza somente o próprio perfil"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'Nova pessoa'));
  return new;
end;
$$;

create or replace trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

grant select on table public.profiles to authenticated;
grant update (full_name, username, avatar_url, bio, updated_at) on table public.profiles to authenticated;
