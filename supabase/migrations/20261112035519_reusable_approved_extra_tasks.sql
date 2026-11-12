-- Keep an extra task active after a claim is approved so the child can claim it again.
create or replace function public.review_extra_task_claim(claim_uuid uuid, approve boolean, decision_note text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.extra_task_claims;
  tx uuid;
begin
  select * into c
  from public.extra_task_claims
  where id = claim_uuid
  for update;

  if not found or not public.is_family_parent(c.family_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if c.status <> 'PENDING' then
    raise exception 'ALREADY_REVIEWED';
  end if;

  if approve then
    insert into public.ledger_transactions(family_id, child_id, kind, amount, description, source_id, created_by)
    values(c.family_id, c.child_id, 'TASK_REWARD', c.amount_snapshot, 'Extra · ' || c.title_snapshot, c.id, (select auth.uid()))
    returning id into tx;

    insert into public.ledger_entries(transaction_id, family_id, child_id, account, amount)
    values(tx, c.family_id, c.child_id, 'available', c.amount_snapshot);

    update public.profiles set xp = xp + 10 where id = c.child_id;
    perform public.unlock_achievements(c.child_id);
  end if;

  update public.extra_task_claims
  set status = case when approve then 'APPROVED'::public.extra_claim_status else 'REJECTED'::public.extra_claim_status end,
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      review_note = left(coalesce(decision_note, ''), 500)
  where id = c.id;
end
$$;
