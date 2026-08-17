create or replace function public.get_monthly_season_ranking()
returns table(id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,theme_color text,aura_points bigint,member_number bigint,season_points bigint,season_number integer,season_start date,season_end date)
language sql security definer set search_path='' stable as $$
with season as(select (extract(year from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer*12+extract(month from age(date_trunc('month',timezone('America/Sao_Paulo',now())),date '2026-08-01'))::integer+1) number,date_trunc('month',timezone('America/Sao_Paulo',now()))::date starts,(date_trunc('month',timezone('America/Sao_Paulo',now()))+interval '1 month-1 day')::date ends),scores as(select c.user_id,sum(c.base_xp+c.bonus_xp)::bigint points from public.action_completions c,season s where c.completed_on between s.starts and s.ends group by c.user_id)
select p.id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,p.aura_points::bigint,p.member_number,coalesce(sc.points,0),s.number,s.starts,s.ends from public.profiles p cross join season s left join scores sc on sc.user_id=p.id order by coalesce(sc.points,0) desc,p.created_at asc limit 100;
$$;
revoke all on function public.get_monthly_season_ranking() from public,anon;
grant execute on function public.get_monthly_season_ranking() to authenticated;
