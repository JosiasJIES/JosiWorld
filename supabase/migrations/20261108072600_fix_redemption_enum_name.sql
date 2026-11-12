create or replace function public.review_redemption(redemption_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare r public.reward_redemptions; available bigint; tx uuid;
begin
  select * into r from public.reward_redemptions where id=redemption_uuid for update;
  if not found or not public.is_family_parent(r.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if r.status <> 'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  if approve then
    perform 1 from public.profiles where id=r.child_id for update;
    select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=r.child_id and account='available';
    if available < r.price_snapshot then raise exception 'INSUFFICIENT_BALANCE'; end if;
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(r.family_id,r.child_id,'REWARD_REDEMPTION',r.price_snapshot,'Canje aprobado',r.id,(select auth.uid())) returning id into tx;
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,r.family_id,r.child_id,'available',-r.price_snapshot);
  end if;
  update public.reward_redemptions set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(), reviewed_by=(select auth.uid()), review_note=left(coalesce(decision_note,''),500) where id=r.id;
end
$$;
