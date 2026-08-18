-- Aura 67: proteções antifarm e limites de integridade.
-- Execute depois da migration 028.

-- Criar um projeto organiza a jornada, mas não concede pontos por si só.
create or replace function public.create_private_project(p_title text,p_goal text,p_next_step text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_project uuid;v_total bigint;v_recent integer;v_active integer;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 perform 1 from public.profiles where id=v_user for update;
 if char_length(trim(p_title)) not between 2 and 80 or char_length(trim(p_goal)) not between 3 and 180 or char_length(trim(p_next_step)) not between 3 and 180 then raise exception 'Preencha corretamente os dados do projeto';end if;
 select count(*) filter(where status<>'completed'),count(*) filter(where created_at>now()-interval '24 hours') into v_active,v_recent from public.user_projects where user_id=v_user;
 if v_active>=20 then raise exception 'Conclua ou exclua um projeto antes de criar outro';end if;
 if v_recent>=5 then raise exception 'Você pode criar até 5 projetos em 24 horas';end if;
 insert into public.user_projects(user_id,title,goal,next_step) values(v_user,trim(p_title),trim(p_goal),trim(p_next_step)) returning id into v_project;
 select aura_points into v_total from public.profiles where id=v_user;
 return jsonb_build_object('project_id',v_project,'earned_points',0,'total_points',v_total);
end;$$;

-- Uma pequena vitória comportamental pontua uma única vez por pessoa/dia,
-- mesmo se o plano for recriado.
create or replace function public.complete_behavior_minimum(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_total bigint;v_today date:=(timezone('America/Sao_Paulo',now()))::date;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 perform 1 from public.profiles where id=v_user for update;
 if not exists(select 1 from public.behavior_plans where id=p_plan_id and user_id=v_user and active=true) then raise exception 'Plano ativo não encontrado';end if;
 if exists(select 1 from public.behavior_checkins where user_id=v_user and checkin_on=v_today) then raise exception 'Sua pequena vitória de hoje já foi registrada';end if;
 insert into public.behavior_checkins(plan_id,user_id,mode,points) values(p_plan_id,v_user,'minimum',3);
 update public.profiles set aura_points=aura_points+3,updated_at=now() where id=v_user returning aura_points into v_total;
 return jsonb_build_object('earned_points',3,'total_points',v_total,'mode','minimum');
end;$$;

-- Índices para os caminhos mais consultados sem duplicar os existentes.
create index if not exists user_projects_status_idx on public.user_projects(user_id,status,created_at desc);
create index if not exists behavior_checkins_user_day_idx on public.behavior_checkins(user_id,checkin_on desc);
create index if not exists direct_messages_unread_idx on public.direct_messages(conversation_id,read_at,created_at desc) where read_at is null;

-- Evita spam automatizado sem atrapalhar uma conversa normal.
create or replace function public.send_direct_message(p_conversation_id uuid,p_content text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_text text:=trim(p_content);v_id bigint;v_other uuid;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select case when c.user_a=v_user then c.user_b else c.user_a end into v_other from public.direct_conversations c where c.id=p_conversation_id and v_user in(c.user_a,c.user_b);
 if v_other is null then raise exception 'Conversa não encontrada';end if;
 if exists(select 1 from public.user_blocks where(blocker_id=v_user and blocked_id=v_other)or(blocker_id=v_other and blocked_id=v_user))then raise exception 'Esta conversa está bloqueada';end if;
 if char_length(v_text) not between 1 and 1000 then raise exception 'Mensagem inválida';end if;
 if (select count(*) from public.direct_messages where sender_id=v_user and created_at>now()-interval '1 minute')>=30 then raise exception 'Muitas mensagens em pouco tempo. Aguarde um instante';end if;
 insert into public.direct_messages(conversation_id,sender_id,content)values(p_conversation_id,v_user,v_text)returning id into v_id;
 update public.direct_conversations set updated_at=now()where id=p_conversation_id;return v_id;
end;$$;

create or replace function public.send_direct_attachment(p_conversation_id uuid,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint,p_caption text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_other uuid;v_message bigint;v_text text:=coalesce(nullif(trim(p_caption),''),'Arquivo: '||trim(p_original_name));
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select case when c.user_a=v_user then c.user_b else c.user_a end into v_other from public.direct_conversations c where c.id=p_conversation_id and v_user in(c.user_a,c.user_b);
 if v_other is null then raise exception 'Conversa não encontrada';end if;
 if exists(select 1 from public.user_blocks where(blocker_id=v_user and blocked_id=v_other)or(blocker_id=v_other and blocked_id=v_user))then raise exception 'Esta conversa está bloqueada';end if;
 if (select count(*) from public.direct_message_attachments where sender_id=v_user and created_at>now()-interval '1 hour')>=10 then raise exception 'Limite de anexos por hora atingido';end if;
 if p_storage_path not like v_user::text||'/direct/'||p_conversation_id::text||'/%' then raise exception 'Caminho de anexo inválido';end if;
 if not exists(select 1 from storage.objects where bucket_id='chat-attachments' and name=p_storage_path and owner_id=v_user::text)then raise exception 'Upload privado não encontrado';end if;
 if p_mime_type not in('image/jpeg','image/png','image/webp','application/pdf')or p_size_bytes<1 or p_size_bytes>(case when p_mime_type like 'image/%' then 10485760 else 20971520 end)then raise exception 'Arquivo não permitido';end if;
 insert into public.direct_messages(conversation_id,sender_id,content)values(p_conversation_id,v_user,left(v_text,1000))returning id into v_message;
 insert into public.direct_message_attachments(message_id,conversation_id,sender_id,storage_path,original_name,mime_type,size_bytes)values(v_message,p_conversation_id,v_user,p_storage_path,left(trim(p_original_name),180),p_mime_type,p_size_bytes);
 update public.direct_conversations set updated_at=now()where id=p_conversation_id;return v_message;
end;$$;

-- Mantém somente as 200 mensagens mais recentes no primeiro carregamento.
create or replace function public.get_direct_messages(p_conversation_id uuid)
returns table(id bigint,sender text,content text,created_at timestamptz,deleted boolean,attachment jsonb)
language sql stable security definer set search_path='' as $$
 with recent as(
  select m.* from public.direct_messages m join public.direct_conversations c on c.id=m.conversation_id
  where m.conversation_id=p_conversation_id and auth.uid() in(c.user_a,c.user_b)
  order by m.created_at desc limit 200
 )
 select m.id,case when m.sender_id=auth.uid() then 'user' else 'person' end,case when m.deleted_at is null then m.content else 'Mensagem apagada' end,m.created_at,m.deleted_at is not null,
  case when m.deleted_at is null and a.id is not null then jsonb_build_object('storage_path',a.storage_path,'original_name',a.original_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes) end
 from recent m left join public.direct_message_attachments a on a.message_id=m.id order by m.created_at;
$$;

revoke all on function public.create_private_project(text,text,text),public.complete_behavior_minimum(uuid),public.send_direct_message(uuid,text),public.send_direct_attachment(uuid,text,text,text,bigint,text),public.get_direct_messages(uuid) from public,anon;
grant execute on function public.create_private_project(text,text,text),public.complete_behavior_minimum(uuid),public.send_direct_message(uuid,text),public.send_direct_attachment(uuid,text,text,text,bigint,text),public.get_direct_messages(uuid) to authenticated;
