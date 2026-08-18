-- Aura 67: exclusão segura de projetos e da própria conta.
-- Execute depois da migration 018.

create or replace function public.delete_private_project(p_project_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_title text;v_points bigint:=0;v_total bigint;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 select title into v_title from public.user_projects where id=p_project_id and user_id=v_user for update;
 if not found then raise exception 'Projeto não encontrado';end if;
 select coalesce(sum(points),0) into v_points from public.project_point_events where project_id=p_project_id and user_id=v_user;
 delete from public.user_projects where id=p_project_id and user_id=v_user;
 update public.profiles set aura_points=greatest(0,aura_points-v_points),updated_at=now() where id=v_user returning aura_points into v_total;
 return jsonb_build_object('deleted',true,'title',v_title,'removed_points',v_points,'total_points',v_total);
end;$$;
revoke all on function public.delete_private_project(uuid) from public,anon;
grant execute on function public.delete_private_project(uuid) to authenticated;

create or replace function public.delete_own_account(p_confirmation text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if p_confirmation<>'EXCLUIR' then raise exception 'Confirmação inválida';end if;
 delete from storage.objects where bucket_id in ('profile-media','action-proofs','chat-attachments') and name like v_user::text||'/%';
 delete from auth.users where id=v_user;
end;$$;
revoke all on function public.delete_own_account(text) from public,anon;
grant execute on function public.delete_own_account(text) to authenticated;
