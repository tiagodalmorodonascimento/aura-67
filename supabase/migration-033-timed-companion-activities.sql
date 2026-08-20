-- Aura 67: atividades cronometradas iniciadas pelo Companheiro Aura.
-- Execute depois da migration 032.

create table if not exists public.companion_timed_sessions(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 task_key text not null check(task_key in('water','stretch','breathe','distance','first_step','walk')),
 title text not null check(char_length(title) between 3 and 160),duration_seconds integer not null default 120 check(duration_seconds=120),
 reward_points integer not null default 4 check(reward_points between 0 and 4),status text not null default 'active' check(status in('active','completed','cancelled','expired')),
 session_on date not null default(timezone('America/Sao_Paulo',now())::date),started_at timestamptz not null default now(),
 finishes_at timestamptz not null default(now()+interval '2 minutes'),completed_at timestamptz
);
create index if not exists companion_timed_user_idx on public.companion_timed_sessions(user_id,started_at desc);
create unique index if not exists companion_timed_reward_once_idx on public.companion_timed_sessions(user_id,task_key,session_on) where status='completed';
alter table public.companion_timed_sessions enable row level security;
revoke all on public.companion_timed_sessions from anon,authenticated;

create or replace function public.start_companion_timed_activity(p_task_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_id uuid;v_title text;v_finish timestamptz;v_existing public.companion_timed_sessions%rowtype;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 v_title:=case p_task_key when 'water' then 'Beber água com atenção' when 'stretch' then 'Alongar o corpo' when 'breathe' then 'Respirar com calma' when 'distance' then 'Descansar os olhos' when 'first_step' then 'Dar o primeiro passo' when 'walk' then 'Caminhar com presença' else null end;
 if v_title is null then raise exception 'Atividade inválida';end if;
 select * into v_existing from public.companion_timed_sessions where user_id=v_user and status='active' order by started_at desc limit 1;
 if found and now()<=v_existing.finishes_at+interval '10 minutes' then return jsonb_build_object('session_id',v_existing.id,'task_key',v_existing.task_key,'title',v_existing.title,'finishes_at',v_existing.finishes_at,'duration_seconds',v_existing.duration_seconds,'resumed',true);end if;
 update public.companion_timed_sessions set status='expired' where user_id=v_user and status='active';
 if exists(select 1 from public.companion_timed_sessions where user_id=v_user and task_key=p_task_key and session_on=timezone('America/Sao_Paulo',now())::date and status='completed') then raise exception 'Esta atividade do Companheiro já rendeu Aura hoje';end if;
 if (select count(*) from public.companion_timed_sessions where user_id=v_user and started_at>now()-interval '24 hours')>=12 then raise exception 'Limite diário de tentativas alcançado';end if;
 insert into public.companion_timed_sessions(user_id,task_key,title) values(v_user,p_task_key,v_title) returning id,finishes_at into v_id,v_finish;
 return jsonb_build_object('session_id',v_id,'task_key',p_task_key,'title',v_title,'finishes_at',v_finish,'duration_seconds',120,'resumed',false);
end;$$;

create or replace function public.cancel_companion_timed_activity(p_session_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin update public.companion_timed_sessions set status='cancelled' where id=p_session_id and user_id=auth.uid() and status='active';end;$$;

create or replace function public.complete_companion_timed_activity(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_session public.companion_timed_sessions%rowtype;v_total bigint;v_today integer;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 perform 1 from public.profiles where id=v_user for update;
 select * into v_session from public.companion_timed_sessions where id=p_session_id and user_id=v_user for update;
 if not found or v_session.status<>'active' then raise exception 'Esta atividade não está mais ativa';end if;
 if now()<v_session.finishes_at then raise exception 'A atividade ainda não terminou';end if;
 if now()>v_session.finishes_at+interval '10 minutes' then update public.companion_timed_sessions set status='expired' where id=p_session_id;raise exception 'O tempo para confirmar esta atividade expirou';end if;
 select count(*) into v_today from public.companion_timed_sessions where user_id=v_user and session_on=v_session.session_on and status='completed';
 if v_today>=6 then update public.companion_timed_sessions set status='completed',reward_points=0,completed_at=now() where id=p_session_id;return jsonb_build_object('earned_points',0,'daily_limit',true);end if;
 update public.companion_timed_sessions set status='completed',completed_at=now() where id=p_session_id;
 update public.profiles set aura_points=aura_points+v_session.reward_points,updated_at=now() where id=v_user returning aura_points into v_total;
 return jsonb_build_object('earned_points',v_session.reward_points,'total_points',v_total,'daily_limit',false);
exception when unique_violation then raise exception 'Esta atividade do Companheiro já rendeu Aura hoje';end;$$;

revoke all on function public.start_companion_timed_activity(text),public.cancel_companion_timed_activity(uuid),public.complete_companion_timed_activity(uuid) from public,anon;
grant execute on function public.start_companion_timed_activity(text),public.cancel_companion_timed_activity(uuid),public.complete_companion_timed_activity(uuid) to authenticated;
