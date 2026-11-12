drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (
  (id=(select auth.uid()) and (role='PARENT' or public.is_self_child(id)))
  or (role='CHILD' and public.is_family_parent(family_id))
);
drop policy if exists task_submissions_read on public.task_submissions;
create policy task_submissions_read on public.task_submissions for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
drop policy if exists redemptions_read on public.reward_redemptions;
create policy redemptions_read on public.reward_redemptions for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
drop policy if exists savings_read on public.savings_goals;
create policy savings_read on public.savings_goals for select to authenticated using (
  public.is_self_child(child_id) or public.is_family_parent(family_id)
);
drop policy if exists ledger_tx_read on public.ledger_transactions;
create policy ledger_tx_read on public.ledger_transactions for select to authenticated using (
  public.is_self_child(child_id) or public.is_family_parent(family_id)
);
drop policy if exists ledger_entries_read on public.ledger_entries;
create policy ledger_entries_read on public.ledger_entries for select to authenticated using (
  public.is_self_child(child_id) or public.is_family_parent(family_id)
);
drop policy if exists child_achievements_read on public.child_achievements;
create policy child_achievements_read on public.child_achievements for select to authenticated using (
  public.is_self_child(child_id) or exists(select 1 from public.profiles p where p.id=child_achievements.child_id and public.is_family_parent(p.family_id))
);
