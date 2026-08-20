-- Aura 67: troféus automáticos de revisão, hidratação e movimento.
-- Execute depois da migration 035.

insert into public.achievements(id,name,description,icon,rarity) values
('review_100','Fiscal de Boteco','Revisou 100 comprovações e já pede evidências até para saber quem lavou a louça.','🧐','raro'),
('review_500','CSI da Aura','Chegou a 500 revisões. Nenhuma foto tremida escapa desse olhar investigativo.','🔬','épico'),
('review_1000','Supremo Tribunal do Sofá','Mil revisões concluídas. A comunidade se levanta quando a excelência entra na sala.','⚖️','lendário'),
('water_7','Aquaman de Copo','Cumpriu a meta de água 7 vezes. As plantas já começaram a pedir conselhos.','🥤','comum'),
('water_30','Reservatório Humano','Trinta metas de hidratação. Se apertar, talvez saia água mineral.','💧','raro'),
('water_100','Hidrelétrica Particular','Cem metas de água concluídas. Energia renovável movida a goles.','🌊','épico'),
('exercise_25','Inimigo do Sofá','Movimentou o corpo 25 vezes. O sofá abriu um boletim de desaparecimento.','🏃','comum'),
('exercise_100','Suor com CNPJ','Cem atividades físicas. O esforço já poderia emitir nota fiscal.','💪','raro'),
('exercise_365','Lenda do Cardio','Trezentos e sessenta e cinco movimentos. O sedentarismo mudou de cidade.','🏅','lendário')
on conflict(id) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,rarity=excluded.rarity;

create or replace function public.award_progress_trophies(p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_reviews integer:=0;v_water integer:=0;v_exercise integer:=0;
begin
 select coalesce(reviews_total,0) into v_reviews from public.community_moderator_profiles where user_id=p_user_id;
 select count(*) into v_water from public.action_completions c join public.actions_catalog a on a.id=c.action_id where c.user_id=p_user_id and a.slug='drink-2l-water';
 select count(*) into v_exercise from public.action_completions c join public.actions_catalog a on a.id=c.action_id where c.user_id=p_user_id and a.slug in('walk-15','pushups-10','stretch-5');
 insert into public.user_achievements(user_id,achievement_id)
 select p_user_id,id from public.achievements where
  (id='review_100' and v_reviews>=100)or(id='review_500' and v_reviews>=500)or(id='review_1000' and v_reviews>=1000)or
  (id='water_7' and v_water>=7)or(id='water_30' and v_water>=30)or(id='water_100' and v_water>=100)or
  (id='exercise_25' and v_exercise>=25)or(id='exercise_100' and v_exercise>=100)or(id='exercise_365' and v_exercise>=365)
 on conflict do nothing;
end;$$;

create or replace function public.trigger_progress_trophies_from_action()
returns trigger language plpgsql security definer set search_path='' as $$begin perform public.award_progress_trophies(new.user_id);return new;end;$$;
drop trigger if exists action_completion_awards_progress_trophies on public.action_completions;
create trigger action_completion_awards_progress_trophies after insert on public.action_completions for each row execute function public.trigger_progress_trophies_from_action();

create or replace function public.trigger_progress_trophies_from_review()
returns trigger language plpgsql security definer set search_path='' as $$begin perform public.award_progress_trophies(new.user_id);return new;end;$$;
drop trigger if exists moderator_review_awards_progress_trophies on public.community_moderator_profiles;
create trigger moderator_review_awards_progress_trophies after insert or update of reviews_total on public.community_moderator_profiles for each row execute function public.trigger_progress_trophies_from_review();

do $$declare r record;begin for r in select id from public.profiles loop perform public.award_progress_trophies(r.id);end loop;end$$;

revoke all on function public.award_progress_trophies(uuid) from public,anon,authenticated;
