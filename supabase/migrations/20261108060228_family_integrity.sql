create or replace function public.validate_family_child_reference()
returns trigger language plpgsql security definer set search_path = '' as $$
declare child_family uuid;
begin
  if new.assigned_child_id is not null then
    select family_id into child_family from public.profiles where id=new.assigned_child_id and role='CHILD';
    if child_family is distinct from new.family_id then raise exception 'CHILD_MUST_BELONG_TO_FAMILY'; end if;
  end if;
  return new;
end
$$;
create trigger tasks_family_child_guard before insert or update of family_id,assigned_child_id on public.tasks
for each row execute function public.validate_family_child_reference();
create trigger rewards_family_child_guard before insert or update of family_id,assigned_child_id on public.rewards
for each row execute function public.validate_family_child_reference();

create or replace function public.validate_goal_child_reference()
returns trigger language plpgsql security definer set search_path = '' as $$
declare child_family uuid;
begin
  select family_id into child_family from public.profiles where id=new.child_id and role='CHILD';
  if child_family is distinct from new.family_id then raise exception 'CHILD_MUST_BELONG_TO_FAMILY'; end if;
  return new;
end
$$;
create trigger savings_goal_family_guard before insert or update of family_id,child_id on public.savings_goals
for each row execute function public.validate_goal_child_reference();

revoke all on function public.validate_family_child_reference(), public.validate_goal_child_reference() from public, anon, authenticated;
