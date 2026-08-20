-- Aura 67: economia funcional de Honra, separada de Fogos e protegida contra troca artificial.
-- Execute depois da migration 038.

alter table public.honor_endorsements add column if not exists points_awarded integer not null default 10 check(points_awarded between 1 and 20);

create or replace function public.honor_level(p_points bigint)
returns text language sql immutable set search_path='' as $$select case
 when coalesce(p_points,0)>=20000 then 'Honra Diamante Vermelho'
 when coalesce(p_points,0)>=11000 then 'Honra Diamante'
 when coalesce(p_points,0)>=8000 then 'Honra Safira'
 when coalesce(p_points,0)>=6000 then 'Honra Esmeralda'
 when coalesce(p_points,0)>=4500 then 'Honra Rubi'
 when coalesce(p_points,0)>=3200 then 'Honra Platina'
 when coalesce(p_points,0)>=2200 then 'Honra Ouro'
 when coalesce(p_points,0)>=1500 then 'Honra Prata'
 when coalesce(p_points,0)>=1000 then 'Honra Bronze'
 when coalesce(p_points,0)>=650 then 'Honra Ferro'
 when coalesce(p_points,0)>=400 then 'Honra Pedra'
 when coalesce(p_points,0)>=250 then 'Honra Madeira'
 when coalesce(p_points,0)>=150 then 'Honra Algodão'
 when coalesce(p_points,0)>=75 then 'Honra Papel'
 else 'Honra Inicial' end$$;

create or replace function public.give_honor(p_receiver_id uuid,p_category_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_giver uuid:=auth.uid();v_period date:=date_trunc('week',timezone('America/Sao_Paulo',now()))::date;v_used integer;v_total bigint;v_age interval;v_connected boolean:=false;v_points integer:=10;
begin
 if v_giver is null then raise exception 'É necessário entrar para conceder Honra';end if;
 if v_giver=p_receiver_id then raise exception 'Você não pode conceder Honra a si mesmo';end if;
 if not exists(select 1 from public.profiles where id=p_receiver_id)then raise exception 'Perfil não encontrado';end if;
 if not exists(select 1 from public.honor_categories where id=p_category_id)then raise exception 'Categoria de Honra inválida';end if;
 select now()-created_at into v_age from public.profiles where id=v_giver;
 if v_age<interval '7 days' and coalesce((select aura_points from public.profiles where id=v_giver),0)<100 then raise exception 'O reconhecimento é liberado após 7 dias ou 100 pontos de Aura';end if;
 select count(*) into v_used from public.honor_endorsements where giver_id=v_giver and period_start=v_period;
 if v_used>=3 then raise exception 'Você já utilizou seus 3 reconhecimentos desta semana';end if;
 if exists(select 1 from public.honor_endorsements where giver_id=v_giver and receiver_id=p_receiver_id and period_start=v_period)then raise exception 'Você já reconheceu esta pessoa nesta semana';end if;
 v_connected:=exists(select 1 from public.profile_follows where(follower_id=v_giver and followed_id=p_receiver_id)or(follower_id=p_receiver_id and followed_id=v_giver))
  or exists(select 1 from public.direct_conversations where user_a=least(v_giver,p_receiver_id)and user_b=greatest(v_giver,p_receiver_id))
  or exists(select 1 from public.aura_community_members a join public.aura_community_members b on b.community_id=a.community_id where a.user_id=v_giver and b.user_id=p_receiver_id)
  or exists(select 1 from public.aura_moment_fires f join public.aura_moments m on m.id=f.moment_id where f.sender_id=v_giver and m.user_id=p_receiver_id);
 if not v_connected then raise exception 'Interaja com esta pessoa antes de reconhecer sua Honra';end if;
 insert into public.honor_endorsements(giver_id,receiver_id,category_id,period_start,points_awarded)values(v_giver,p_receiver_id,p_category_id,v_period,v_points);
 update public.profiles set honor_points=honor_points+v_points,updated_at=now()where id=p_receiver_id returning honor_points into v_total;
 return jsonb_build_object('honor_points',v_total,'honor_level',public.honor_level(v_total),'earned',v_points,'remaining_this_week',2-v_used);
end;$$;

-- Fogos celebram; não aumentam reputação. O bloco é opcional para bancos sem a migration 031.
create or replace function public.prevent_firework_honor()
returns trigger language plpgsql set search_path='' as $$begin new.honor_reward:=0;return new;end;$$;
do $$begin
 if to_regclass('public.profile_firework_events') is not null then
  execute 'update public.profile_firework_events set honor_reward=0 where received_at is null and honor_reward<>0';
  execute 'drop trigger if exists profile_fireworks_do_not_award_honor on public.profile_firework_events';
  execute 'create trigger profile_fireworks_do_not_award_honor before insert or update on public.profile_firework_events for each row execute function public.prevent_firework_honor()';
 end if;
end$$;

-- Revisões alinhadas ao consenso fortalecem a reputação do revisor.
create or replace function public.award_review_honor()
returns trigger language plpgsql security definer set search_path='' as $$begin update public.profiles set honor_points=honor_points+2,updated_at=now()where id=new.reviewer_id;return new;end;$$;
do $$begin
 if to_regclass('public.community_review_rewards') is not null then
  execute 'drop trigger if exists community_review_reward_awards_honor on public.community_review_rewards';
  execute 'create trigger community_review_reward_awards_honor after insert on public.community_review_rewards for each row execute function public.award_review_honor()';
 end if;
end$$;

revoke all on function public.give_honor(uuid,text) from public,anon;
grant execute on function public.give_honor(uuid,text) to authenticated;
