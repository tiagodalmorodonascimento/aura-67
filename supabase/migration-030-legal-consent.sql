-- Aura 67: aceite versionado de Termos de Uso e Política de Privacidade.
-- Execute depois da migration 029.

create table if not exists public.legal_acceptances(
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 terms_version text not null check(char_length(terms_version) between 8 and 30),
 privacy_version text not null check(char_length(privacy_version) between 8 and 30),
 accepted_at timestamptz not null default now(),
 unique(user_id,terms_version,privacy_version)
);
create index if not exists legal_acceptances_user_idx on public.legal_acceptances(user_id,accepted_at desc);
alter table public.legal_acceptances enable row level security;
revoke all on public.legal_acceptances from anon,authenticated;

create or replace function public.has_current_legal_acceptance(p_terms_version text,p_privacy_version text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(
  select 1 from public.legal_acceptances
  where user_id=auth.uid() and terms_version=p_terms_version and privacy_version=p_privacy_version
 );
$$;

create or replace function public.accept_current_legal_documents(p_terms_version text,p_privacy_version text)
returns timestamptz language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_accepted timestamptz;
begin
 if v_user is null then raise exception 'Sessão necessária';end if;
 if p_terms_version<>'2026-08-18' or p_privacy_version<>'2026-08-18' then raise exception 'Versão de documento inválida';end if;
 insert into public.legal_acceptances(user_id,terms_version,privacy_version)
 values(v_user,p_terms_version,p_privacy_version)
 on conflict(user_id,terms_version,privacy_version) do update set accepted_at=public.legal_acceptances.accepted_at
 returning accepted_at into v_accepted;
 return v_accepted;
end;$$;

revoke all on function public.has_current_legal_acceptance(text,text),public.accept_current_legal_documents(text,text) from public,anon;
grant execute on function public.has_current_legal_acceptance(text,text),public.accept_current_legal_documents(text,text) to authenticated;
