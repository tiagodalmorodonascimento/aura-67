-- Aura 67: fila visível de auditorias e recompensa por consenso.
-- Execute depois da migration 036.

create table if not exists public.community_review_rewards(
 assignment_id uuid primary key references public.community_review_assignments(id) on delete cascade,
 reviewer_id uuid not null references public.profiles(id) on delete cascade,
 proof_id uuid not null references public.action_proofs(id) on delete cascade,
 aura_reward integer not null default 5 check(aura_reward between 1 and 20),
 awarded_at timestamptz not null default now()
);
create index if not exists community_review_rewards_reviewer_idx on public.community_review_rewards(reviewer_id,awarded_at desc);
alter table public.community_review_rewards enable row level security;
revoke all on public.community_review_rewards from anon,authenticated;

create or replace function public.award_consensus_review_aura()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='pending' and new.status in('approved','rejected') then
  with rewarded as(
   insert into public.community_review_rewards(assignment_id,reviewer_id,proof_id,aura_reward)
   select r.assignment_id,r.reviewer_id,r.proof_id,5 from public.community_reviews r
   where r.proof_id=new.id and r.decision=case when new.status='approved' then 'approve' else 'reject' end
   on conflict do nothing returning reviewer_id,aura_reward
  ),totals as(select reviewer_id,sum(aura_reward) aura from rewarded group by reviewer_id)
  update public.profiles p set aura_points=p.aura_points+t.aura,updated_at=now() from totals t where p.id=t.reviewer_id;
 end if;
 return new;
end;$$;
drop trigger if exists action_proof_awards_consensus_review_aura on public.action_proofs;
create trigger action_proof_awards_consensus_review_aura after update of status on public.action_proofs for each row execute function public.award_consensus_review_aura();

create or replace function public.my_review_reward_summary()
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'total_aura',coalesce(sum(aura_reward),0),
  'today_aura',coalesce(sum(aura_reward) filter(where timezone('America/Sao_Paulo',awarded_at)::date=timezone('America/Sao_Paulo',now())::date),0),
  'rewarded_reviews',count(*)
 ) from public.community_review_rewards where reviewer_id=auth.uid();
$$;

create or replace function public.get_community_review_queue(p_limit integer default 6)
returns table(proof_id uuid,action_title text,action_icon text,submitted_at timestamptz,review_count bigint)
language sql stable security definer set search_path='' as $$
 select pr.id,a.title,a.icon,pr.submitted_at,
  (select count(*) from public.community_review_assignments ra where ra.proof_id=pr.id and ra.status in('assigned','completed'))
 from public.action_proofs pr join public.actions_catalog a on a.id=pr.action_id
 where pr.community_opt_in=true and pr.status='pending' and pr.community_state in('available','reviewing') and pr.user_id<>auth.uid()
 and not exists(select 1 from public.community_review_assignments mine where mine.proof_id=pr.id and mine.reviewer_id=auth.uid())
 and (select count(*) from public.community_review_assignments ra where ra.proof_id=pr.id and ra.status in('assigned','completed'))<3
 order by pr.submitted_at asc limit least(greatest(coalesce(p_limit,6),1),20);
$$;

create or replace function public.claim_specific_community_review(p_proof_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_proof public.action_proofs%rowtype;v_assignment uuid;v_action public.actions_catalog%rowtype;v_age interval;v_today integer;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select now()-created_at into v_age from public.profiles where id=v_user;
 if v_age<interval '7 days' and coalesce((select aura_points from public.profiles where id=v_user),0)<100 then raise exception 'A moderação é liberada após 7 dias ou 100 pontos de Aura';end if;
 insert into public.community_moderator_profiles(user_id) values(v_user) on conflict do nothing;
 if exists(select 1 from public.community_moderator_profiles where user_id=v_user and(reputation<20 or suspended_until>now()))then raise exception 'Sua participação na moderação está temporariamente indisponível';end if;
 select count(*) into v_today from public.community_reviews where reviewer_id=v_user and created_at::date=timezone('America/Sao_Paulo',now())::date;
 if v_today>=10 then raise exception 'Você concluiu o limite de 10 revisões de hoje';end if;
 select pr.* into v_proof from public.action_proofs pr where pr.id=p_proof_id and pr.community_opt_in=true and pr.status='pending' and pr.community_state in('available','reviewing') and pr.user_id<>v_user
 and(select count(*) from public.community_review_assignments ra where ra.proof_id=pr.id and ra.status in('assigned','completed'))<3
 and not exists(select 1 from public.community_review_assignments mine where mine.proof_id=pr.id and mine.reviewer_id=v_user)
 for update skip locked;
 if not found then return jsonb_build_object('available',false);end if;
 insert into public.community_review_assignments(proof_id,reviewer_id)values(v_proof.id,v_user)returning id into v_assignment;
 update public.action_proofs set community_state='reviewing' where id=v_proof.id;
 select * into v_action from public.actions_catalog where id=v_proof.action_id;
 return jsonb_build_object('available',true,'assignment_id',v_assignment,'proof_id',v_proof.id,'evidence_path',v_proof.evidence_path,'note',v_proof.note,'action_title',v_action.title,'action_description',v_action.description,'action_icon',v_action.icon);
end;$$;

revoke all on function public.my_review_reward_summary(),public.get_community_review_queue(integer),public.claim_specific_community_review(uuid) from public,anon;
grant execute on function public.my_review_reward_summary(),public.get_community_review_queue(integer),public.claim_specific_community_review(uuid) to authenticated;
