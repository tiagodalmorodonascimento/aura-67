-- TESTE VISUAL: libera a Moldura Diamante para a conta administradora ativa.
-- Este arquivo não é uma migration de produção.

do $$
declare v_admin uuid;v_count integer;
begin
 select count(*),(array_agg(user_id))[1] into v_count,v_admin
 from public.admin_users where active=true and role='super_admin';
 if v_count<>1 then raise exception 'Teste cancelado: esperada exatamente 1 conta super administradora ativa, encontradas %',v_count;end if;
 update public.profiles set honor_points=11000,updated_at=now() where id=v_admin;
 if not found then raise exception 'Perfil da conta administradora não encontrado';end if;
end;$$;

select p.id,p.full_name,p.username,p.honor_points,public.honor_level(p.honor_points) as honor_level
from public.profiles p join public.admin_users a on a.user_id=p.id
where a.active=true and a.role='super_admin';
