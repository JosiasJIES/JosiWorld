-- Run in the Supabase SQL editor as the database owner. The transaction rolls back
-- all temporary Auth users, families, child invites, and seeded tasks at the end.
begin;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111','authenticated','authenticated','codex-rls-a-20261108@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Isolation Test A"}',now(),now()),
  ('22222222-2222-4222-8222-222222222222','authenticated','authenticated','codex-rls-b-20261108@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Isolation Test B"}',now(),now());

insert into public.child_invites(token,family_id,username,display_name) values
  ('33333333-3333-4333-8333-333333333333',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'test_child_a','Test Child A'),
  ('44444444-4444-4444-8444-444444444444',(select family_id from public.profiles where id='11111111-1111-4111-8111-111111111111'),'test_child_a2','Test Child A2'),
  ('55555555-5555-4555-8555-555555555555',(select family_id from public.profiles where id='22222222-2222-4222-8222-222222222222'),'test_child_b','Test Child B');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('66666666-6666-4666-8666-666666666666','authenticated','authenticated','test_child_a@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"33333333-3333-4333-8333-333333333333"}',now(),now()),
  ('77777777-7777-4777-8777-777777777777','authenticated','authenticated','test_child_a2@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"44444444-4444-4444-8444-444444444444"}',now(),now()),
  ('88888888-8888-4888-8888-888888888888','authenticated','authenticated','test_child_b@kids.mibanquito.invalid','',now(),'{"provider":"email","providers":["email"]}','{"child_invite_token":"55555555-5555-4555-8555-555555555555"}',now(),now());

select set_config('request.test.task_b',(select t.id::text from public.tasks t join public.profiles p on p.family_id=t.family_id where p.id='22222222-2222-4222-8222-222222222222' limit 1),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $test$ begin
  if (select count(*) from public.families) <> 1 then raise exception 'Parent A must see exactly their own family'; end if;
  if exists(select 1 from public.families where owner_id='22222222-2222-4222-8222-222222222222') then raise exception 'Parent A can see family B'; end if;
  if (select count(*) from public.tasks) <> 5 then raise exception 'Parent A must see only their five seeded tasks'; end if;
  update public.profiles set display_name='Edited Test Child' where id='66666666-6666-4666-8666-666666666666';
  if not found then raise exception 'Parent must be able to edit their child profile'; end if;
end $test$;

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $test$ begin
  if (select count(*) from public.families) <> 1 then raise exception 'Parent B must see exactly their own family'; end if;
  if exists(select 1 from public.families where owner_id='11111111-1111-4111-8111-111111111111') then raise exception 'Parent B can see family A'; end if;
  if (select count(*) from public.tasks) <> 5 then raise exception 'Parent B must see only their five seeded tasks'; end if;
end $test$;

select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
do $test$ begin
  if (select count(*) from public.profiles where role='CHILD') <> 1 then raise exception 'Child A must not see sibling or other family profiles'; end if;
  if (select count(*) from public.tasks) <> 5 then raise exception 'Child A must see only their family tasks'; end if;
  update public.profiles set role='PARENT' where id='66666666-6666-4666-8666-666666666666';
  if found then raise exception 'Child changed their own role'; end if;
  begin
    perform public.request_task(current_setting('request.test.task_b')::uuid,'isolation test');
    raise exception 'Child A was able to submit a task from family B';
  exception when others then
    if sqlerrm = 'Child A was able to submit a task from family B' then raise; end if;
    if sqlerrm not like '%FAMILY_MISMATCH%' then raise; end if;
  end;
end $test$;

select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
do $test$ begin
  if (select count(*) from public.profiles where role='CHILD') <> 1 then raise exception 'Child B must not see children from family A'; end if;
  if (select count(*) from public.tasks) <> 5 then raise exception 'Child B must see only their family tasks'; end if;
end $test$;

reset role;
rollback;
