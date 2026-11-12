-- Run in the Supabase SQL editor as the database owner. All fixtures are rolled back.
begin;

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('11111111-1111-4111-8111-111111111111','authenticated','authenticated','codex-routines-20261108@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Routine Test Parent"}',now(),now());
insert into public.child_invites(token,family_id,username,display_name) values
  ('33333333-3333-4333-8333-333333333333',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'routine_child_a','Routine Child A'),
  ('44444444-4444-4444-8444-444444444444',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'routine_child_b','Routine Child B');
insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
  ('66666666-6666-4666-8666-666666666666','authenticated','authenticated','routine_child_a@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"33333333-3333-4333-8333-333333333333"}',now(),now()),
  ('88888888-8888-4888-8888-888888888888','authenticated','authenticated','routine_child_b@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"44444444-4444-4444-8444-444444444444"}',now(),now());

insert into public.tasks(id,family_id,title,description,amount,category,frequency,active)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'Extra test task','One-time extra',25,'Hogar','once',true);

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.test.today_weekday',(extract(isodow from (now() at time zone 'America/Mexico_City')::date)::integer)::text,true);
select set_config('request.test.family',(select family_id::text from public.profiles where id='11111111-1111-4111-8111-111111111111'),true);
select set_config('request.test.per_routine',public.save_routine(null,'Rutina por actividad','Prueba de envío conjunto',null,array[current_setting('request.test.today_weekday')::integer],'PER_ACTIVITY',time '23:59','[{"title":"Make bed","amount":5},{"title":"Brush teeth","amount":3}]')::text,true);
select set_config('request.test.per_items',(select string_agg(id::text,',' order by position) from public.routine_activities where routine_id=current_setting('request.test.per_routine')::uuid),true);
select set_config('request.test.whole_routine',public.save_routine(null,'Rutina completa','Pago al terminar todo',null,array[current_setting('request.test.today_weekday')::integer],'WHOLE_ROUTINE',time '23:59','[{"title":"Read","amount":8},{"title":"Study","amount":12}]')::text,true);
select set_config('request.test.whole_items',(select string_agg(id::text,',' order by position) from public.routine_activities where routine_id=current_setting('request.test.whole_routine')::uuid),true);

select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select set_config('request.test.per_submission',public.submit_routine(current_setting('request.test.per_routine')::uuid,string_to_array(current_setting('request.test.per_items'),',')::uuid[])::text,true);
select set_config('request.test.whole_submission',public.submit_routine(current_setting('request.test.whole_routine')::uuid,string_to_array(current_setting('request.test.whole_items'),',')::uuid[])::text,true);
select set_config('request.test.extra_claim',public.claim_extra_task('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')::text,true);

select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
do $test$ begin
  begin
    perform public.claim_extra_task('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    raise exception 'A second child claimed an already reserved extra';
  exception when others then
    if sqlerrm='A second child claimed an already reserved extra' then raise; end if;
    if sqlerrm not like '%TASK_ALREADY_CLAIMED%' then raise; end if;
  end;
end $test$;

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.test.first_item',(
  select id::text from public.routine_submission_items where submission_id=current_setting('request.test.per_submission')::uuid and title_snapshot='Make bed'),true);
select set_config('request.test.second_item',(
  select id::text from public.routine_submission_items where submission_id=current_setting('request.test.per_submission')::uuid and title_snapshot='Brush teeth'),true);
select public.review_routine_activity_item(current_setting('request.test.first_item')::uuid,true,'');
select public.review_routine_activity_item(current_setting('request.test.second_item')::uuid,false,'Not completed');
select public.review_routine_completion(current_setting('request.test.whole_submission')::uuid,true,'');
select public.submit_extra_task_claim(current_setting('request.test.extra_claim')::uuid);
select public.review_extra_task_claim(current_setting('request.test.extra_claim')::uuid,true,'');

do $test$ declare available bigint; child_xp integer; begin
  select available_balance into available from public.child_balances where child_id='66666666-6666-4666-8666-666666666666';
  select xp into child_xp from public.profiles where id='66666666-6666-4666-8666-666666666666';
  if available<>50 then raise exception 'Expected 50 coins from the approved activity, full routine, and extra; got %',available; end if;
  if child_xp<>40 then raise exception 'Expected XP per approved activity; got %',child_xp; end if;
  if (select status from public.routine_submissions where id=current_setting('request.test.per_submission')::uuid)<>'REJECTED' then raise exception 'Partially approved routine should not count as fully complete'; end if;
  if (select count(*) from public.ledger_transactions where child_id='66666666-6666-4666-8666-666666666666' and kind='TASK_REWARD')<>3 then raise exception 'Routine and extra rewards were not recorded exactly once'; end if;
  if (select active from public.tasks where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') then raise exception 'Approved extra task was not closed'; end if;
  if exists(select 1 from (select transaction_id,sum(amount) as entry_total from public.ledger_entries where child_id='66666666-6666-4666-8666-666666666666' group by transaction_id) e where entry_total<>0) then raise exception 'A task reward ledger transaction is unbalanced'; end if;
end $test$;

reset role;
rollback;
