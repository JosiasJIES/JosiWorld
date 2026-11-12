create or replace function public.parent_adjustment(target_child uuid, amount_to_adjust integer, direction text, reason text, idempotency_key uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles; available bigint; tx uuid;
begin
  if amount_to_adjust <= 0 or length(btrim(coalesce(reason,''))) < 3 or direction not in ('credit','debit') then raise exception 'INVALID_ADJUSTMENT'; end if;
  if idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select * into p from public.profiles where id=target_child and role='CHILD' for update;
  if not found or not public.is_family_parent(p.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if exists(select 1 from public.ledger_transactions where kind='ADJUSTMENT' and source_id=idempotency_key and child_id=p.id) then return; end if;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=p.id and account='available';
  if direction='debit' and available < amount_to_adjust then raise exception 'INSUFFICIENT_BALANCE'; end if;
  insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
  values(p.family_id,p.id,'ADJUSTMENT',amount_to_adjust,left(btrim(reason),250),idempotency_key,(select auth.uid())) returning id into tx;
  insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
  values(tx,p.family_id,p.id,'available',case when direction='credit' then amount_to_adjust else -amount_to_adjust end);
end
$$;
revoke all on function public.parent_adjustment(uuid,integer,text,text,uuid) from public, anon;
grant execute on function public.parent_adjustment(uuid,integer,text,text,uuid) to authenticated;
revoke execute on function public.move_savings(uuid,integer,boolean) from authenticated;
