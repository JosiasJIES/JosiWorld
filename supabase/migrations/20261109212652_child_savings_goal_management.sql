create policy savings_child_update on public.savings_goals for update to authenticated
using (child_id=(select auth.uid()) and public.is_family_child(family_id))
with check (child_id=(select auth.uid()) and public.is_family_child(family_id));
grant update(title,target_amount) on public.savings_goals to authenticated;

create or replace function public.archive_savings_goal(goal_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare g public.savings_goals; saved bigint;
begin
  select * into g from public.savings_goals where id=goal_uuid for update;
  if not found or g.child_id<>(select auth.uid()) or not public.is_self_child(g.child_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not g.active then raise exception 'GOAL_ALREADY_ARCHIVED'; end if;
  select coalesce(sum(amount),0) into saved from public.ledger_entries where goal_id=g.id and account='savings';
  if saved<>0 then raise exception 'GOAL_HAS_SAVINGS'; end if;
  update public.savings_goals set active=false where id=g.id;
end
$$;

revoke all on function public.archive_savings_goal(uuid) from public,anon,authenticated;
grant execute on function public.archive_savings_goal(uuid) to authenticated;
