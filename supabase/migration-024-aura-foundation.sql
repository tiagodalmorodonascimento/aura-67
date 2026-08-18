-- Aura 67: mapa privado das quatro dimensões comportamentais.
-- Execute depois da migration 023.

create or replace function public.get_my_aura_foundation()
returns jsonb language sql stable security definer set search_path='' as $$
with bounds as (
  select (timezone('America/Sao_Paulo',now()))::date today,
         (timezone('America/Sao_Paulo',now()))::date-29 starts
), action_stats as (
  select
    count(*)::integer actions,
    count(*) filter(where a.difficulty in ('hard','special'))::integer courage,
    count(*) filter(where a.category='social')::integer impact,
    count(distinct c.completed_on)::integer action_days
  from public.action_completions c
  join public.actions_catalog a on a.id=c.action_id
  cross join bounds b
  where c.user_id=auth.uid() and c.completed_on between b.starts and b.today
), behavior_stats as (
  select count(distinct h.checkin_on)::integer behavior_days
  from public.behavior_checkins h cross join bounds b
  where h.user_id=auth.uid() and h.checkin_on between b.starts and b.today
), project_stats as (
  select count(*) filter(where p.status='completed' and p.completed_at::date between b.starts and b.today)::integer completed_projects
  from public.user_projects p cross join bounds b where p.user_id=auth.uid()
), active_dates as (
  select c.completed_on day from public.action_completions c,bounds b where c.user_id=auth.uid() and c.completed_on between b.starts and b.today
  union
  select h.checkin_on from public.behavior_checkins h,bounds b where h.user_id=auth.uid() and h.checkin_on between b.starts and b.today
  union
  select e.event_date from public.project_point_events e,bounds b where e.user_id=auth.uid() and e.event_date between b.starts and b.today
)
select jsonb_build_object(
  'period_days',30,
  'acao',coalesce(s.actions,0),
  'constancia',(select count(*)::integer from active_dates),
  'coragem',coalesce(s.courage,0)+coalesce(p.completed_projects,0),
  'impacto',coalesce(s.impact,0),
  'completed_projects',coalesce(p.completed_projects,0)
) from action_stats s cross join behavior_stats h cross join project_stats p;
$$;

revoke all on function public.get_my_aura_foundation() from public,anon;
grant execute on function public.get_my_aura_foundation() to authenticated;
