-- Aura 67: registros pessoais sem Aura e pontos apenas por validação.
-- Execute depois da migration 037.

create table if not exists public.action_declarations(
 id bigint generated always as identity primary key,
 user_id uuid not null references public.profiles(id) on delete cascade,
 action_id bigint not null references public.actions_catalog(id),
 declared_on date not null default timezone('America/Sao_Paulo',now())::date,
 created_at timestamptz not null default now(),
 unique(user_id,action_id,declared_on)
);
alter table public.action_declarations enable row level security;
drop policy if exists "Usuário vê seus registros pessoais" on public.action_declarations;
create policy "Usuário vê seus registros pessoais" on public.action_declarations for select to authenticated using(user_id=auth.uid());
revoke all on public.action_declarations from anon,authenticated;
grant select on public.action_declarations to authenticated;

create or replace function public.complete_aura_action(p_action_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action public.actions_catalog%rowtype;v_today date:=timezone('America/Sao_Paulo',now())::date;v_count integer;v_streak integer:=0;v_day date:=v_today;v_total bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_action from public.actions_catalog where id=p_action_id and active=true;if not found then raise exception 'Ação não encontrada';end if;
 if v_action.proof_mode='photo_required' then raise exception 'Esta ação exige comprovação';end if;
 if exists(select 1 from public.action_completions where user_id=v_user and action_id=p_action_id and completed_on=v_today)then raise exception 'Esta ação já foi validada hoje';end if;
 insert into public.action_declarations(user_id,action_id,declared_on)values(v_user,p_action_id,v_today);
 select count(*) into v_count from(
  select action_id from public.action_declarations where user_id=v_user and declared_on=v_today
  union select action_id from public.action_completions where user_id=v_user and completed_on=v_today
 )d;
 while exists(select 1 from public.action_declarations where user_id=v_user and declared_on=v_day union select 1 from public.action_completions where user_id=v_user and completed_on=v_day)loop v_streak:=v_streak+1;v_day:=v_day-1;end loop;
 select aura_points into v_total from public.profiles where id=v_user;
 return jsonb_build_object('earned_xp',0,'bonus_xp',0,'total_points',v_total,'today_count',v_count,'streak',v_streak,'verification','personal_record');
exception when unique_violation then raise exception 'Você já registrou esta ação hoje';end;$$;

revoke all on function public.complete_aura_action(bigint) from public,anon;
grant execute on function public.complete_aura_action(bigint) to authenticated;
