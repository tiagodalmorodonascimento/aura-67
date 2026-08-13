-- Aura 67: fundadores, conquistas e progressão.
-- Execute no ambiente de teste depois das migrations 001 e 002.

create sequence if not exists public.aura_member_number_seq start with 1;
alter table public.profiles add column if not exists member_number bigint;
alter table public.profiles alter column member_number set default nextval('public.aura_member_number_seq');
update public.profiles set member_number = nextval('public.aura_member_number_seq') where member_number is null;
create unique index if not exists profiles_member_number_key on public.profiles(member_number);

create table if not exists public.achievements (
  id text primary key,
  name text not null,
  description text not null,
  icon text not null,
  rarity text not null default 'comum',
  created_at timestamptz not null default now()
);

create table if not exists public.user_achievements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id text not null references public.achievements(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

insert into public.achievements (id, name, description, icon, rarity)
values ('good_start_1000', 'Um Bom Início', 'Concedido às primeiras 1.000 pessoas que acreditaram na Aura 67.', '🏆', 'fundador')
on conflict (id) do update set name = excluded.name, description = excluded.description, icon = excluded.icon, rarity = excluded.rarity;

insert into public.user_achievements (user_id, achievement_id)
select id, 'good_start_1000' from public.profiles where member_number <= 1000
on conflict do nothing;

create or replace function public.award_founder_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.member_number <= 1000 then
    insert into public.user_achievements (user_id, achievement_id)
    values (new.id, 'good_start_1000') on conflict do nothing;
  end if;
  return new;
end;
$$;

create or replace trigger on_profile_created_award_founder
after insert on public.profiles
for each row execute procedure public.award_founder_achievement();

alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;

create policy "Conquistas são públicas" on public.achievements for select to anon, authenticated using (true);
create policy "Conquistas obtidas são públicas" on public.user_achievements for select to anon, authenticated using (true);

grant select on table public.achievements, public.user_achievements to anon, authenticated;
grant usage, select on sequence public.aura_member_number_seq to authenticated;
