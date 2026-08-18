-- Aura 67: anexos privados no chat (imagens e PDF).
-- Execute depois da migration 012.

create table if not exists public.chat_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id bigint not null unique references public.aura_tester_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  original_name text not null check(char_length(original_name) between 1 and 180),
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  size_bytes bigint not null check(size_bytes between 1 and 20971520),
  created_at timestamptz not null default now()
);
alter table public.chat_attachments enable row level security;
drop policy if exists "Usuário vê seus anexos de conversa" on public.chat_attachments;
create policy "Usuário vê seus anexos de conversa" on public.chat_attachments for select to authenticated using((select auth.uid())=user_id);
grant select on public.chat_attachments to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chat-attachments','chat-attachments',false,20971520,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Usuário envia anexos na própria pasta" on storage.objects;
create policy "Usuário envia anexos na própria pasta" on storage.objects for insert to authenticated
with check(bucket_id='chat-attachments' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Usuário acessa seus anexos privados" on storage.objects;
create policy "Usuário acessa seus anexos privados" on storage.objects for select to authenticated
using(bucket_id='chat-attachments' and owner_id=(select auth.uid())::text);
drop policy if exists "Usuário remove seus anexos privados" on storage.objects;
create policy "Usuário remove seus anexos privados" on storage.objects for delete to authenticated
using(bucket_id='chat-attachments' and owner_id=(select auth.uid())::text);

create or replace function public.send_aura_tester_attachment(p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint,p_caption text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_message bigint;v_text text:=coalesce(nullif(trim(p_caption),''),'Arquivo: '||trim(p_original_name));
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if p_storage_path not like v_user::text||'/%' then raise exception 'Caminho de anexo inválido';end if;
 if not exists(select 1 from storage.objects where bucket_id='chat-attachments' and name=p_storage_path and owner_id=v_user::text) then raise exception 'Upload privado não encontrado';end if;
 if p_mime_type not in('image/jpeg','image/png','image/webp','application/pdf') then raise exception 'Formato não permitido';end if;
 if p_size_bytes < 1 or p_size_bytes > (case when p_mime_type like 'image/%' then 10485760 else 20971520 end) then
  raise exception 'Arquivo excede o limite permitido';
 end if;
 insert into public.aura_tester_messages(user_id,sender,content) values(v_user,'user',left(v_text,1000)) returning id into v_message;
 insert into public.chat_attachments(message_id,user_id,storage_path,original_name,mime_type,size_bytes) values(v_message,v_user,p_storage_path,left(trim(p_original_name),180),p_mime_type,p_size_bytes);
 insert into public.aura_tester_messages(user_id,sender,content) values(v_user,'tester','Recebi seu anexo privado. Ele fica disponível somente nesta conversa. ✦');
 return v_message;
end;$$;

create or replace function public.delete_own_chat_message(p_message_id bigint)
returns text language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_path text;
begin
 select a.storage_path into v_path from public.aura_tester_messages m left join public.chat_attachments a on a.message_id=m.id where m.id=p_message_id and m.user_id=v_user and m.sender='user';
 if not found then raise exception 'Mensagem não encontrada';end if;
 delete from public.aura_tester_messages where id=p_message_id and user_id=v_user and sender='user';
 return v_path;
end;$$;
revoke all on function public.send_aura_tester_attachment(text,text,text,bigint,text) from public,anon;
grant execute on function public.send_aura_tester_attachment(text,text,text,bigint,text) to authenticated;
revoke all on function public.delete_own_chat_message(bigint) from public,anon;
grant execute on function public.delete_own_chat_message(bigint) to authenticated;
