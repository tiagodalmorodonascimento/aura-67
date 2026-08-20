-- Aura 67: lista privada das pessoas seguidas. Execute depois da migration 039.

create or replace function public.get_my_following()
returns table(
 id uuid,full_name text,username text,bio text,avatar_url text,cover_url text,
 theme_color text,aura_points bigint,member_number bigint,followed_at timestamptz
)
language sql stable security definer set search_path='' as $$
 select p.id,p.full_name,p.username,p.bio,p.avatar_url,p.cover_url,p.theme_color,
  p.aura_points::bigint,p.member_number,f.created_at
 from public.profile_follows f
 join public.profiles p on p.id=f.followed_id
 where f.follower_id=auth.uid()
 order by f.created_at desc;
$$;

revoke all on function public.get_my_following() from public,anon;
grant execute on function public.get_my_following() to authenticated;
