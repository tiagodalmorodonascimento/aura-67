-- Aura 67: verificação comunitária anônima, denúncias e recursos.
-- Execute depois da migration 019.

alter table public.action_proofs add column if not exists community_opt_in boolean not null default false;
alter table public.action_proofs add column if not exists community_state text not null default 'private';
alter table public.action_proofs drop constraint if exists action_proofs_community_state_check;
alter table public.action_proofs add constraint action_proofs_community_state_check check(community_state in ('private','available','reviewing','approved','rejected','appealed','admin_review'));

create table if not exists public.community_moderator_profiles(
 user_id uuid primary key references public.profiles(id) on delete cascade,
 reputation integer not null default 50 check(reputation between 0 and 100),
 reviews_total integer not null default 0,
 reviews_aligned integer not null default 0,
 reports_valid integer not null default 0,
 suspended_until timestamptz,
 created_at timestamptz not null default now()
);
alter table public.community_moderator_profiles enable row level security;
drop policy if exists "Moderador vê a própria reputação" on public.community_moderator_profiles;
create policy "Moderador vê a própria reputação" on public.community_moderator_profiles for select to authenticated using(user_id=(select auth.uid()));
grant select on public.community_moderator_profiles to authenticated;

create table if not exists public.community_review_assignments(
 id uuid primary key default gen_random_uuid(),proof_id uuid not null references public.action_proofs(id) on delete cascade,
 reviewer_id uuid not null references public.profiles(id) on delete cascade,status text not null default 'assigned' check(status in ('assigned','completed','expired')),
 assigned_at timestamptz not null default now(),completed_at timestamptz,unique(proof_id,reviewer_id)
);
create index if not exists community_assignment_reviewer_idx on public.community_review_assignments(reviewer_id,status,assigned_at);
alter table public.community_review_assignments enable row level security;
drop policy if exists "Revisor vê a própria atribuição" on public.community_review_assignments;
create policy "Revisor vê a própria atribuição" on public.community_review_assignments for select to authenticated using(reviewer_id=(select auth.uid()));
grant select on public.community_review_assignments to authenticated;

create table if not exists public.community_reviews(
 id uuid primary key default gen_random_uuid(),assignment_id uuid not null unique references public.community_review_assignments(id) on delete cascade,
 proof_id uuid not null references public.action_proofs(id) on delete cascade,reviewer_id uuid not null references public.profiles(id) on delete cascade,
 decision text not null check(decision in ('approve','reject','unsure')),reason text check(char_length(reason)<=300),created_at timestamptz not null default now(),unique(proof_id,reviewer_id)
);
alter table public.community_reviews enable row level security;

create table if not exists public.community_reports(
 id uuid primary key default gen_random_uuid(),proof_id uuid not null references public.action_proofs(id) on delete cascade,
 reporter_id uuid not null references public.profiles(id) on delete cascade,reason text not null check(reason in ('fake','reused','offensive','personal_data','inappropriate','other')),
 details text check(char_length(details)<=300),status text not null default 'pending' check(status in ('pending','valid','invalid')),
 created_at timestamptz not null default now(),unique(proof_id,reporter_id)
);
alter table public.community_reports enable row level security;

create table if not exists public.community_appeals(
 id uuid primary key default gen_random_uuid(),proof_id uuid not null unique references public.action_proofs(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,reason text not null check(char_length(reason) between 10 and 500),
 status text not null default 'pending' check(status in ('pending','accepted','rejected')),created_at timestamptz not null default now(),reviewed_at timestamptz
);
alter table public.community_appeals enable row level security;
drop policy if exists "Usuário vê o próprio recurso" on public.community_appeals;
create policy "Usuário vê o próprio recurso" on public.community_appeals for select to authenticated using(user_id=(select auth.uid()));
grant select on public.community_appeals to authenticated;

create or replace function public.submit_action_proof(p_action_id bigint,p_evidence_path text,p_note text default null,p_community_opt_in boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action public.actions_catalog%rowtype;v_id uuid;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_action from public.actions_catalog where id=p_action_id and active=true;if not found then raise exception 'Ação não encontrada';end if;
 if p_evidence_path not like v_user::text||'/%' then raise exception 'Caminho de prova inválido';end if;
 insert into public.action_proofs(user_id,action_id,evidence_path,note,community_opt_in,community_state)
 values(v_user,p_action_id,p_evidence_path,nullif(trim(p_note),''),p_community_opt_in,case when p_community_opt_in then 'available' else 'private' end) returning id into v_id;
 return jsonb_build_object('proof_id',v_id,'status','pending','pending_xp',v_action.xp,'community_opt_in',p_community_opt_in);
exception when unique_violation then raise exception 'Você já enviou uma comprovação para esta ação hoje';end;$$;
revoke all on function public.submit_action_proof(bigint,text,text,boolean) from public,anon;
grant execute on function public.submit_action_proof(bigint,text,text,boolean) to authenticated;

create or replace function public.complete_aura_action(p_action_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action public.actions_catalog%rowtype;v_today date:=(timezone('America/Sao_Paulo',now()))::date;v_count integer;v_bonus integer:=0;v_earned integer;v_total bigint;v_streak integer:=0;v_day date:=v_today;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_action from public.actions_catalog where id=p_action_id and active=true;if not found then raise exception 'Ação não encontrada';end if;
 if v_action.proof_mode='photo_required' then raise exception 'Esta ação exige uma foto de comprovação';end if;
 v_earned:=greatest(1,ceil(v_action.xp*.4)::integer);
 select count(*) into v_count from public.action_completions where user_id=v_user and completed_on=v_today;if(v_count+1)%3=0 then v_bonus:=6;end if;
 insert into public.action_completions(user_id,action_id,completed_on,base_xp,bonus_xp) values(v_user,p_action_id,v_today,v_earned,v_bonus);
 update public.profiles set aura_points=aura_points+v_earned+v_bonus,updated_at=now() where id=v_user returning aura_points into v_total;
 while exists(select 1 from public.action_completions where user_id=v_user and completed_on=v_day)loop v_streak:=v_streak+1;v_day:=v_day-1;end loop;
 return jsonb_build_object('earned_xp',v_earned,'bonus_xp',v_bonus,'total_points',v_total,'today_count',v_count+1,'streak',v_streak,'verification','self_declared');
exception when unique_violation then raise exception 'Você já concluiu esta ação hoje';end;$$;

create or replace function public.claim_community_review()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_proof public.action_proofs%rowtype;v_assignment uuid;v_action public.actions_catalog%rowtype;v_age interval;v_today integer;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select now()-created_at into v_age from public.profiles where id=v_user;
 if v_age<interval '7 days' and coalesce((select aura_points from public.profiles where id=v_user),0)<100 then raise exception 'A moderação é liberada após 7 dias ou 100 pontos de Aura';end if;
 insert into public.community_moderator_profiles(user_id) values(v_user) on conflict do nothing;
 if exists(select 1 from public.community_moderator_profiles where user_id=v_user and (reputation<20 or suspended_until>now())) then raise exception 'Sua participação na moderação está temporariamente indisponível';end if;
 select count(*) into v_today from public.community_reviews where reviewer_id=v_user and created_at::date=(timezone('America/Sao_Paulo',now()))::date;
 if v_today>=10 then raise exception 'Você concluiu o limite de 10 revisões de hoje';end if;
 select pr.* into v_proof from public.action_proofs pr where pr.community_opt_in=true and pr.status='pending' and pr.community_state in ('available','reviewing') and pr.user_id<>v_user
 and (select count(*) from public.community_review_assignments a where a.proof_id=pr.id and a.status in ('assigned','completed'))<3
 and not exists(select 1 from public.community_review_assignments a where a.proof_id=pr.id and a.reviewer_id=v_user)
 order by pr.submitted_at asc limit 1 for update skip locked;
 if not found then return jsonb_build_object('available',false);end if;
 insert into public.community_review_assignments(proof_id,reviewer_id) values(v_proof.id,v_user) returning id into v_assignment;
 update public.action_proofs set community_state='reviewing' where id=v_proof.id;
 select * into v_action from public.actions_catalog where id=v_proof.action_id;
 return jsonb_build_object('available',true,'assignment_id',v_assignment,'proof_id',v_proof.id,'evidence_path',v_proof.evidence_path,'note',v_proof.note,'action_title',v_action.title,'action_description',v_action.description,'action_icon',v_action.icon);
end;$$;

drop policy if exists "Revisor acessa somente a prova atribuída" on storage.objects;
create policy "Revisor acessa somente a prova atribuída" on storage.objects for select to authenticated using(
 bucket_id='action-proofs' and exists(select 1 from public.action_proofs pr join public.community_review_assignments a on a.proof_id=pr.id where pr.evidence_path=name and a.reviewer_id=(select auth.uid()) and a.status='assigned')
);

create or replace function public.submit_community_review(p_assignment_id uuid,p_decision text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_assignment public.community_review_assignments%rowtype;v_proof public.action_proofs%rowtype;v_approve integer;v_reject integer;v_action public.actions_catalog%rowtype;v_count integer;v_bonus integer:=0;v_total bigint;v_final text;
begin
 if p_decision not in ('approve','reject','unsure') then raise exception 'Decisão inválida';end if;
 select * into v_assignment from public.community_review_assignments where id=p_assignment_id and reviewer_id=v_user and status='assigned' for update;if not found then raise exception 'Revisão não encontrada';end if;
 select * into v_proof from public.action_proofs where id=v_assignment.proof_id and status='pending' for update;if not found then raise exception 'Esta comprovação já foi finalizada';end if;
 insert into public.community_reviews(assignment_id,proof_id,reviewer_id,decision,reason) values(p_assignment_id,v_proof.id,v_user,p_decision,nullif(trim(p_reason),''));
 update public.community_review_assignments set status='completed',completed_at=now() where id=p_assignment_id;
 update public.community_moderator_profiles set reviews_total=reviews_total+1 where user_id=v_user;
 select count(*) filter(where decision='approve'),count(*) filter(where decision='reject') into v_approve,v_reject from public.community_reviews where proof_id=v_proof.id;
 if v_proof.community_state<>'admin_review' then if v_approve>=2 then v_final:='approved';elsif v_reject>=2 then v_final:='rejected';end if;end if;
 if v_final='approved' then
   select * into v_action from public.actions_catalog where id=v_proof.action_id;select count(*) into v_count from public.action_completions where user_id=v_proof.user_id and completed_on=v_proof.submitted_on;if(v_count+1)%3=0 then v_bonus:=15;end if;
   insert into public.action_completions(user_id,action_id,completed_on,base_xp,bonus_xp) values(v_proof.user_id,v_proof.action_id,v_proof.submitted_on,v_action.xp,v_bonus) on conflict do nothing;
   if found then update public.profiles set aura_points=aura_points+v_action.xp+v_bonus,updated_at=now() where id=v_proof.user_id returning aura_points into v_total;end if;
   update public.action_proofs set status='approved',community_state='approved',reviewed_at=now(),reviewer_note='Aprovada por consenso comunitário' where id=v_proof.id;
 elsif v_final='rejected' then update public.action_proofs set status='rejected',community_state='rejected',reviewed_at=now(),reviewer_note='Rejeitada por consenso comunitário. Você pode solicitar nova análise.' where id=v_proof.id;
 elsif (select count(*) from public.community_reviews where proof_id=v_proof.id)>=3 then update public.action_proofs set community_state='admin_review' where id=v_proof.id;
 end if;
 if v_final is not null then update public.community_review_assignments set status='expired' where proof_id=v_proof.id and status='assigned';update public.community_moderator_profiles m set reputation=least(100,greatest(0,reputation+case when r.decision=case when v_final='approved' then 'approve' else 'reject' end then 2 else -1 end)),reviews_aligned=reviews_aligned+case when r.decision=case when v_final='approved' then 'approve' else 'reject' end then 1 else 0 end from public.community_reviews r where r.proof_id=v_proof.id and r.reviewer_id=m.user_id;end if;
 return jsonb_build_object('recorded',true,'final_status',v_final,'approvals',v_approve,'rejections',v_reject);
end;$$;

create or replace function public.report_community_proof(p_proof_id uuid,p_reason text,p_details text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if p_reason not in ('fake','reused','offensive','personal_data','inappropriate','other') then raise exception 'Motivo inválido';end if;
 if not exists(select 1 from public.community_review_assignments where proof_id=p_proof_id and reviewer_id=v_user) then raise exception 'Somente o revisor designado pode denunciar esta prova';end if;
 insert into public.community_reports(proof_id,reporter_id,reason,details) values(p_proof_id,v_user,p_reason,nullif(trim(p_details),''));
 update public.action_proofs set community_state='admin_review' where id=p_proof_id and status='pending';
end;$$;

create or replace function public.appeal_community_decision(p_proof_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if char_length(trim(p_reason)) not between 10 and 500 then raise exception 'Explique o recurso em pelo menos 10 caracteres';end if;
 if not exists(select 1 from public.action_proofs where id=p_proof_id and user_id=v_user and status='rejected') then raise exception 'Comprovação rejeitada não encontrada';end if;
 insert into public.community_appeals(proof_id,user_id,reason) values(p_proof_id,v_user,trim(p_reason));
 update public.action_proofs set community_state='appealed' where id=p_proof_id;
end;$$;

create or replace function public.my_community_moderation()
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('reputation',coalesce((select reputation from public.community_moderator_profiles where user_id=auth.uid()),50),'reviews',coalesce((select reviews_total from public.community_moderator_profiles where user_id=auth.uid()),0),'proofs',coalesce((select jsonb_agg(jsonb_build_object('id',pr.id,'title',a.title,'icon',a.icon,'status',pr.status,'community_state',pr.community_state,'submitted_at',pr.submitted_at,'reviewer_note',pr.reviewer_note) order by pr.submitted_at desc) from public.action_proofs pr join public.actions_catalog a on a.id=pr.action_id where pr.user_id=auth.uid() and pr.community_opt_in=true),'[]'::jsonb));
$$;

revoke all on function public.claim_community_review() from public,anon;
revoke all on function public.submit_community_review(uuid,text,text) from public,anon;
revoke all on function public.report_community_proof(uuid,text,text) from public,anon;
revoke all on function public.appeal_community_decision(uuid,text) from public,anon;
revoke all on function public.my_community_moderation() from public,anon;
grant execute on function public.claim_community_review() to authenticated;
grant execute on function public.submit_community_review(uuid,text,text) to authenticated;
grant execute on function public.report_community_proof(uuid,text,text) to authenticated;
grant execute on function public.appeal_community_decision(uuid,text) to authenticated;
grant execute on function public.my_community_moderation() to authenticated;

create or replace function public.close_community_assignments()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='pending' and new.status in ('approved','rejected') then
   update public.community_review_assignments set status='expired' where proof_id=new.id and status='assigned';
 end if;
 return new;
end;$$;
drop trigger if exists action_proof_close_community_assignments on public.action_proofs;
create trigger action_proof_close_community_assignments after update of status on public.action_proofs for each row execute function public.close_community_assignments();

create or replace function public.admin_community_cases()
returns jsonb language sql stable security definer set search_path='' as $$
select case when public.is_aura_admin() then jsonb_build_object(
 'reports',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'proof_id',r.proof_id,'reason',r.reason,'details',r.details,'created_at',r.created_at,'action_title',a.title,'user_name',p.full_name) order by r.created_at) from public.community_reports r join public.action_proofs pr on pr.id=r.proof_id join public.actions_catalog a on a.id=pr.action_id join public.profiles p on p.id=pr.user_id where r.status='pending'),'[]'::jsonb),
 'appeals',coalesce((select jsonb_agg(jsonb_build_object('id',ap.id,'proof_id',ap.proof_id,'reason',ap.reason,'created_at',ap.created_at,'action_title',a.title,'user_name',p.full_name) order by ap.created_at) from public.community_appeals ap join public.action_proofs pr on pr.id=ap.proof_id join public.actions_catalog a on a.id=pr.action_id join public.profiles p on p.id=pr.user_id where ap.status='pending'),'[]'::jsonb)
) else null end;
$$;

create or replace function public.resolve_community_report(p_report_id uuid,p_valid boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_proof uuid;
begin
 if not public.is_aura_admin() then raise exception 'Acesso administrativo necessário';end if;
 update public.community_reports set status=case when p_valid then 'valid' else 'invalid' end where id=p_report_id and status='pending' returning proof_id into v_proof;
 if v_proof is null then raise exception 'Denúncia pendente não encontrada';end if;
 if p_valid then update public.action_proofs set community_state='admin_review' where id=v_proof and status='pending';end if;
end;$$;

create or replace function public.resolve_community_appeal(p_appeal_id uuid,p_accept boolean,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_proof uuid;v_result jsonb;
begin
 if not public.is_aura_admin() then raise exception 'Acesso administrativo necessário';end if;
 select proof_id into v_proof from public.community_appeals where id=p_appeal_id and status='pending' for update;if not found then raise exception 'Recurso pendente não encontrado';end if;
 if p_accept then
   update public.action_proofs set status='pending',community_state='admin_review' where id=v_proof;
   select public.review_action_proof(v_proof,true,coalesce(nullif(trim(p_note),''),'Recurso aceito após análise administrativa')) into v_result;
   update public.community_appeals set status='accepted',reviewed_at=now() where id=p_appeal_id;
 else
   update public.community_appeals set status='rejected',reviewed_at=now() where id=p_appeal_id;
   update public.action_proofs set reviewer_note=coalesce(nullif(trim(p_note),''),'Recurso analisado e decisão mantida') where id=v_proof;
   v_result:=jsonb_build_object('status','rejected');
 end if;
 return v_result;
end;$$;

revoke all on function public.admin_community_cases() from public,anon;
revoke all on function public.resolve_community_report(uuid,boolean) from public,anon;
revoke all on function public.resolve_community_appeal(uuid,boolean,text) from public,anon;
grant execute on function public.admin_community_cases() to authenticated;
grant execute on function public.resolve_community_report(uuid,boolean) to authenticated;
grant execute on function public.resolve_community_appeal(uuid,boolean,text) to authenticated;
