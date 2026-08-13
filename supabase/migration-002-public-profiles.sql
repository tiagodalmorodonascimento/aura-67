-- Aura 67: perfis públicos e personalização.
-- Execute primeiro no projeto Supabase de teste.

alter table public.profiles add column if not exists cover_url text;
alter table public.profiles add column if not exists theme_color text not null default '#7657ec' check (theme_color ~ '^#[0-9A-Fa-f]{6}$');
alter table public.profiles add column if not exists aura_points bigint not null default 0 check (aura_points >= 0);

-- O perfil é público, mas esta tabela nunca armazena o e-mail da autenticação.
create policy "Perfis públicos podem ser visualizados"
on public.profiles for select to anon, authenticated using (true);

grant select on table public.profiles to anon, authenticated;
grant update (full_name, username, avatar_url, cover_url, theme_color, bio, updated_at) on table public.profiles to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-media', 'profile-media', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "Imagens de perfil são públicas"
on storage.objects for select to public
using (bucket_id = 'profile-media');

create policy "Usuário envia imagens na própria pasta"
on storage.objects for insert to authenticated
with check (bucket_id = 'profile-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Usuário atualiza imagens na própria pasta"
on storage.objects for update to authenticated
using (bucket_id = 'profile-media' and owner_id = (select auth.uid()::text))
with check (bucket_id = 'profile-media' and owner_id = (select auth.uid()::text));

create policy "Usuário remove imagens da própria pasta"
on storage.objects for delete to authenticated
using (bucket_id = 'profile-media' and owner_id = (select auth.uid()::text));
