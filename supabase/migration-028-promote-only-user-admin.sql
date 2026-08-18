-- Aura 67: promove a conta única existente a super administradora.
-- Segurança: aborta sem alterar nada se houver zero ou mais de uma conta no Auth.
do $$
declare v_count integer;v_user uuid;
begin
 select count(*) into v_count from auth.users;
 if v_count<>1 then raise exception 'Promoção cancelada: esperada exatamente 1 conta, encontradas %',v_count;end if;
 select id into v_user from auth.users limit 1;
 insert into public.admin_users(user_id,role,active) values(v_user,'super_admin',true)
 on conflict(user_id) do update set role='super_admin',active=true;
end;$$;
