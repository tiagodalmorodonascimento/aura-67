-- Aura 67: progressão automática e privada de projetos.
-- Execute depois das migrations 010 e 013.

alter table public.user_projects add column if not exists completed_at timestamptz;

create table if not exists public.project_point_events (
  id bigint generated always as identity primary key,
  project_id uuid not null references public.user_projects(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in ('created','daily_progress','milestone_25','milestone_50','milestone_75','completed')),
  points integer not null check (points between 1 and 100),
  event_date date not null default (timezone('America/Sao_Paulo',now()))::date,
  created_at timestamptz not null default now()
);
create unique index if not exists project_point_events_once_idx on public.project_point_events(project_id,event_type) where event_type<>'daily_progress';
create unique index if not exists project_point_events_daily_idx on public.project_point_events(project_id,event_date) where event_type='daily_progress';
create index if not exists project_point_events_season_idx on public.project_point_events(user_id,event_date);
alter table public.project_point_events enable row level security;
drop policy if exists "Usuário vê pontos dos próprios projetos" on public.project_point_events;
create policy "Usuário vê pontos dos próprios projetos" on public.project_point_events for select to authenticated using ((select auth.uid())=user_id);
grant select on public.project_point_events to authenticated;

create or replace function public.create_private_project(p_title text,p_goal text,p_next_step text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_project uuid;v_total bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if char_length(trim(p_title)) not between 2 and 80 or char_length(trim(p_goal)) not between 3 and 180 or char_length(trim(p_next_step)) not between 3 and 180 then raise exception 'Preencha corretamente os dados do projeto';end if;
 insert into public.user_projects(user_id,title,goal,next_step) values(v_user,trim(p_title),trim(p_goal),trim(p_next_step)) returning id into v_project;
 insert into public.project_point_events(project_id,user_id,event_type,points) values(v_project,v_user,'created',10);
 update public.profiles set aura_points=aura_points+10,updated_at=now() where id=v_user returning aura_points into v_total;
 return jsonb_build_object('project_id',v_project,'earned_points',10,'total_points',v_total);
end;$$;

create or replace function public.update_private_project(p_project_id uuid,p_title text,p_goal text,p_next_step text,p_progress integer,p_status text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_project public.user_projects%rowtype;v_earned integer:=0;v_bonus integer:=0;v_active_days integer;v_age_days integer;v_daily_events integer;v_completed boolean:=false;v_total bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_project from public.user_projects where id=p_project_id and user_id=v_user for update;if not found then raise exception 'Projeto não encontrado';end if;
 if v_project.status='completed' then raise exception 'Um projeto concluído não pode ser alterado';end if;
 if p_progress not between 0 and 100 or p_status not in ('active','paused','completed') then raise exception 'Progresso ou status inválido';end if;
 if p_progress<v_project.progress then raise exception 'O progresso não pode diminuir';end if;
 if p_status='completed' then p_progress:=100;v_completed:=true;end if;
 select count(*) into v_daily_events from public.project_point_events where project_id=p_project_id and event_type='daily_progress';
 if p_progress>=v_project.progress+5 and v_daily_events<5 then
  insert into public.project_point_events(project_id,user_id,event_type,points) values(p_project_id,v_user,'daily_progress',10) on conflict do nothing;
  if found then v_earned:=v_earned+10;end if;
 end if;
 if p_progress>=25 and v_project.progress<25 then insert into public.project_point_events(project_id,user_id,event_type,points) values(p_project_id,v_user,'milestone_25',20) on conflict do nothing;if found then v_earned:=v_earned+20;end if;end if;
 if p_progress>=50 and v_project.progress<50 then insert into public.project_point_events(project_id,user_id,event_type,points) values(p_project_id,v_user,'milestone_50',20) on conflict do nothing;if found then v_earned:=v_earned+20;end if;end if;
 if p_progress>=75 and v_project.progress<75 then insert into public.project_point_events(project_id,user_id,event_type,points) values(p_project_id,v_user,'milestone_75',20) on conflict do nothing;if found then v_earned:=v_earned+20;end if;end if;
 if v_completed then
  select count(distinct event_date),greatest(0,(timezone('America/Sao_Paulo',now()))::date-v_project.created_at::date) into v_active_days,v_age_days from public.project_point_events where project_id=p_project_id;
  v_bonus:=30+least(v_active_days,5)*5+least(v_age_days,14)*2;
  insert into public.project_point_events(project_id,user_id,event_type,points) values(p_project_id,v_user,'completed',v_bonus) on conflict do nothing;
  if found then v_earned:=v_earned+v_bonus;end if;
 end if;
 update public.user_projects set title=trim(p_title),goal=trim(p_goal),next_step=trim(p_next_step),progress=p_progress,status=p_status,completed_at=case when v_completed then now() else completed_at end,updated_at=now() where id=p_project_id;
 if v_earned>0 then update public.profiles set aura_points=aura_points+v_earned,updated_at=now() where id=v_user returning aura_points into v_total;else select aura_points into v_total from public.profiles where id=v_user;end if;
 return jsonb_build_object('earned_points',v_earned,'completion_bonus',v_bonus,'completed',v_completed,'total_points',v_total);
end;$$;

revoke insert,update,delete on public.user_projects from authenticated;
revoke all on function public.create_private_project(text,text,text) from public,anon;
grant execute on function public.create_private_project(text,text,text) to authenticated;
revoke all on function public.update_private_project(uuid,text,text,text,integer,text) from public,anon;
grant execute on function public.update_private_project(uuid,text,text,text,integer,text) to authenticated;

create or replace function public.get_monthly_season_ranking()
returns table(id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,theme_color text,aura_points bigint,member_number bigint,season_points bigint,season_number integer,season_start date,season_end date)
language sql security definer set search_path='' stable as $$
with season as(select (extract(year from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer*12+extract(month from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer+1) number,date_trunc('month',timezone('America/Sao_Paulo',now()))::date starts,(date_trunc('month',timezone('America/Sao_Paulo',now()))+interval '1 month'-interval '1 day')::date ends),action_scores as(select c.user_id,sum(c.base_xp+c.bonus_xp)::bigint points from public.action_completions c,season s where c.completed_on between s.starts and s.ends group by c.user_id),project_scores as(select e.user_id,sum(e.points)::bigint points from public.project_point_events e,season s where e.event_date between s.starts and s.ends group by e.user_id)
select p.id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,p.aura_points::bigint,p.member_number,coalesce(a.points,0)+coalesce(j.points,0),s.number,s.starts,s.ends from public.profiles p cross join season s left join action_scores a on a.user_id=p.id left join project_scores j on j.user_id=p.id order by coalesce(a.points,0)+coalesce(j.points,0) desc,p.created_at asc limit 100;
$$;
revoke all on function public.get_monthly_season_ranking() from public,anon;
grant execute on function public.get_monthly_season_ranking() to authenticated;
