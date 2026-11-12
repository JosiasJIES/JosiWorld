create index if not exists child_invites_family_id_idx on public.child_invites(family_id);
create index if not exists ledger_transactions_created_by_idx on public.ledger_transactions(created_by);
create index if not exists reward_redemptions_reviewed_by_idx on public.reward_redemptions(reviewed_by);
create index if not exists reward_redemptions_reward_id_idx on public.reward_redemptions(reward_id);
create index if not exists rewards_assigned_child_id_idx on public.rewards(assigned_child_id);
create index if not exists savings_goals_family_id_idx on public.savings_goals(family_id);
create index if not exists task_submissions_reviewed_by_idx on public.task_submissions(reviewed_by);
create index if not exists tasks_assigned_child_id_idx on public.tasks(assigned_child_id);
