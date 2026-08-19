-- Aura 67: comunidades privadas ou públicas, membros e convites.
-- Execute depois da migration 031.

create table if not exists public.aura_communities(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 name text not null check(char_length(trim(name)) between 3 and 60),
 description text not null default '' check(char_length(description)<=300),
 visibility text not null default 'private' check(visibility in('private','public')),
 invite_code uuid not null default gen_random_uuid() unique,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table if not exists public.aura_community_members(
 community_id uuid not null references public.aura_communities(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 role text not null default 'member' check(role in('owner','admin','member')),
 joined_at timestamptz not null default now(),primary key(community_id,user_id)
);
create table if not exists public.aura_community_invites(
 id uuid primary key default gen_random_uuid(),community_id uuid not null references public.aura_communities(id) on delete cascade,
 inviter_id uuid not null references public.profiles(id) on delete cascade,invited_profile_id uuid references public.profiles(id) on delete cascade,
 token uuid not null default gen_random_uuid() unique,status text not null default 'pending' check(status in('pending','accepted','declined','revoked')),
 expires_at timestamptz not null default(now()+interval '7 days'),created_at timestamptz not null default now()
);
create index if not exists aura_community_members_user_idx on public.aura_community_members(user_id,joined_at desc);
create index if not exists aura_community_invites_profile_idx on public.aura_community_invites(invited_profile_id,status,created_at desc);
alter table public.aura_communities enable row level security;
alter table public.aura_community_members enable row level security;
alter table public.aura_community_invites enable row level security;
revoke all on public.aura_communities,public.aura_community_members,public.aura_community_invites from anon,authenticated;

create or replace function public.create_aura_community(p_name text,p_description text default '',p_visibility text default 'private')
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_id uuid;v_name text:=trim(p_name);v_description text:=trim(coalesce(p_description,''));
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if char_length(v_name) not between 3 and 60 then raise exception 'O nome deve ter entre 3 e 60 caracteres';end if;
 if char_length(v_description)>300 then raise exception 'A descrição deve ter até 300 caracteres';end if;
 if p_visibility not in('private','public') then raise exception 'Privacidade inválida';end if;
 if (select count(*) from public.aura_communities where owner_id=v_user)>=10 then raise exception 'Você pode criar até 10 comunidades';end if;
 insert into public.aura_communities(owner_id,name,description,visibility) values(v_user,v_name,v_description,p_visibility) returning id into v_id;
 insert into public.aura_community_members(community_id,user_id,role) values(v_id,v_user,'owner');return v_id;
end;$$;

create or replace function public.list_my_aura_communities()
returns table(id uuid,name text,description text,visibility text,owner_id uuid,member_count bigint,my_role text,invite_code uuid,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select c.id,c.name,c.description,c.visibility,c.owner_id,(select count(*) from public.aura_community_members x where x.community_id=c.id),m.role,
 case when m.role in('owner','admin') then c.invite_code else null end,c.created_at
 from public.aura_community_members m join public.aura_communities c on c.id=m.community_id where m.user_id=auth.uid() order by c.updated_at desc;
$$;

create or replace function public.discover_aura_communities()
returns table(id uuid,name text,description text,member_count bigint,joined boolean)
language sql stable security definer set search_path='' as $$
 select c.id,c.name,c.description,(select count(*) from public.aura_community_members m where m.community_id=c.id),
 exists(select 1 from public.aura_community_members m where m.community_id=c.id and m.user_id=auth.uid())
 from public.aura_communities c where c.visibility='public' order by 4 desc,c.created_at desc limit 60;
$$;

create or replace function public.get_aura_community(p_community_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_community public.aura_communities%rowtype;v_role text;
begin
 select * into v_community from public.aura_communities where id=p_community_id;if not found then raise exception 'Comunidade não encontrada';end if;
 select role into v_role from public.aura_community_members where community_id=p_community_id and user_id=v_user;
 if v_community.visibility='private' and v_role is null then raise exception 'Esta comunidade é privada';end if;
 return jsonb_build_object('id',v_community.id,'name',v_community.name,'description',v_community.description,'visibility',v_community.visibility,'my_role',v_role,
  'invite_code',case when v_role in('owner','admin') then v_community.invite_code else null end,
  'members',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'full_name',p.full_name,'username',p.username,'avatar_url',p.avatar_url,'aura_points',p.aura_points,'role',m.role,'joined_at',m.joined_at) order by case m.role when 'owner' then 0 when 'admin' then 1 else 2 end,p.full_name),'[]'::jsonb) from public.aura_community_members m join public.profiles p on p.id=m.user_id where m.community_id=p_community_id));
end;$$;

create or replace function public.join_public_aura_community(p_community_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.aura_communities where id=p_community_id and visibility='public') then raise exception 'Comunidade pública não encontrada';end if;
 if (select count(*) from public.aura_community_members where community_id=p_community_id)>=250 then raise exception 'Esta comunidade atingiu o limite de membros';end if;
 insert into public.aura_community_members(community_id,user_id) values(p_community_id,auth.uid()) on conflict do nothing;
 update public.aura_communities set updated_at=now() where id=p_community_id;
end;$$;

create or replace function public.invite_to_aura_community(p_community_id uuid,p_username text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_target uuid;v_invite uuid;v_role text;
begin
 select role into v_role from public.aura_community_members where community_id=p_community_id and user_id=v_user;
 if v_role not in('owner','admin') then raise exception 'Somente administradores podem convidar';end if;
 select id into v_target from public.profiles where lower(username)=lower(trim(leading '@' from trim(p_username)));
 if v_target is null then raise exception 'Usuário não encontrado';end if;if v_target=v_user then raise exception 'Você já está na comunidade';end if;
 if exists(select 1 from public.aura_community_members where community_id=p_community_id and user_id=v_target) then raise exception 'Esta pessoa já participa';end if;
 update public.aura_community_invites set status='revoked' where community_id=p_community_id and invited_profile_id=v_target and status='pending';
 insert into public.aura_community_invites(community_id,inviter_id,invited_profile_id) values(p_community_id,v_user,v_target) returning id into v_invite;
 return jsonb_build_object('invite_id',v_invite,'profile_id',v_target);
end;$$;

create or replace function public.list_my_aura_community_invites()
returns table(id uuid,community_id uuid,community_name text,inviter_name text,expires_at timestamptz)
language sql stable security definer set search_path='' as $$
 select i.id,i.community_id,c.name,p.full_name,i.expires_at from public.aura_community_invites i
 join public.aura_communities c on c.id=i.community_id join public.profiles p on p.id=i.inviter_id
 where i.invited_profile_id=auth.uid() and i.status='pending' and i.expires_at>now() order by i.created_at desc;
$$;

create or replace function public.respond_aura_community_invite(p_invite_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_invite public.aura_community_invites%rowtype;
begin
 select * into v_invite from public.aura_community_invites where id=p_invite_id and invited_profile_id=auth.uid() and status='pending' and expires_at>now() for update;
 if not found then raise exception 'Convite indisponível ou expirado';end if;
 if p_accept then
  if (select count(*) from public.aura_community_members where community_id=v_invite.community_id)>=250 then raise exception 'Esta comunidade atingiu o limite de membros';end if;
  insert into public.aura_community_members(community_id,user_id) values(v_invite.community_id,auth.uid()) on conflict do nothing;
 end if;
 update public.aura_community_invites set status=case when p_accept then 'accepted' else 'declined' end where id=p_invite_id;
end;$$;

create or replace function public.join_aura_community_by_code(p_code uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 select id into v_id from public.aura_communities where invite_code=p_code;if v_id is null then raise exception 'Convite inválido';end if;
 if (select count(*) from public.aura_community_members where community_id=v_id)>=250 then raise exception 'Esta comunidade atingiu o limite de membros';end if;
 insert into public.aura_community_members(community_id,user_id) values(v_id,auth.uid()) on conflict do nothing;return v_id;
end;$$;

create or replace function public.leave_aura_community(p_community_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.aura_community_members where community_id=p_community_id and user_id=auth.uid() and role='owner') then raise exception 'Transfira a administração antes de sair';end if;
 delete from public.aura_community_members where community_id=p_community_id and user_id=auth.uid();
end;$$;

create or replace function public.remove_aura_community_member(p_community_id uuid,p_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_role text;v_target_role text;
begin
 select role into v_role from public.aura_community_members where community_id=p_community_id and user_id=auth.uid();
 select role into v_target_role from public.aura_community_members where community_id=p_community_id and user_id=p_profile_id;
 if v_role not in('owner','admin') or v_target_role='owner' or (v_role='admin' and v_target_role='admin') then raise exception 'Você não pode remover esta pessoa';end if;
 delete from public.aura_community_members where community_id=p_community_id and user_id=p_profile_id;
end;$$;

revoke all on function public.create_aura_community(text,text,text),public.list_my_aura_communities(),public.discover_aura_communities(),public.get_aura_community(uuid),public.join_public_aura_community(uuid),public.invite_to_aura_community(uuid,text),public.list_my_aura_community_invites(),public.respond_aura_community_invite(uuid,boolean),public.join_aura_community_by_code(uuid),public.leave_aura_community(uuid),public.remove_aura_community_member(uuid,uuid) from public,anon;
grant execute on function public.create_aura_community(text,text,text),public.list_my_aura_communities(),public.discover_aura_communities(),public.get_aura_community(uuid),public.join_public_aura_community(uuid),public.invite_to_aura_community(uuid,text),public.list_my_aura_community_invites(),public.respond_aura_community_invite(uuid,boolean),public.join_aura_community_by_code(uuid),public.leave_aura_community(uuid),public.remove_aura_community_member(uuid,uuid) to authenticated;
