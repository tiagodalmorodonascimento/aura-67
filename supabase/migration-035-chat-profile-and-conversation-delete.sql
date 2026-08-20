-- Aura 67: exclusão privada de conversas. Execute depois da migration 034.

create table if not exists public.direct_conversation_hidden(
 user_id uuid not null references public.profiles(id) on delete cascade,
 conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
 hidden_at timestamptz not null default now(),
 primary key(user_id,conversation_id)
);
alter table public.direct_conversation_hidden enable row level security;
revoke all on public.direct_conversation_hidden from anon,authenticated;

create or replace function public.delete_direct_conversation_for_me(p_conversation_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.direct_conversations c where c.id=p_conversation_id and auth.uid() in(c.user_a,c.user_b)) then raise exception 'Conversa não encontrada';end if;
 insert into public.direct_conversation_hidden(user_id,conversation_id,hidden_at) values(auth.uid(),p_conversation_id,now())
 on conflict(user_id,conversation_id) do update set hidden_at=excluded.hidden_at;
 return true;
end;$$;

create or replace function public.get_my_direct_conversations()
returns table(conversation_id uuid,profile_id uuid,full_name text,username text,avatar_url text,theme_color text,last_message text,last_at timestamptz,unread_count bigint)
language sql stable security definer set search_path='' as $$
 select c.id,p.id,p.full_name,p.username,p.avatar_url,p.theme_color,
  coalesce((select case when m.deleted_at is null then m.content else 'Mensagem apagada' end from public.direct_messages m where m.conversation_id=c.id and (h.hidden_at is null or m.created_at>h.hidden_at) order by m.created_at desc limit 1),'Conversa iniciada'),
  coalesce((select m.created_at from public.direct_messages m where m.conversation_id=c.id and (h.hidden_at is null or m.created_at>h.hidden_at) order by m.created_at desc limit 1),c.created_at),
  (select count(*) from public.direct_messages m where m.conversation_id=c.id and m.sender_id<>auth.uid() and m.read_at is null and (h.hidden_at is null or m.created_at>h.hidden_at))
 from public.direct_conversations c
 join public.profiles p on p.id=case when c.user_a=auth.uid() then c.user_b else c.user_a end
 left join public.direct_conversation_hidden h on h.conversation_id=c.id and h.user_id=auth.uid()
 where auth.uid() in(c.user_a,c.user_b)
 and (h.hidden_at is null or exists(select 1 from public.direct_messages m where m.conversation_id=c.id and m.created_at>h.hidden_at))
 order by 8 desc;
$$;

create or replace function public.get_direct_messages(p_conversation_id uuid)
returns table(id bigint,sender text,content text,created_at timestamptz,deleted boolean,attachment jsonb)
language sql stable security definer set search_path='' as $$
 with permitted as(
  select h.hidden_at from public.direct_conversations c left join public.direct_conversation_hidden h on h.conversation_id=c.id and h.user_id=auth.uid()
  where c.id=p_conversation_id and auth.uid() in(c.user_a,c.user_b)
 ),recent as(
  select m.* from public.direct_messages m cross join permitted p
  where m.conversation_id=p_conversation_id and (p.hidden_at is null or m.created_at>p.hidden_at)
  order by m.created_at desc limit 200
 )
 select m.id,case when m.sender_id=auth.uid() then 'user' else 'person' end,
  case when m.deleted_at is null then m.content else 'Mensagem apagada' end,m.created_at,m.deleted_at is not null,
  case when m.deleted_at is null and a.id is not null then jsonb_build_object('storage_path',a.storage_path,'original_name',a.original_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes) end
 from recent m left join public.direct_message_attachments a on a.message_id=m.id order by m.created_at;
$$;

revoke all on function public.delete_direct_conversation_for_me(uuid) from public,anon;
grant execute on function public.delete_direct_conversation_for_me(uuid) to authenticated;
