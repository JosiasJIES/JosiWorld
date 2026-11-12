-- Run in the Supabase SQL editor as the database owner. All fixtures are rolled back.
begin;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('11111111-1111-4111-8111-111111111111','authenticated','authenticated','codex-ledger-20261108@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Ledger Test Parent"}',now(),now());
insert into public.child_invites(token,family_id,username,display_name) values
  ('33333333-3333-4333-8333-333333333333',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'ledger_test_child','Ledger Test Child');
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('66666666-6666-4666-8666-666666666666','authenticated','authenticated','ledger_test_child@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"33333333-3333-4333-8333-333333333333"}',now(),now());

select set_config('request.test.task',(select t.id::text from public.tasks t join public.profiles p on p.family_id=t.family_id where p.id='11111111-1111-4111-8111-111111111111' and t.title='Leer 10 páginas'),true);
select set_config('request.test.reward',(select r.id::text from public.rewards r join public.profiles p on p.family_id=r.family_id where p.id='11111111-1111-4111-8111-111111111111' and r.title='15 minutos de celular'),true);
insert into public.savings_goals(id,family_id,child_id,title,target_amount) values
  ('99999999-9999-4999-8999-999999999999',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'66666666-6666-4666-8666-666666666666','Test goal',50);

set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select set_config('request.test.submission',public.request_task(current_setting('request.test.task')::uuid,'test submission')::text,true);
select set_config('request.test.goal','99999999-9999-4999-8999-999999999999',true);
do $test$ begin
  begin
    perform public.review_task(current_setting('request.test.submission')::uuid,true,'');
    raise exception 'Child approved their own task';
  exception when others then
    if sqlerrm='Child approved their own task' then raise; end if;
    if sqlerrm not like '%NOT_AUTHORIZED%' then raise; end if;
  end;
  begin
    perform public.request_task(current_setting('request.test.task')::uuid,'duplicate test');
    raise exception 'A once-only task was submitted twice';
  exception when others then
    if sqlerrm='A once-only task was submitted twice' then raise; end if;
    if sqlerrm not like '%TASK_ALREADY_DONE%' then raise; end if;
  end;
  begin
    perform public.request_redemption(current_setting('request.test.reward')::uuid);
    raise exception 'Insufficient balance allowed a redemption';
  exception when others then
    if sqlerrm='Insufficient balance allowed a redemption' then raise; end if;
    if sqlerrm not like '%INSUFFICIENT_BALANCE%' then raise; end if;
  end;
end $test$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.review_task(current_setting('request.test.submission')::uuid,true,'');
do $test$ begin
  begin
    perform public.review_task(current_setting('request.test.submission')::uuid,true,'');
    raise exception 'Duplicate review unexpectedly succeeded';
  exception when others then
    if sqlerrm='Duplicate review unexpectedly succeeded' then raise; end if;
    if sqlerrm not like '%ALREADY_REVIEWED%' then raise; end if;
  end;
end $test$;
select public.parent_adjustment('66666666-6666-4666-8666-666666666666',100,'credit','Ledger test','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
select public.parent_adjustment('66666666-6666-4666-8666-666666666666',100,'credit','Ledger test','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select set_config('request.test.redemption',public.request_redemption(current_setting('request.test.reward')::uuid)::text,true);
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.review_redemption(current_setting('request.test.redemption')::uuid,true,'');
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
do $test$ begin
  begin
    perform public.move_savings(current_setting('request.test.goal')::uuid,80,true,'dddddddd-dddd-4ddd-8ddd-dddddddddddd');
    raise exception 'Insufficient funds were allowed into savings';
  exception when others then
    if sqlerrm='Insufficient funds were allowed into savings' then raise; end if;
    if sqlerrm not like '%INSUFFICIENT_BALANCE%' then raise; end if;
  end;
end $test$;
select public.move_savings(current_setting('request.test.goal')::uuid,30,true,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
select public.move_savings(current_setting('request.test.goal')::uuid,30,true,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
select public.move_savings(current_setting('request.test.goal')::uuid,10,false,'cccccccc-cccc-4ccc-8ccc-cccccccccccc');

do $test$ declare available bigint; saved bigint; total bigint; begin
  select available_balance,savings_balance into available,saved from public.child_balances where child_id='66666666-6666-4666-8666-666666666666';
  total := available + saved;
  if available <> 50 or saved <> 20 or total <> 70 then raise exception 'Unexpected balances: available %, saved %, total %',available,saved,total; end if;
  if (select xp from public.profiles where id='66666666-6666-4666-8666-666666666666') <> 10 then raise exception 'Task approval did not award XP'; end if;
  if (select count(*) from public.ledger_transactions where child_id='66666666-6666-4666-8666-666666666666' and kind='ADJUSTMENT') <> 1 then raise exception 'Idempotent parent adjustment duplicated'; end if;
  if (select count(*) from public.ledger_transactions where child_id='66666666-6666-4666-8666-666666666666' and kind='SAVINGS_DEPOSIT') <> 1 then raise exception 'Idempotent savings transfer duplicated'; end if;
  if (select count(*) from public.ledger_transactions where child_id='66666666-6666-4666-8666-666666666666' and kind='REWARD_REDEMPTION') <> 1 then raise exception 'Approved reward was not recorded exactly once'; end if;
  if exists(select 1 from (select transaction_id,sum(amount) as entry_total from public.ledger_entries where child_id='66666666-6666-4666-8666-666666666666' group by transaction_id) entries where entry_total<>0) then raise exception 'Ledger transaction is not balanced'; end if;
end $test$;

reset role;
rollback;
