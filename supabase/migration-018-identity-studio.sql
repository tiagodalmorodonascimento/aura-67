-- Aura 67: Estúdio de Identidade, trilha ambiente e destaques públicos.
-- Execute depois da migration 017.

alter table public.profiles add column if not exists identity_manifesto text;
alter table public.profiles add column if not exists identity_values text[] not null default '{}';
alter table public.profiles add column if not exists identity_interests text[] not null default '{}';
alter table public.profiles add column if not exists identity_energy text not null default 'equilibrada';
alter table public.profiles add column if not exists identity_focus text;
alter table public.profiles add column if not exists identity_emblem text not null default '✦';
alter table public.profiles add column if not exists identity_music text not null default 'silencio';
alter table public.profiles add column if not exists identity_layout text not null default 'essencial';
alter table public.profiles add column if not exists pinned_achievement_ids text[] not null default '{}';

alter table public.profiles drop constraint if exists profiles_identity_manifesto_check;
alter table public.profiles add constraint profiles_identity_manifesto_check check(identity_manifesto is null or char_length(identity_manifesto)<=180);
alter table public.profiles drop constraint if exists profiles_identity_focus_check;
alter table public.profiles add constraint profiles_identity_focus_check check(identity_focus is null or char_length(identity_focus)<=120);
alter table public.profiles drop constraint if exists profiles_identity_values_check;
alter table public.profiles add constraint profiles_identity_values_check check(cardinality(identity_values)<=3);
alter table public.profiles drop constraint if exists profiles_identity_interests_check;
alter table public.profiles add constraint profiles_identity_interests_check check(cardinality(identity_interests)<=6);
alter table public.profiles drop constraint if exists profiles_identity_energy_check;
alter table public.profiles add constraint profiles_identity_energy_check check(identity_energy in ('serena','focada','criativa','corajosa','equilibrada','celebrando'));
alter table public.profiles drop constraint if exists profiles_identity_music_check;
alter table public.profiles add constraint profiles_identity_music_check check(identity_music in ('silencio','aurora','fluxo','horizonte','centelha'));
alter table public.profiles drop constraint if exists profiles_identity_layout_check;
alter table public.profiles add constraint profiles_identity_layout_check check(identity_layout in ('essencial','expressivo','jornada'));

create or replace function public.public_profile_identity(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
 'profile',jsonb_build_object(
   'id',p.id,'full_name',p.full_name,'username',p.username,'bio',p.bio,'avatar_url',p.avatar_url,'cover_url',p.cover_url,
   'theme_color',p.theme_color,'aura_points',p.aura_points,'honor_points',p.honor_points,'honor_level',public.honor_level(p.honor_points),
   'profile_visit_count',p.profile_visit_count,'member_number',p.member_number,'created_at',p.created_at,
   'identity_manifesto',p.identity_manifesto,'identity_values',p.identity_values,'identity_interests',p.identity_interests,
   'identity_energy',p.identity_energy,'identity_focus',p.identity_focus,'identity_emblem',p.identity_emblem,
   'identity_music',p.identity_music,'identity_layout',p.identity_layout
 ),
 'achievements',coalesce((select jsonb_agg(jsonb_build_object(
   'id',a.id,'name',a.name,'description',a.description,'icon',a.icon,'rarity',a.rarity,'awarded_at',ua.awarded_at,
   'pinned',a.id=any(p.pinned_achievement_ids)
 ) order by (a.id=any(p.pinned_achievement_ids)) desc,ua.awarded_at desc)
 from public.user_achievements ua join public.achievements a on a.id=ua.achievement_id where ua.user_id=p.id),'[]'::jsonb),
 'honors',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'icon',c.icon,'count',h.total) order by c.display_order)
 from (select category_id,count(*)::bigint total from public.honor_endorsements where receiver_id=p.id group by category_id) h
 join public.honor_categories c on c.id=h.category_id),'[]'::jsonb),
 'milestones',coalesce((select jsonb_agg(item order by occurred_at desc) from (
   select jsonb_build_object('type','achievement','icon',a.icon,'title',a.name,'description',a.description,'date',ua.awarded_at) item,ua.awarded_at occurred_at
   from public.user_achievements ua join public.achievements a on a.id=ua.achievement_id where ua.user_id=p.id
   union all select jsonb_build_object('type','joined','icon','✦','title','Entrou para a Aura','description','O início desta identidade.','date',p.created_at),p.created_at
 ) timeline),'[]'::jsonb)
) from public.profiles p where p.id=p_profile_id;
$$;

revoke all on function public.public_profile_identity(uuid) from public;
grant execute on function public.public_profile_identity(uuid) to anon,authenticated;
