create or replace function public.request_redemption(reward_uuid uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare r public.rewards; available bigint; pending bigint; redemption_id uuid;
begin
  perform 1 from public.profiles where id=(select auth.uid()) and role='CHILD' and is_active for update;
  if not found then raise exception 'NOT_AUTHORIZED'; end if;
  select * into r from public.rewards where id=reward_uuid and active for share;
  if not found then raise exception 'REWARD_UNAVAILABLE'; end if;
  if (select family_id from public.profiles where id=(select auth.uid())) <> r.family_id then raise exception 'FAMILY_MISMATCH'; end if;
  if r.assigned_child_id is not null and r.assigned_child_id <> (select auth.uid()) then raise exception 'REWARD_NOT_AVAILABLE'; end if;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=(select auth.uid()) and account='available';
  select coalesce(sum(price_snapshot),0) into pending from public.reward_redemptions where child_id=(select auth.uid()) and status='PENDING';
  if available-pending < r.price then raise exception 'INSUFFICIENT_BALANCE'; end if;
  insert into public.reward_redemptions(family_id,reward_id,child_id,price_snapshot)
  values(r.family_id,r.id,(select auth.uid()),r.price) returning id into redemption_id;
  return redemption_id;
end
$$;

create or replace function public.move_savings(goal_uuid uuid, amount_to_move integer, deposit boolean, idempotency_key uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare g public.savings_goals; available bigint; tx uuid; k public.ledger_kind;
begin
  if amount_to_move <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  if idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select * into g from public.savings_goals where id=goal_uuid and active for update;
  if not found or (g.child_id <> (select auth.uid()) and not public.is_family_parent(g.family_id)) then raise exception 'NOT_AUTHORIZED'; end if;
  perform 1 from public.profiles where id=g.child_id for update;
  k := case when deposit then 'SAVINGS_DEPOSIT'::public.ledger_kind else 'SAVINGS_WITHDRAWAL'::public.ledger_kind end;
  if exists(select 1 from public.ledger_transactions where kind=k and source_id=idempotency_key) then return; end if;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=g.child_id and account=case when deposit then 'available' else 'savings' end;
  if available < amount_to_move then raise exception 'INSUFFICIENT_BALANCE'; end if;
  insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
  values(g.family_id,g.child_id,k,amount_to_move,case when deposit then 'Ahorro para ' else 'Retiro de ' end||g.title,idempotency_key,(select auth.uid())) returning id into tx;
  insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount,goal_id) values
    (tx,g.family_id,g.child_id,case when deposit then 'available' else 'savings' end,-amount_to_move,g.id),
    (tx,g.family_id,g.child_id,case when deposit then 'savings' else 'available' end,amount_to_move,g.id);
end
$$;
revoke all on function public.move_savings(uuid,integer,boolean,uuid) from public, anon;
grant execute on function public.move_savings(uuid,integer,boolean,uuid) to authenticated;
