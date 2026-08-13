-- Aura 67: Super Admin e moderação segura.
-- Execute depois da migration 005.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'moderator' check (role in ('moderator','super_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
alter table public.admin_users enable row level security;

create or replace function public.is_aura_admin()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.admin_users where user_id=auth.uid() and active=true);
$$;
create or replace function public.is_aura_super_admin()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.admin_users where user_id=auth.uid() and role='super_admin' and active=true);
$$;
revoke all on function public.is_aura_admin() from public,anon;
grant execute on function public.is_aura_admin() to authenticated;
revoke all on function public.is_aura_super_admin() from public,anon;
grant execute on function public.is_aura_super_admin() to authenticated;

create policy "Admin vê o próprio papel" on public.admin_users for select to authenticated using(user_id=(select auth.uid()) or public.is_aura_super_admin());
grant select on public.admin_users to authenticated;

create policy "Administradores veem provas" on public.action_proofs for select to authenticated using(public.is_aura_admin());
create policy "Administradores veem arquivos de prova" on storage.objects for select to authenticated using(bucket_id='action-proofs' and public.is_aura_admin());

create or replace function public.admin_proof_queue(p_status text default 'pending',p_limit integer default 50,p_offset integer default 0)
returns table(proof_id uuid,status text,submitted_at timestamptz,note text,evidence_path text,action_title text,action_icon text,xp integer,user_name text,username text,member_number bigint)
language sql stable security definer set search_path='' as $$
 select pr.id,pr.status,pr.submitted_at,pr.note,pr.evidence_path,a.title,a.icon,a.xp,p.full_name,p.username,p.member_number
 from public.action_proofs pr join public.actions_catalog a on a.id=pr.action_id join public.profiles p on p.id=pr.user_id
 where public.is_aura_admin() and (p_status='all' or pr.status=p_status)
 order by case when pr.status='pending' then 0 else 1 end,pr.submitted_at asc limit least(p_limit,100) offset greatest(p_offset,0);
$$;
revoke all on function public.admin_proof_queue(text,integer,integer) from public,anon;
grant execute on function public.admin_proof_queue(text,integer,integer) to authenticated;

create or replace function public.admin_moderation_metrics()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_aura_admin() then jsonb_build_object(
  'pending',(select count(*) from public.action_proofs where status='pending'),
  'approved_today',(select count(*) from public.action_proofs where status='approved' and reviewed_at::date=(timezone('America/Sao_Paulo',now()))::date),
  'rejected_today',(select count(*) from public.action_proofs where status='rejected' and reviewed_at::date=(timezone('America/Sao_Paulo',now()))::date),
  'members',(select count(*) from public.profiles)
 ) else '{}'::jsonb end;
$$;
revoke all on function public.admin_moderation_metrics() from public,anon;
grant execute on function public.admin_moderation_metrics() to authenticated;

create or replace function public.review_action_proof(p_proof_id uuid,p_approve boolean,p_reviewer_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_proof public.action_proofs%rowtype;v_action public.actions_catalog%rowtype;v_count integer;v_bonus integer:=0;v_total bigint;
begin
 if not public.is_aura_admin() then raise exception 'Acesso administrativo necessário';end if;
 select * into v_proof from public.action_proofs where id=p_proof_id and status='pending' for update;if not found then raise exception 'Comprovação pendente não encontrada';end if;
 if not p_approve then update public.action_proofs set status='rejected',reviewer_note=nullif(trim(p_reviewer_note),''),reviewed_at=now() where id=p_proof_id;return jsonb_build_object('status','rejected');end if;
 select * into v_action from public.actions_catalog where id=v_proof.action_id;
 select count(*) into v_count from public.action_completions where user_id=v_proof.user_id and completed_on=v_proof.submitted_on;if(v_count+1)%3=0 then v_bonus:=15;end if;
 insert into public.action_completions(user_id,action_id,completed_on,base_xp,bonus_xp)values(v_proof.user_id,v_proof.action_id,v_proof.submitted_on,v_action.xp,v_bonus);
 update public.profiles set aura_points=aura_points+v_action.xp+v_bonus,updated_at=now() where id=v_proof.user_id returning aura_points into v_total;
 update public.action_proofs set status='approved',reviewer_note=nullif(trim(p_reviewer_note),''),reviewed_at=now() where id=p_proof_id;
 return jsonb_build_object('status','approved','earned_xp',v_action.xp,'bonus_xp',v_bonus,'total_points',v_total);
end;$$;
revoke all on function public.review_action_proof(uuid,boolean,text) from public,anon;
grant execute on function public.review_action_proof(uuid,boolean,text) to authenticated;

-- PROMOVA A PRIMEIRA CONTA: troque o e-mail abaixo e execute somente depois de conferir.
-- insert into public.admin_users(user_id,role)
-- select id,'super_admin' from auth.users where email='SEU_EMAIL_AQUI'
-- on conflict(user_id) do update set role='super_admin',active=true;
