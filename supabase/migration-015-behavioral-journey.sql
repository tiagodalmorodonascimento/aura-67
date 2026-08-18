-- Aura 67: planos comportamentais privados e retorno sem culpa.
-- Execute depois da migration 014.

create table if not exists public.behavior_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  action_id bigint not null references public.actions_catalog(id),
  identity_label text not null check(char_length(identity_label) between 3 and 80),
  anchor_text text not null check(char_length(anchor_text) between 3 and 120),
  minimum_version text not null check(char_length(minimum_version) between 3 and 140),
  obstacle_plan text check(char_length(obstacle_plan)<=180),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists behavior_plans_one_active_idx on public.behavior_plans(user_id) where active=true;
alter table public.behavior_plans enable row level security;
drop policy if exists "Usuário vê seu plano comportamental" on public.behavior_plans;
create policy "Usuário vê seu plano comportamental" on public.behavior_plans for select to authenticated using((select auth.uid())=user_id);
grant select on public.behavior_plans to authenticated;

create table if not exists public.behavior_checkins (
  id bigint generated always as identity primary key,
  plan_id uuid not null references public.behavior_plans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  checkin_on date not null default (timezone('America/Sao_Paulo',now()))::date,
  mode text not null check(mode in ('full','minimum')),
  points integer not null default 0 check(points between 0 and 5),
  created_at timestamptz not null default now(),
  unique(user_id,plan_id,checkin_on)
);
create index if not exists behavior_checkins_consistency_idx on public.behavior_checkins(user_id,checkin_on desc);
alter table public.behavior_checkins enable row level security;
drop policy if exists "Usuário vê seus check-ins comportamentais" on public.behavior_checkins;
create policy "Usuário vê seus check-ins comportamentais" on public.behavior_checkins for select to authenticated using((select auth.uid())=user_id);
grant select on public.behavior_checkins to authenticated;

create or replace function public.save_behavior_plan(p_action_id bigint,p_identity_label text,p_anchor_text text,p_minimum_version text,p_obstacle_plan text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_id uuid;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if not exists(select 1 from public.actions_catalog where id=p_action_id and active=true) then raise exception 'Ação não encontrada';end if;
 update public.behavior_plans set active=false,updated_at=now() where user_id=v_user and active=true;
 insert into public.behavior_plans(user_id,action_id,identity_label,anchor_text,minimum_version,obstacle_plan)
 values(v_user,p_action_id,trim(p_identity_label),trim(p_anchor_text),trim(p_minimum_version),nullif(trim(p_obstacle_plan),'')) returning id into v_id;
 return v_id;
end;$$;

create or replace function public.complete_behavior_minimum(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_total bigint;
begin
 if not exists(select 1 from public.behavior_plans where id=p_plan_id and user_id=v_user and active=true) then raise exception 'Plano ativo não encontrado';end if;
 insert into public.behavior_checkins(plan_id,user_id,mode,points) values(p_plan_id,v_user,'minimum',3);
 update public.profiles set aura_points=aura_points+3,updated_at=now() where id=v_user returning aura_points into v_total;
 return jsonb_build_object('earned_points',3,'total_points',v_total,'mode','minimum');
exception when unique_violation then raise exception 'Sua pequena vitória de hoje já foi registrada';end;$$;

create or replace function public.record_behavior_full(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action bigint;
begin
 select action_id into v_action from public.behavior_plans where id=p_plan_id and user_id=v_user and active=true;
 if v_action is null then raise exception 'Plano ativo não encontrado';end if;
 if not exists(select 1 from public.action_completions where user_id=v_user and action_id=v_action and completed_on=(timezone('America/Sao_Paulo',now()))::date) then raise exception 'Conclua a ação antes de registrar a vitória';end if;
 insert into public.behavior_checkins(plan_id,user_id,mode,points) values(p_plan_id,v_user,'full',0) on conflict(user_id,plan_id,checkin_on) do nothing;
 return jsonb_build_object('recorded',true,'mode','full');
end;$$;

revoke all on function public.save_behavior_plan(bigint,text,text,text,text) from public,anon;
grant execute on function public.save_behavior_plan(bigint,text,text,text,text) to authenticated;
revoke all on function public.complete_behavior_minimum(uuid) from public,anon;
grant execute on function public.complete_behavior_minimum(uuid) to authenticated;
revoke all on function public.record_behavior_full(uuid) from public,anon;
grant execute on function public.record_behavior_full(uuid) to authenticated;

-- Inclui as pequenas vitórias na temporada sem revelar o conteúdo dos planos.
create or replace function public.get_monthly_season_ranking()
returns table(id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,theme_color text,aura_points bigint,member_number bigint,season_points bigint,season_number integer,season_start date,season_end date)
language sql security definer set search_path='' stable as $$
with season as(select (extract(year from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer*12+extract(month from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer+1) number,date_trunc('month',timezone('America/Sao_Paulo',now()))::date starts,(date_trunc('month',timezone('America/Sao_Paulo',now()))+interval '1 month'-interval '1 day')::date ends),action_scores as(select c.user_id,sum(c.base_xp+c.bonus_xp)::bigint points from public.action_completions c,season s where c.completed_on between s.starts and s.ends group by c.user_id),project_scores as(select e.user_id,sum(e.points)::bigint points from public.project_point_events e,season s where e.event_date between s.starts and s.ends group by e.user_id),behavior_scores as(select b.user_id,sum(b.points)::bigint points from public.behavior_checkins b,season s where b.checkin_on between s.starts and s.ends group by b.user_id)
select p.id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,p.aura_points::bigint,p.member_number,coalesce(a.points,0)+coalesce(j.points,0)+coalesce(h.points,0),s.number,s.starts,s.ends from public.profiles p cross join season s left join action_scores a on a.user_id=p.id left join project_scores j on j.user_id=p.id left join behavior_scores h on h.user_id=p.id order by coalesce(a.points,0)+coalesce(j.points,0)+coalesce(h.points,0) desc,p.created_at asc limit 100;
$$;
revoke all on function public.get_monthly_season_ranking() from public,anon;
grant execute on function public.get_monthly_season_ranking() to authenticated;
