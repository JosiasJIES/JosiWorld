revoke all on table
  public.families,
  public.profiles,
  public.tasks,
  public.task_submissions,
  public.rewards,
  public.reward_redemptions,
  public.savings_goals,
  public.ledger_transactions,
  public.ledger_entries,
  public.achievements,
  public.child_achievements,
  public.app_settings,
  public.child_balances
from anon;

grant update on table public.profiles to authenticated;
