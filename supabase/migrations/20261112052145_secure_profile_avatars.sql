insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 524288, array['image/jpeg']::text[])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy family_avatars_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.profiles me
      where me.id = (select auth.uid())
        and me.is_active
        and me.family_id::text = (storage.foldername(name))[1]
    )
  );

create policy family_avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select p.family_id::text from public.profiles p where p.id = (select auth.uid()))
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy family_avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select p.family_id::text from public.profiles p where p.id = (select auth.uid()))
    and (storage.foldername(name))[2] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select p.family_id::text from public.profiles p where p.id = (select auth.uid()))
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy family_avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select p.family_id::text from public.profiles p where p.id = (select auth.uid()))
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create or replace function public.update_my_avatar(avatar_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile public.profiles;
begin
  select * into current_profile
  from public.profiles
  where id = (select auth.uid()) and is_active
  for update;

  if not found then
    raise exception 'NOT_AUTHORIZED';
  end if;

  if avatar_path is not null and avatar_path <> ''
     and avatar_path <> current_profile.family_id::text || '/' || current_profile.id::text || '/avatar.jpg' then
    raise exception 'INVALID_AVATAR_PATH';
  end if;

  update public.profiles
  set avatar = case when coalesce(avatar_path, '') = '' then '' else 'photo:' || avatar_path end
  where id = current_profile.id;
end
$$;

revoke all on function public.update_my_avatar(text) from public, anon, authenticated;
grant execute on function public.update_my_avatar(text) to authenticated;
