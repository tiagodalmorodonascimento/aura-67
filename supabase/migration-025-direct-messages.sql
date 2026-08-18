-- Aura 67: conversas privadas entre duas pessoas.
-- Execute depois da migration 024.

create table if not exists public.direct_conversations(
 id uuid primary key default gen_random_uuid(),
 user_a uuid not null references public.profiles(id) on delete cascade,
 user_b uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(user_a<user_b),unique(user_a,user_b)
);
create table if not exists public.direct_messages(
 id bigint generated always as identity primary key,
 conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 content text not null check(char_length(content) between 1 and 1000),
 created_at timestamptz not null default now(),read_at timestamptz,deleted_at timestamptz
);
create index if not exists direct_conversations_users_idx on public.direct_conversations(user_a,user_b);
create index if not exists direct_messages_conversation_idx on public.direct_messages(conversation_id,created_at);
alter table public.direct_conversations enable row level security;
alter table public.direct_messages enable row level security;
revoke all on public.direct_conversations,public.direct_messages from anon,authenticated;

create or replace function public.start_direct_conversation(p_profile_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_a uuid;v_b uuid;v_id uuid;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if p_profile_id=v_user then raise exception 'Escolha outra pessoa para conversar';end if;
 if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Perfil não encontrado';end if;
 v_a:=least(v_user,p_profile_id);v_b:=greatest(v_user,p_profile_id);
 insert into public.direct_conversations(user_a,user_b) values(v_a,v_b) on conflict(user_a,user_b) do update set updated_at=public.direct_conversations.updated_at returning id into v_id;
 return v_id;
end;$$;

create or replace function public.get_my_direct_conversations()
returns table(conversation_id uuid,profile_id uuid,full_name text,username text,avatar_url text,theme_color text,last_message text,last_at timestamptz,unread_count bigint)
language sql stable security definer set search_path='' as $$
 select c.id,p.id,p.full_name,p.username,p.avatar_url,p.theme_color,
  coalesce((select case when m.deleted_at is null then m.content else 'Mensagem apagada' end from public.direct_messages m where m.conversation_id=c.id order by m.created_at desc limit 1),'Conversa iniciada'),
  coalesce((select m.created_at from public.direct_messages m where m.conversation_id=c.id order by m.created_at desc limit 1),c.created_at),
  (select count(*) from public.direct_messages m where m.conversation_id=c.id and m.sender_id<>auth.uid() and m.read_at is null)
 from public.direct_conversations c join public.profiles p on p.id=case when c.user_a=auth.uid() then c.user_b else c.user_a end
 where auth.uid() in(c.user_a,c.user_b) order by 8 desc;
$$;

create or replace function public.get_direct_messages(p_conversation_id uuid)
returns table(id bigint,sender text,content text,created_at timestamptz,deleted boolean)
language sql stable security definer set search_path='' as $$
 select m.id,case when m.sender_id=auth.uid() then 'user' else 'person' end,case when m.deleted_at is null then m.content else 'Mensagem apagada' end,m.created_at,m.deleted_at is not null
 from public.direct_messages m join public.direct_conversations c on c.id=m.conversation_id
 where m.conversation_id=p_conversation_id and auth.uid() in(c.user_a,c.user_b) order by m.created_at;
$$;

create or replace function public.send_direct_message(p_conversation_id uuid,p_content text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_text text:=trim(p_content);v_id bigint;
begin
 if not exists(select 1 from public.direct_conversations c where c.id=p_conversation_id and v_user in(c.user_a,c.user_b)) then raise exception 'Conversa não encontrada';end if;
 if char_length(v_text) not between 1 and 1000 then raise exception 'Mensagem inválida';end if;
 insert into public.direct_messages(conversation_id,sender_id,content) values(p_conversation_id,v_user,v_text) returning id into v_id;
 update public.direct_conversations set updated_at=now() where id=p_conversation_id;return v_id;
end;$$;

create or replace function public.mark_direct_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.direct_conversations c where c.id=p_conversation_id and auth.uid() in(c.user_a,c.user_b)) then raise exception 'Conversa não encontrada';end if;
 update public.direct_messages set read_at=now() where conversation_id=p_conversation_id and sender_id<>auth.uid() and read_at is null;
end;$$;

create or replace function public.delete_own_direct_message(p_message_id bigint)
returns boolean language plpgsql security definer set search_path='' as $$
begin update public.direct_messages set content='Mensagem apagada',deleted_at=now() where id=p_message_id and sender_id=auth.uid() and deleted_at is null;return found;end;$$;

revoke all on function public.start_direct_conversation(uuid),public.get_my_direct_conversations(),public.get_direct_messages(uuid),public.send_direct_message(uuid,text),public.mark_direct_conversation_read(uuid),public.delete_own_direct_message(bigint) from public,anon;
grant execute on function public.start_direct_conversation(uuid),public.get_my_direct_conversations(),public.get_direct_messages(uuid),public.send_direct_message(uuid,text),public.mark_direct_conversation_read(uuid),public.delete_own_direct_message(bigint) to authenticated;
