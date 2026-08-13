-- Aura 67: comprovação privada por foto e XP pendente.
-- Execute depois da migration 004.

alter table public.actions_catalog add column if not exists proof_mode text not null default 'declaration'
check (proof_mode in ('declaration','photo_optional','photo_required','timer'));

update public.actions_catalog set proof_mode='photo_required'
where slug in ('eat-fruit','eat-salad','make-bed','organize-desk','put-clothes-away','clean-room-10','organize-drawer','clean-device');
update public.actions_catalog set proof_mode='photo_optional'
where slug in ('drink-2l-water','walk-15','pushups-10','read-5','three-good-things','log-expenses','start-project','kindness','flash-mission','anti-laziness');
update public.actions_catalog set proof_mode='timer'
where slug in ('stretch-5','no-phone-10','meditate-5','no-social-30','focus-25','personal-goal-30');

create table if not exists public.action_proofs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  action_id bigint not null references public.actions_catalog(id),
  evidence_path text not null,
  note text check (char_length(note) <= 280),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewer_note text check (char_length(reviewer_note) <= 500),
  submitted_on date not null default (timezone('America/Sao_Paulo',now()))::date,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique(user_id,action_id,submitted_on)
);

alter table public.action_proofs enable row level security;
create policy "Usuário vê suas próprias provas" on public.action_proofs for select to authenticated using ((select auth.uid())=user_id);
grant select on public.action_proofs to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('action-proofs','action-proofs',false,8388608,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy "Usuário envia provas na própria pasta" on storage.objects for insert to authenticated
with check(bucket_id='action-proofs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Usuário vê seus próprios arquivos de prova" on storage.objects for select to authenticated
using(bucket_id='action-proofs' and owner_id=(select auth.uid())::text);
create policy "Usuário remove prova ainda própria" on storage.objects for delete to authenticated
using(bucket_id='action-proofs' and owner_id=(select auth.uid())::text);

create or replace function public.complete_aura_action(p_action_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action public.actions_catalog%rowtype;v_today date:=(timezone('America/Sao_Paulo',now()))::date;v_count integer;v_bonus integer:=0;v_total bigint;v_streak integer:=0;v_day date:=v_today;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_action from public.actions_catalog where id=p_action_id and active=true;if not found then raise exception 'Ação não encontrada';end if;
 if v_action.proof_mode='photo_required' then raise exception 'Esta ação exige uma foto de comprovação';end if;
 select count(*) into v_count from public.action_completions where user_id=v_user and completed_on=v_today;
 if(v_count+1)%3=0 then v_bonus:=15;end if;
 insert into public.action_completions(user_id,action_id,completed_on,base_xp,bonus_xp)values(v_user,p_action_id,v_today,v_action.xp,v_bonus);
 update public.profiles set aura_points=aura_points+v_action.xp+v_bonus,updated_at=now() where id=v_user returning aura_points into v_total;
 while exists(select 1 from public.action_completions where user_id=v_user and completed_on=v_day)loop v_streak:=v_streak+1;v_day:=v_day-1;end loop;
 return jsonb_build_object('earned_xp',v_action.xp,'bonus_xp',v_bonus,'total_points',v_total,'today_count',v_count+1,'streak',v_streak);
exception when unique_violation then raise exception 'Você já concluiu esta ação hoje';end;$$;

create or replace function public.submit_action_proof(p_action_id bigint,p_evidence_path text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_action public.actions_catalog%rowtype;v_id uuid;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select * into v_action from public.actions_catalog where id=p_action_id and active=true;if not found then raise exception 'Ação não encontrada';end if;
 if p_evidence_path not like v_user::text||'/%' then raise exception 'Caminho de prova inválido';end if;
 insert into public.action_proofs(user_id,action_id,evidence_path,note)values(v_user,p_action_id,p_evidence_path,nullif(trim(p_note),''))returning id into v_id;
 return jsonb_build_object('proof_id',v_id,'status','pending','pending_xp',v_action.xp);
exception when unique_violation then raise exception 'Você já enviou uma comprovação para esta ação hoje';end;$$;

create or replace function public.review_action_proof(p_proof_id uuid,p_approve boolean,p_reviewer_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_proof public.action_proofs%rowtype;v_action public.actions_catalog%rowtype;v_count integer;v_bonus integer:=0;v_total bigint;
begin
 if coalesce(auth.jwt()->'app_metadata'->>'role','')<>'admin' then raise exception 'Acesso administrativo necessário';end if;
 select * into v_proof from public.action_proofs where id=p_proof_id and status='pending' for update;if not found then raise exception 'Comprovação pendente não encontrada';end if;
 if not p_approve then update public.action_proofs set status='rejected',reviewer_note=p_reviewer_note,reviewed_at=now() where id=p_proof_id;return jsonb_build_object('status','rejected');end if;
 select * into v_action from public.actions_catalog where id=v_proof.action_id;
 select count(*) into v_count from public.action_completions where user_id=v_proof.user_id and completed_on=v_proof.submitted_on;if(v_count+1)%3=0 then v_bonus:=15;end if;
 insert into public.action_completions(user_id,action_id,completed_on,base_xp,bonus_xp)values(v_proof.user_id,v_proof.action_id,v_proof.submitted_on,v_action.xp,v_bonus);
 update public.profiles set aura_points=aura_points+v_action.xp+v_bonus,updated_at=now() where id=v_proof.user_id returning aura_points into v_total;
 update public.action_proofs set status='approved',reviewer_note=p_reviewer_note,reviewed_at=now() where id=p_proof_id;
 return jsonb_build_object('status','approved','earned_xp',v_action.xp,'bonus_xp',v_bonus,'total_points',v_total);
end;$$;

revoke all on function public.submit_action_proof(bigint,text,text) from public,anon;
grant execute on function public.submit_action_proof(bigint,text,text) to authenticated;
revoke all on function public.review_action_proof(uuid,boolean,text) from public,anon;
grant execute on function public.review_action_proof(uuid,boolean,text) to authenticated;
