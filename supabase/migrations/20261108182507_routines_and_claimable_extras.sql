-- Routines and claimable one-off extras for Mi Banquito.
create unique index if not exists profiles_id_family_idx on public.profiles(id,family_id);
create unique index if not exists tasks_id_family_idx on public.tasks(id,family_id);

create table public.routines (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 100),
  description text not null default '',
  assigned_child_id uuid,
  weekdays integer[] not null default array[1,2,3,4,5],
  payout_mode text not null check (payout_mode in ('PER_ACTIVITY','WHOLE_ROUTINE')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(id,family_id),
  foreign key (assigned_child_id,family_id) references public.profiles(id,family_id) on delete restrict,
  check (cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7])
);
create index routines_family_active_idx on public.routines(family_id,active);

create table public.routine_activities (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  routine_id uuid not null,
  title text not null check (length(btrim(title)) between 1 and 120),
  description text not null default '',
  amount integer not null check (amount > 0),
  position integer not null default 0 check (position >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(id,routine_id),
  foreign key (routine_id,family_id) references public.routines(id,family_id) on delete restrict
);
create index routine_activities_order_idx on public.routine_activities(routine_id,active,position);

create table public.routine_submissions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  routine_id uuid not null,
  child_id uuid not null,
  scheduled_date date not null,
  payout_mode text not null check (payout_mode in ('PER_ACTIVITY','WHOLE_ROUTINE')),
  total_amount integer not null check (total_amount > 0),
  status public.request_status not null default 'PENDING',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text,
  unique(routine_id,child_id,scheduled_date),
  unique(id,routine_id,family_id),
  foreign key (routine_id,family_id) references public.routines(id,family_id) on delete restrict,
  foreign key (child_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create index routine_submissions_family_status_idx on public.routine_submissions(family_id,status,submitted_at desc);
create index routine_submissions_child_date_idx on public.routine_submissions(child_id,scheduled_date desc);

create table public.routine_submission_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  routine_id uuid not null,
  submission_id uuid not null,
  activity_id uuid not null,
  title_snapshot text not null,
  amount_snapshot integer not null check (amount_snapshot > 0),
  status public.request_status not null default 'PENDING',
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text,
  created_at timestamptz not null default now(),
  foreign key (submission_id,routine_id,family_id) references public.routine_submissions(id,routine_id,family_id) on delete restrict,
  foreign key (activity_id,routine_id) references public.routine_activities(id,routine_id) on delete restrict
);
create index routine_submission_items_submission_idx on public.routine_submission_items(submission_id,status);

create type public.extra_claim_status as enum ('CLAIMED','PENDING','APPROVED','REJECTED','RELEASED');
create table public.extra_task_claims (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  task_id uuid not null,
  child_id uuid not null,
  title_snapshot text not null,
  amount_snapshot integer not null check (amount_snapshot > 0),
  status public.extra_claim_status not null default 'CLAIMED',
  claimed_at timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text,
  foreign key (task_id,family_id) references public.tasks(id,family_id) on delete restrict,
  foreign key (child_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create unique index extra_task_one_open_claim_idx on public.extra_task_claims(task_id) where status in ('CLAIMED','PENDING');
create index extra_task_claims_family_status_idx on public.extra_task_claims(family_id,status,claimed_at desc);
create index extra_task_claims_child_date_idx on public.extra_task_claims(child_id,claimed_at desc);

alter table public.routines enable row level security;
alter table public.routine_activities enable row level security;
alter table public.routine_submissions enable row level security;
alter table public.routine_submission_items enable row level security;
alter table public.extra_task_claims enable row level security;

create policy routines_read on public.routines for select to authenticated using (
  public.is_family_parent(family_id) or public.is_family_child(family_id)
);
create policy routine_activities_read on public.routine_activities for select to authenticated using (
  public.is_family_parent(family_id) or public.is_family_child(family_id)
);
create policy routine_submissions_read on public.routine_submissions for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
create policy routine_submission_items_read on public.routine_submission_items for select to authenticated using (
  exists(select 1 from public.routine_submissions s where s.id=submission_id and
    (public.is_family_parent(s.family_id) or public.is_self_child(s.child_id)))
);
create policy extra_task_claims_read on public.extra_task_claims for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);

revoke all on table public.routines,public.routine_activities,public.routine_submissions,
  public.routine_submission_items,public.extra_task_claims from anon,authenticated;
grant select on table public.routines,public.routine_activities,public.routine_submissions,
  public.routine_submission_items,public.extra_task_claims to authenticated;

create or replace function public.save_routine(
  routine_uuid uuid,
  routine_title text,
  routine_description text,
  child_uuid uuid,
  routine_weekdays integer[],
  routine_payout_mode text,
  activities jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  family_uuid uuid;
  saved_routine uuid;
  activity jsonb;
  activity_uuid uuid;
  keep_ids uuid[] := array[]::uuid[];
  activity_count integer;
begin
  select p.family_id into family_uuid from public.profiles p
  where p.id=(select auth.uid()) and p.role='PARENT' and p.is_active;
  if family_uuid is null then raise exception 'NOT_AUTHORIZED'; end if;
  if length(btrim(coalesce(routine_title,''))) not between 1 and 100 then raise exception 'INVALID_ROUTINE_TITLE'; end if;
  if routine_payout_mode not in ('PER_ACTIVITY','WHOLE_ROUTINE') then raise exception 'INVALID_PAYOUT_MODE'; end if;
  if routine_weekdays is null or cardinality(routine_weekdays) not between 1 and 7
     or exists(select 1 from unnest(routine_weekdays) d where d not between 1 and 7)
     or cardinality(routine_weekdays) <> (select count(distinct d) from unnest(routine_weekdays) d) then
    raise exception 'INVALID_WEEKDAYS';
  end if;
  if child_uuid is not null and not exists(select 1 from public.profiles p where p.id=child_uuid and p.family_id=family_uuid and p.role='CHILD') then
    raise exception 'CHILD_NOT_IN_FAMILY';
  end if;
  if jsonb_typeof(activities) <> 'array' or jsonb_array_length(activities) < 1 then raise exception 'ROUTINE_NEEDS_ACTIVITIES'; end if;

  if routine_uuid is null then
    insert into public.routines(family_id,title,description,assigned_child_id,weekdays,payout_mode)
    values(family_uuid,btrim(routine_title),left(coalesce(routine_description,''),500),child_uuid,routine_weekdays,routine_payout_mode)
    returning id into saved_routine;
  else
    update public.routines set title=btrim(routine_title),description=left(coalesce(routine_description,''),500),
      assigned_child_id=child_uuid,weekdays=routine_weekdays,payout_mode=routine_payout_mode
    where id=routine_uuid and family_id=family_uuid returning id into saved_routine;
    if saved_routine is null then raise exception 'NOT_AUTHORIZED'; end if;
  end if;

  activity_count := 0;
  for activity in select value from jsonb_array_elements(activities) loop
    activity_count := activity_count + 1;
    if length(btrim(coalesce(activity->>'title',''))) not between 1 and 120
       or coalesce((activity->>'amount')::integer,0) <= 0 then raise exception 'INVALID_ROUTINE_ACTIVITY'; end if;
    activity_uuid := nullif(activity->>'id','')::uuid;
    if activity_uuid is null then
      insert into public.routine_activities(family_id,routine_id,title,description,amount,position)
      values(family_uuid,saved_routine,btrim(activity->>'title'),left(coalesce(activity->>'description',''),500),
        (activity->>'amount')::integer,activity_count-1) returning id into activity_uuid;
    else
      update public.routine_activities set title=btrim(activity->>'title'),description=left(coalesce(activity->>'description',''),500),
        amount=(activity->>'amount')::integer,position=activity_count-1,active=true
      where id=activity_uuid and routine_id=saved_routine and family_id=family_uuid;
      if not found then raise exception 'INVALID_ROUTINE_ACTIVITY'; end if;
    end if;
    keep_ids := array_append(keep_ids,activity_uuid);
  end loop;
  update public.routine_activities set active=false where routine_id=saved_routine and family_id=family_uuid
    and active and not (id=any(keep_ids));
  return saved_routine;
end
$$;

create or replace function public.set_routine_active(routine_uuid uuid, make_active boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.routines set active=make_active
  where id=routine_uuid and public.is_family_parent(family_id);
  if not found then raise exception 'NOT_AUTHORIZED'; end if;
end
$$;

create or replace function public.submit_routine(routine_uuid uuid, activity_uuids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  r public.routines;
  child_family uuid;
  local_day date := (now() at time zone 'America/Mexico_City')::date;
  local_weekday integer;
  active_count integer;
  selected_count integer;
  total integer;
  submission_uuid uuid;
begin
  perform 1 from public.profiles p where p.id=(select auth.uid()) and p.role='CHILD' and p.is_active for update;
  if not found then raise exception 'CHILD_ONLY'; end if;
  select family_id into child_family from public.profiles where id=(select auth.uid());
  select * into r from public.routines where id=routine_uuid and family_id=child_family and active for share;
  if not found then raise exception 'ROUTINE_UNAVAILABLE'; end if;
  if r.assigned_child_id is not null and r.assigned_child_id<>(select auth.uid()) then raise exception 'ROUTINE_NOT_ASSIGNED'; end if;
  local_weekday := extract(isodow from local_day)::integer;
  if not (r.weekdays @> array[local_weekday]) then raise exception 'ROUTINE_NOT_SCHEDULED_TODAY'; end if;
  select count(*) into active_count from public.routine_activities where routine_id=r.id and family_id=r.family_id and active;
  selected_count := coalesce(cardinality(activity_uuids),0);
  if active_count=0 or selected_count=0 or selected_count<>(select count(distinct id) from unnest(activity_uuids) id) then
    raise exception 'INVALID_ROUTINE_ACTIVITIES';
  end if;
  if exists(select 1 from unnest(activity_uuids) id where not exists(
    select 1 from public.routine_activities a where a.id=id and a.routine_id=r.id and a.family_id=r.family_id and a.active)) then
    raise exception 'INVALID_ROUTINE_ACTIVITIES';
  end if;
  if r.payout_mode='WHOLE_ROUTINE' and selected_count<>active_count then raise exception 'ROUTINE_NOT_COMPLETE'; end if;
  select sum(amount) into total from public.routine_activities where id=any(activity_uuids) and routine_id=r.id and active;
  insert into public.routine_submissions(family_id,routine_id,child_id,scheduled_date,payout_mode,total_amount)
  values(r.family_id,r.id,(select auth.uid()),local_day,r.payout_mode,total) returning id into submission_uuid;
  insert into public.routine_submission_items(family_id,routine_id,submission_id,activity_id,title_snapshot,amount_snapshot)
  select r.family_id,r.id,submission_uuid,a.id,a.title,a.amount from public.routine_activities a
  where a.id=any(activity_uuids) and a.routine_id=r.id and a.active order by a.position;
  return submission_uuid;
end
$$;

create or replace function public.review_routine_activity_item(item_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare i public.routine_submission_items; s public.routine_submissions; tx uuid; pending_count integer; approved_count integer;
begin
  select * into i from public.routine_submission_items where id=item_uuid for update;
  if not found then raise exception 'NOT_AUTHORIZED'; end if;
  select * into s from public.routine_submissions where id=i.submission_id for update;
  if not public.is_family_parent(s.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if s.payout_mode<>'PER_ACTIVITY' then raise exception 'WRONG_PAYOUT_MODE'; end if;
  if i.status<>'PENDING' or s.status<>'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  if approve then
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(s.family_id,s.child_id,'TASK_REWARD',i.amount_snapshot,'Rutina · '||i.title_snapshot,i.id,(select auth.uid())) returning id into tx;
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,s.family_id,s.child_id,'available',i.amount_snapshot);
    update public.profiles set xp=xp+10 where id=s.child_id;
    perform public.unlock_achievements(s.child_id);
  end if;
  update public.routine_submission_items set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where id=i.id;
  select count(*) filter(where status='PENDING'),count(*) filter(where status='APPROVED') into pending_count,approved_count
    from public.routine_submission_items where submission_id=s.id;
  if pending_count=0 then
    update public.routine_submissions set status=case when approved_count>0 then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
      reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where id=s.id;
  end if;
end
$$;

create or replace function public.review_routine_completion(submission_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare s public.routine_submissions; tx uuid; item_count integer; snapshot_total bigint;
begin
  select * into s from public.routine_submissions where id=submission_uuid for update;
  if not found or not public.is_family_parent(s.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if s.payout_mode<>'WHOLE_ROUTINE' then raise exception 'WRONG_PAYOUT_MODE'; end if;
  if s.status<>'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  select count(*),coalesce(sum(amount_snapshot),0) into item_count,snapshot_total from public.routine_submission_items where submission_id=s.id;
  if item_count=0 or snapshot_total<>s.total_amount then raise exception 'INVALID_ROUTINE_SNAPSHOT'; end if;
  if approve then
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(s.family_id,s.child_id,'TASK_REWARD',s.total_amount,'Rutina completada',s.id,(select auth.uid())) returning id into tx;
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,s.family_id,s.child_id,'available',s.total_amount);
    update public.profiles set xp=xp+(item_count*10) where id=s.child_id;
  end if;
  update public.routine_submission_items set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where submission_id=s.id;
  update public.routine_submissions set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where id=s.id;
  if approve then perform public.unlock_achievements(s.child_id); end if;
end
$$;

create or replace function public.claim_extra_task(task_uuid uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare t public.tasks; family_uuid uuid; claim_uuid uuid;
begin
  perform 1 from public.profiles p where p.id=(select auth.uid()) and p.role='CHILD' and p.is_active for update;
  if not found then raise exception 'CHILD_ONLY'; end if;
  select family_id into family_uuid from public.profiles where id=(select auth.uid());
  select * into t from public.tasks where id=task_uuid and family_id=family_uuid and active for update;
  if not found then raise exception 'TASK_UNAVAILABLE'; end if;
  if t.assigned_child_id is not null and t.assigned_child_id<>(select auth.uid()) then raise exception 'TASK_NOT_ASSIGNED'; end if;
  insert into public.extra_task_claims(family_id,task_id,child_id,title_snapshot,amount_snapshot)
  values(t.family_id,t.id,(select auth.uid()),t.title,t.amount) returning id into claim_uuid;
  return claim_uuid;
exception when unique_violation then raise exception 'TASK_ALREADY_CLAIMED';
end
$$;

create or replace function public.submit_extra_task_claim(claim_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.extra_task_claims set status='PENDING',submitted_at=now()
  where id=claim_uuid and child_id=(select auth.uid()) and status='CLAIMED'
    and public.is_self_child(child_id);
  if not found then raise exception 'CLAIM_NOT_SUBMITTABLE'; end if;
end
$$;

create or replace function public.review_extra_task_claim(claim_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare c public.extra_task_claims; tx uuid;
begin
  select * into c from public.extra_task_claims where id=claim_uuid for update;
  if not found or not public.is_family_parent(c.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if c.status<>'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  if approve then
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(c.family_id,c.child_id,'TASK_REWARD',c.amount_snapshot,'Extra · '||c.title_snapshot,c.id,(select auth.uid())) returning id into tx;
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,c.family_id,c.child_id,'available',c.amount_snapshot);
    update public.profiles set xp=xp+10 where id=c.child_id;
    update public.tasks set active=false where id=c.task_id and family_id=c.family_id;
    perform public.unlock_achievements(c.child_id);
  end if;
  update public.extra_task_claims set status=case when approve then 'APPROVED'::public.extra_claim_status else 'REJECTED'::public.extra_claim_status end,
    reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where id=c.id;
end
$$;

create or replace function public.release_extra_task_claim(claim_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.extra_task_claims;
begin
  select * into c from public.extra_task_claims where id=claim_uuid for update;
  if not found or (c.child_id<>(select auth.uid()) and not public.is_family_parent(c.family_id)) then raise exception 'NOT_AUTHORIZED'; end if;
  if c.status<>'CLAIMED' then raise exception 'CLAIM_CANNOT_BE_RELEASED'; end if;
  update public.extra_task_claims set status='RELEASED' where id=c.id;
end
$$;

revoke all on function public.save_routine(uuid,text,text,uuid,integer[],text,jsonb) from public,anon,authenticated;
revoke all on function public.set_routine_active(uuid,boolean) from public,anon,authenticated;
revoke all on function public.submit_routine(uuid,uuid[]) from public,anon,authenticated;
revoke all on function public.review_routine_activity_item(uuid,boolean,text) from public,anon,authenticated;
revoke all on function public.review_routine_completion(uuid,boolean,text) from public,anon,authenticated;
revoke all on function public.claim_extra_task(uuid) from public,anon,authenticated;
revoke all on function public.submit_extra_task_claim(uuid) from public,anon,authenticated;
revoke all on function public.review_extra_task_claim(uuid,boolean,text) from public,anon,authenticated;
revoke all on function public.release_extra_task_claim(uuid) from public,anon,authenticated;
grant execute on function public.save_routine(uuid,text,text,uuid,integer[],text,jsonb) to authenticated;
grant execute on function public.set_routine_active(uuid,boolean) to authenticated;
grant execute on function public.submit_routine(uuid,uuid[]) to authenticated;
grant execute on function public.review_routine_activity_item(uuid,boolean,text) to authenticated;
grant execute on function public.review_routine_completion(uuid,boolean,text) to authenticated;
grant execute on function public.claim_extra_task(uuid) to authenticated;
grant execute on function public.submit_extra_task_claim(uuid) to authenticated;
grant execute on function public.review_extra_task_claim(uuid,boolean,text) to authenticated;
grant execute on function public.release_extra_task_claim(uuid) to authenticated;
