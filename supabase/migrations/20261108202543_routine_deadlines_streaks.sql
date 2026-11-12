-- Local deadlines and family-visible routine streak medals.
alter table public.routines
  add column deadline_time time not null default time '23:59';

alter table public.routine_submissions
  add column deadline_time_snapshot time not null default time '23:59';

create table public.routine_streaks (
  family_id uuid not null references public.families(id) on delete cascade,
  routine_id uuid not null,
  child_id uuid not null,
  current_streak integer not null default 0 check (current_streak >= 0),
  best_streak integer not null default 0 check (best_streak >= current_streak),
  last_completed_date date,
  updated_at timestamptz not null default now(),
  primary key (routine_id, child_id),
  foreign key (routine_id, family_id) references public.routines(id, family_id) on delete cascade,
  foreign key (child_id, family_id) references public.profiles(id, family_id) on delete cascade
);
create index routine_streaks_family_idx on public.routine_streaks(family_id, child_id);

create table public.routine_streak_medals (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  routine_id uuid not null,
  child_id uuid not null,
  milestone integer not null check (milestone in (3,7,14,30)),
  awarded_at timestamptz not null default now(),
  unique (routine_id, child_id, milestone),
  foreign key (routine_id, family_id) references public.routines(id, family_id) on delete cascade,
  foreign key (child_id, family_id) references public.profiles(id, family_id) on delete cascade
);
create index routine_streak_medals_family_idx on public.routine_streak_medals(family_id, child_id, awarded_at desc);

alter table public.routine_streaks enable row level security;
alter table public.routine_streak_medals enable row level security;
create policy routine_streaks_read on public.routine_streaks for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
create policy routine_streak_medals_read on public.routine_streak_medals for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
revoke all on table public.routine_streaks, public.routine_streak_medals from anon, authenticated;
grant select on table public.routine_streaks, public.routine_streak_medals to authenticated;

create function public.save_routine(
  routine_uuid uuid,
  routine_title text,
  routine_description text,
  child_uuid uuid,
  routine_weekdays integer[],
  routine_payout_mode text,
  deadline_at time,
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
  if deadline_at is null then raise exception 'INVALID_DEADLINE'; end if;
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
    insert into public.routines(family_id,title,description,assigned_child_id,weekdays,payout_mode,deadline_time)
    values(family_uuid,btrim(routine_title),left(coalesce(routine_description,''),500),child_uuid,routine_weekdays,routine_payout_mode,deadline_at)
    returning id into saved_routine;
  else
    update public.routines set title=btrim(routine_title),description=left(coalesce(routine_description,''),500),
      assigned_child_id=child_uuid,weekdays=routine_weekdays,payout_mode=routine_payout_mode,deadline_time=deadline_at
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

create or replace function public.submit_routine(routine_uuid uuid, activity_uuids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  r public.routines;
  child_family uuid;
  local_day date := (now() at time zone 'America/Mexico_City')::date;
  local_time time := (now() at time zone 'America/Mexico_City')::time;
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
  if local_time > r.deadline_time then raise exception 'ROUTINE_DEADLINE_PASSED'; end if;
  select count(*) into active_count from public.routine_activities where routine_id=r.id and family_id=r.family_id and active;
  selected_count := coalesce(cardinality(activity_uuids),0);
  if active_count=0 or selected_count=0 or selected_count<>(select count(distinct id) from unnest(activity_uuids) id) then
    raise exception 'INVALID_ROUTINE_ACTIVITIES';
  end if;
  if exists(select 1 from unnest(activity_uuids) id where not exists(
    select 1 from public.routine_activities a where a.id=id and a.routine_id=r.id and a.family_id=r.family_id and a.active)) then
    raise exception 'INVALID_ROUTINE_ACTIVITIES';
  end if;
  if selected_count<>active_count then raise exception 'ROUTINE_NOT_COMPLETE'; end if;
  select sum(amount) into total from public.routine_activities where id=any(activity_uuids) and routine_id=r.id and active;
  insert into public.routine_submissions(family_id,routine_id,child_id,scheduled_date,payout_mode,total_amount,deadline_time_snapshot)
  values(r.family_id,r.id,(select auth.uid()),local_day,r.payout_mode,total,r.deadline_time) returning id into submission_uuid;
  insert into public.routine_submission_items(family_id,routine_id,submission_id,activity_id,title_snapshot,amount_snapshot)
  select r.family_id,r.id,submission_uuid,a.id,a.title,a.amount from public.routine_activities a
  where a.id=any(activity_uuids) and a.routine_id=r.id and a.active order by a.position;
  return submission_uuid;
end
$$;

create function public.recalculate_routine_streak(routine_uuid uuid, child_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.routines;
  family_uuid uuid;
  first_day date;
  last_day date;
  current_day date;
  today_local date := (now() at time zone 'America/Mexico_City')::date;
  time_local time := (now() at time zone 'America/Mexico_City')::time;
  run_length integer := 0;
  best_length integer := 0;
  existing_best integer := 0;
  is_complete boolean;
begin
  select * into r from public.routines where id=routine_uuid;
  if not found then return; end if;
  family_uuid := r.family_id;
  select coalesce(best_streak,0) into existing_best from public.routine_streaks
    where routine_id=routine_uuid and child_id=child_uuid;
  select min(scheduled_date),max(scheduled_date) into first_day,last_day from public.routine_submissions
    where routine_id=routine_uuid and child_id=child_uuid and status='APPROVED';
  if first_day is null then
    insert into public.routine_streaks(family_id,routine_id,child_id,current_streak,best_streak,last_completed_date,updated_at)
    values(family_uuid,routine_uuid,child_uuid,0,coalesce(existing_best,0),null,now())
    on conflict (routine_id,child_id) do update set current_streak=0,updated_at=now();
    return;
  end if;
  best_length := coalesce(existing_best,0);
  for current_day in select d::date from generate_series(first_day,today_local,interval '1 day') d loop
    if extract(isodow from current_day)::integer = any(r.weekdays) then
      select exists(select 1 from public.routine_submissions s where s.routine_id=routine_uuid
        and s.child_id=child_uuid and s.scheduled_date=current_day and s.status='APPROVED') into is_complete;
      if is_complete then
        run_length := run_length+1;
        best_length := greatest(best_length,run_length);
        if run_length in (3,7,14,30) then
          insert into public.routine_streak_medals(family_id,routine_id,child_id,milestone)
          values(family_uuid,routine_uuid,child_uuid,run_length) on conflict (routine_id,child_id,milestone) do nothing;
        end if;
      elsif current_day<today_local or time_local>r.deadline_time then
        run_length := 0;
      else
        exit;
      end if;
    end if;
  end loop;
  insert into public.routine_streaks(family_id,routine_id,child_id,current_streak,best_streak,last_completed_date,updated_at)
  values(family_uuid,routine_uuid,child_uuid,run_length,best_length,last_day,now())
  on conflict (routine_id,child_id) do update set current_streak=excluded.current_streak,
    best_streak=greatest(public.routine_streaks.best_streak,excluded.best_streak),
    last_completed_date=excluded.last_completed_date,updated_at=now();
end
$$;

create or replace function public.review_routine_activity_item(item_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare i public.routine_submission_items; s public.routine_submissions; tx uuid; pending_count integer; approved_count integer; item_count integer;
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
  select count(*) filter(where status='PENDING'),count(*) filter(where status='APPROVED'),count(*)
    into pending_count,approved_count,item_count from public.routine_submission_items where submission_id=s.id;
  if pending_count=0 then
    update public.routine_submissions set status=case when approved_count=item_count then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
      reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=left(coalesce(decision_note,''),500) where id=s.id;
    if approved_count=item_count then perform public.recalculate_routine_streak(s.routine_id,s.child_id); end if;
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
  if approve then
    perform public.unlock_achievements(s.child_id);
    perform public.recalculate_routine_streak(s.routine_id,s.child_id);
  end if;
end
$$;

revoke all on function public.save_routine(uuid,text,text,uuid,integer[],text,time,jsonb) from public,anon,authenticated;
revoke all on function public.save_routine(uuid,text,text,uuid,integer[],text,jsonb) from public,anon,authenticated;
revoke all on function public.recalculate_routine_streak(uuid,uuid) from public,anon,authenticated;
grant execute on function public.save_routine(uuid,text,text,uuid,integer[],text,time,jsonb) to authenticated;
