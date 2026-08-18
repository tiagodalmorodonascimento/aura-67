-- Aura 67: estado sincronizado de mensagens visualizadas do Aura Tester.
-- Execute depois da migration 020.

alter table public.profiles add column if not exists aura_tester_last_read_id bigint not null default 0;

create or replace function public.aura_tester_unread_count()
returns integer language sql stable security definer set search_path='' as $$
select count(*)::integer from public.aura_tester_messages m join public.profiles p on p.id=auth.uid()
where m.user_id=auth.uid() and m.sender='tester' and m.id>p.aura_tester_last_read_id;
$$;

create or replace function public.mark_aura_tester_read(p_last_message_id bigint)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.profiles set aura_tester_last_read_id=greatest(aura_tester_last_read_id,coalesce(p_last_message_id,0)),updated_at=now()
 where id=auth.uid() and exists(select 1 from public.aura_tester_messages where id=p_last_message_id and user_id=auth.uid() and sender='tester');
end;$$;

revoke all on function public.aura_tester_unread_count() from public,anon;
revoke all on function public.mark_aura_tester_read(bigint) from public,anon;
grant execute on function public.aura_tester_unread_count() to authenticated;
grant execute on function public.mark_aura_tester_read(bigint) to authenticated;
