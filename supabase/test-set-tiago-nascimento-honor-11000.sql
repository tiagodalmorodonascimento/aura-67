-- TESTE VISUAL: libera a Moldura Diamante somente para Tiago Nascimento.
-- Este arquivo não é uma migration de produção.

do $$
declare v_profile uuid;v_count integer;
begin
 select count(*),min(id) into v_count,v_profile
 from public.profiles where lower(trim(full_name))='tiago nascimento';
 if v_count<>1 then raise exception 'Teste cancelado: esperado exatamente 1 perfil Tiago Nascimento, encontrados %',v_count;end if;
 update public.profiles set honor_points=11000,updated_at=now() where id=v_profile;
end;$$;

select id,full_name,username,honor_points,public.honor_level(honor_points) as honor_level
from public.profiles
where lower(trim(full_name))='tiago nascimento';
