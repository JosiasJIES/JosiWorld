-- Parents can delete a routine only through a narrowly scoped function that
-- checks family ownership and refuses routines with submission history.
create or replace function public.delete_routine(routine_uuid uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  family_uuid uuid;
begin
  select family_id into family_uuid
  from public.routines
  where id = routine_uuid
  for update;

  if family_uuid is null or not public.is_family_parent(family_uuid) then
    raise exception 'ROUTINE_NOT_FOUND_OR_FORBIDDEN';
  end if;

  if exists (select 1 from public.routine_submissions where routine_id = routine_uuid) then
    raise exception 'ROUTINE_HAS_HISTORY';
  end if;

  delete from public.routine_activities
  where routine_id = routine_uuid and family_id = family_uuid;

  delete from public.routines
  where id = routine_uuid and family_id = family_uuid;
end;
$$;
revoke all on function public.delete_routine(uuid) from public, anon;
grant execute on function public.delete_routine(uuid) to authenticated;
