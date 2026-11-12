alter type public.ledger_kind rename value 'REDEMPTION' to 'REWARD_REDEMPTION';
alter table public.ledger_entries drop constraint ledger_entries_account_check;
alter table public.ledger_entries add constraint ledger_entries_account_check check (account in ('available','savings','system'));

create or replace function public.balance_ledger_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.account <> 'system' then
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount,goal_id)
    values(new.transaction_id,new.family_id,new.child_id,'system',-new.amount,null);
  end if;
  return new;
end
$$;
create trigger balance_ledger_entry_after_insert after insert on public.ledger_entries
for each row execute function public.balance_ledger_entry();
revoke all on function public.balance_ledger_entry() from public, anon, authenticated;
