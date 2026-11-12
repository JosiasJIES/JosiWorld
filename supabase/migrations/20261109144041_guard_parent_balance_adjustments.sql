create or replace function public.parent_adjustment(target_child uuid, amount_to_adjust integer, direction text, reason text, idempotency_key uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles; available bigint; pending bigint; tx uuid; description_text text;
begin
  if amount_to_adjust <= 0 or length(btrim(coalesce(reason,''))) < 3 or direction not in ('credit','debit') then raise exception 'INVALID_ADJUSTMENT'; end if;
  if idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select * into p from public.profiles where id=target_child and role='CHILD' for update;
  if not found or not public.is_family_parent(p.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if exists(select 1 from public.ledger_transactions where kind='ADJUSTMENT' and source_id=idempotency_key and child_id=p.id) then return; end if;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=p.id and account='available';
  if direction='debit' then
    select coalesce(sum(price_snapshot),0) into pending from public.reward_redemptions where child_id=p.id and status='PENDING';
    if available-pending < amount_to_adjust then raise exception 'INSUFFICIENT_BALANCE'; end if;
  end if;
  description_text := case when direction='debit' then 'Retiro de monedas · ' else 'Ajuste a favor · ' end||left(btrim(reason),210);
  insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
  values(p.family_id,p.id,'ADJUSTMENT',amount_to_adjust,left(description_text,250),idempotency_key,(select auth.uid())) returning id into tx;
  insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
  values(tx,p.family_id,p.id,'available',case when direction='credit' then amount_to_adjust else -amount_to_adjust end);
end
$$;

create or replace function public.parent_reset_child_balance(target_child uuid, reason text, idempotency_key uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles; available bigint; savings bigint; total_to_remove bigint; tx uuid;
begin
  if idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if length(btrim(coalesce(reason,''))) < 3 then raise exception 'INVALID_REASON'; end if;
  select * into p from public.profiles where id=target_child and role='CHILD' for update;
  if not found or not public.is_family_parent(p.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if exists(select 1 from public.ledger_transactions where kind='ADJUSTMENT' and source_id=idempotency_key and child_id=p.id) then return; end if;
  if exists(select 1 from public.reward_redemptions where child_id=p.id and status='PENDING') then raise exception 'PENDING_REDEMPTIONS_EXIST'; end if;

  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=p.id and account='available';
  select coalesce(sum(amount),0) into savings from public.ledger_entries where child_id=p.id and account='savings';
  if available<0 or savings<0 then raise exception 'INVALID_BALANCE'; end if;
  total_to_remove := available+savings;
  if total_to_remove=0 then return; end if;
  if total_to_remove>2147483647 then raise exception 'BALANCE_TOO_LARGE'; end if;

  insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
  values(p.family_id,p.id,'ADJUSTMENT',total_to_remove::integer,left('Reinicio de saldo · '||btrim(reason),250),idempotency_key,(select auth.uid()))
  returning id into tx;

  if available>0 then
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,p.family_id,p.id,'available',-available::integer);
  end if;
  if savings>0 then
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount,goal_id)
    select tx,p.family_id,p.id,'savings',-sum(e.amount)::integer,e.goal_id
    from public.ledger_entries e where e.child_id=p.id and e.account='savings'
    group by e.goal_id having sum(e.amount)>0;
  end if;
end
$$;
