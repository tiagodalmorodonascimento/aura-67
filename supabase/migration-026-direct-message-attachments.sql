-- Aura 67: fotos e PDFs privados nas conversas entre pessoas.
-- Execute depois da migration 025.

create table if not exists public.direct_message_attachments(
 id uuid primary key default gen_random_uuid(),
 message_id bigint not null unique references public.direct_messages(id) on delete cascade,
 conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 storage_path text not null unique,
 original_name text not null check(char_length(original_name) between 1 and 180),
 mime_type text not null check(mime_type in('image/jpeg','image/png','image/webp','application/pdf')),
 size_bytes bigint not null check(size_bytes between 1 and 20971520),created_at timestamptz not null default now()
);
create index if not exists direct_message_attachments_conversation_idx on public.direct_message_attachments(conversation_id);
alter table public.direct_message_attachments enable row level security;
revoke all on public.direct_message_attachments from anon,authenticated;

create or replace function public.can_access_direct_attachment(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.direct_message_attachments a join public.direct_conversations c on c.id=a.conversation_id where a.storage_path=p_path and auth.uid() in(c.user_a,c.user_b));
$$;
revoke all on function public.can_access_direct_attachment(text) from public,anon;
grant execute on function public.can_access_direct_attachment(text) to authenticated;

drop policy if exists "Participante acessa anexo de conversa privada" on storage.objects;
create policy "Participante acessa anexo de conversa privada" on storage.objects for select to authenticated
using(bucket_id='chat-attachments' and public.can_access_direct_attachment(name));

create or replace function public.send_direct_attachment(p_conversation_id uuid,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint,p_caption text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_message bigint;v_text text:=coalesce(nullif(trim(p_caption),''),'Arquivo: '||trim(p_original_name));
begin
 if not exists(select 1 from public.direct_conversations c where c.id=p_conversation_id and v_user in(c.user_a,c.user_b)) then raise exception 'Conversa não encontrada';end if;
 if p_storage_path not like v_user::text||'/direct/'||p_conversation_id::text||'/%' then raise exception 'Caminho de anexo inválido';end if;
 if not exists(select 1 from storage.objects where bucket_id='chat-attachments' and name=p_storage_path and owner_id=v_user::text) then raise exception 'Upload privado não encontrado';end if;
 if p_mime_type not in('image/jpeg','image/png','image/webp','application/pdf') then raise exception 'Formato não permitido';end if;
 if p_size_bytes<1 or p_size_bytes>(case when p_mime_type like 'image/%' then 10485760 else 20971520 end) then raise exception 'Arquivo excede o limite permitido';end if;
 insert into public.direct_messages(conversation_id,sender_id,content) values(p_conversation_id,v_user,left(v_text,1000)) returning id into v_message;
 insert into public.direct_message_attachments(message_id,conversation_id,sender_id,storage_path,original_name,mime_type,size_bytes) values(v_message,p_conversation_id,v_user,p_storage_path,left(trim(p_original_name),180),p_mime_type,p_size_bytes);
 update public.direct_conversations set updated_at=now() where id=p_conversation_id;return v_message;
end;$$;

drop function if exists public.get_direct_messages(uuid);
create function public.get_direct_messages(p_conversation_id uuid)
returns table(id bigint,sender text,content text,created_at timestamptz,deleted boolean,attachment jsonb)
language sql stable security definer set search_path='' as $$
 select m.id,case when m.sender_id=auth.uid() then 'user' else 'person' end,case when m.deleted_at is null then m.content else 'Mensagem apagada' end,m.created_at,m.deleted_at is not null,
  case when m.deleted_at is null and a.id is not null then jsonb_build_object('storage_path',a.storage_path,'original_name',a.original_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes) end
 from public.direct_messages m join public.direct_conversations c on c.id=m.conversation_id left join public.direct_message_attachments a on a.message_id=m.id
 where m.conversation_id=p_conversation_id and auth.uid() in(c.user_a,c.user_b) order by m.created_at;
$$;

drop function if exists public.delete_own_direct_message(bigint);
create function public.delete_own_direct_message(p_message_id bigint)
returns text language plpgsql security definer set search_path='' as $$
declare v_path text;
begin
 select a.storage_path into v_path from public.direct_messages m left join public.direct_message_attachments a on a.message_id=m.id where m.id=p_message_id and m.sender_id=auth.uid() and m.deleted_at is null;
 if not found then raise exception 'Mensagem não encontrada';end if;
 update public.direct_messages set content='Mensagem apagada',deleted_at=now() where id=p_message_id and sender_id=auth.uid();return v_path;
end;$$;

revoke all on function public.send_direct_attachment(uuid,text,text,text,bigint,text),public.get_direct_messages(uuid),public.delete_own_direct_message(bigint) from public,anon;
grant execute on function public.send_direct_attachment(uuid,text,text,text,bigint,text),public.get_direct_messages(uuid),public.delete_own_direct_message(bigint) to authenticated;
