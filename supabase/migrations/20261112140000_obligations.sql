create table public.obligations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 100),
  description text not null default '',
  assigned_child_id uuid,
  weekdays integer[] not null default array[1,2,3,4,5],
  deadline_time time not null default time '23:59',
  penalty_amount integer not null check (penalty_amount > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(id,family_id),
  foreign key (assigned_child_id,family_id) references public.profiles(id,family_id) on delete restrict,
  check (cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7])
);
create index obligations_family_active_idx on public.obligations(family_id,active);

create table public.obligation_occurrences (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  obligation_id uuid not null,
  child_id uuid not null,
  scheduled_date date not null,
  status text not null check (status in ('COMPLETED','MISSED')),
  title_snapshot text not null,
  penalty_amount_snapshot integer not null check (penalty_amount_snapshot > 0),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(obligation_id,child_id,scheduled_date),
  foreign key (obligation_id,family_id) references public.obligations(id,family_id) on delete restrict,
  foreign key (child_id,family_id) references public.profiles(id,family_id) on delete restrict,
  check ((status='COMPLETED' and completed_at is not null) or (status='MISSED' and completed_at is null))
);
create index obligation_occurrences_child_date_idx on public.obligation_occurrences(child_id,scheduled_date desc);

alter table public.obligations enable row level security;
alter table public.obligation_occurrences enable row level security;
create policy obligations_read on public.obligations for select to authenticated using (
  public.is_family_parent(family_id) or public.is_family_child(family_id)
);
create policy obligations_parent_write on public.obligations for all to authenticated
  using (public.is_family_parent(family_id)) with check (public.is_family_parent(family_id));
create policy obligation_occurrences_read on public.obligation_occurrences for select to authenticated using (
  public.is_family_parent(family_id) or public.is_self_child(child_id)
);
revoke all on public.obligations,public.obligation_occurrences from anon,authenticated;
grant select,insert,update,delete on public.obligations to authenticated;
grant select on public.obligation_occurrences to authenticated;

create or replace function public.complete_obligation(obligation_uuid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.obligations; today_local date := (now() at time zone 'America/Mexico_City')::date; local_time time := (now() at time zone 'America/Mexico_City')::time; child_uuid uuid := (select auth.uid());
begin
  if not public.is_self_child(child_uuid) then raise exception 'CHILD_ONLY'; end if;
  select * into o from public.obligations where id=obligation_uuid and active;
  if not found or o.assigned_child_id is not null and o.assigned_child_id<>child_uuid then raise exception 'OBLIGATION_UNAVAILABLE'; end if;
  if not (extract(isodow from today_local)::integer = any(o.weekdays)) then raise exception 'OBLIGATION_NOT_SCHEDULED_TODAY'; end if;
  if local_time > o.deadline_time then raise exception 'OBLIGATION_DEADLINE_PASSED'; end if;
  insert into public.obligation_occurrences(family_id,obligation_id,child_id,scheduled_date,status,title_snapshot,penalty_amount_snapshot,completed_at)
  values(o.family_id,o.id,child_uuid,today_local,'COMPLETED',o.title,o.penalty_amount,now())
  on conflict (obligation_id,child_id,scheduled_date) do nothing;
  if not found then raise exception 'OBLIGATION_ALREADY_RESOLVED'; end if;
end
$$;
revoke all on function public.complete_obligation(uuid) from public,anon;
grant execute on function public.complete_obligation(uuid) to authenticated;

create or replace function public.process_due_obligations()
returns void language plpgsql security definer set search_path = '' as $$
declare
  today_local date := (now() at time zone 'America/Mexico_City')::date;
  local_time time := (now() at time zone 'America/Mexico_City')::time;
  item record;
  occurrence_uuid uuid;
  available_balance bigint;
  penalty_to_apply integer;
  transaction_uuid uuid;
begin
  for item in
    select o.id,o.family_id,o.title,o.penalty_amount,p.id as child_id
    from public.obligations o
    join public.profiles p on p.family_id=o.family_id and p.role='CHILD' and p.is_active
      and (o.assigned_child_id is null or o.assigned_child_id=p.id)
    where o.active
      and extract(isodow from today_local)::integer = any(o.weekdays)
      and o.deadline_time <= local_time
  loop
    occurrence_uuid := null;
    insert into public.obligation_occurrences(family_id,obligation_id,child_id,scheduled_date,status,title_snapshot,penalty_amount_snapshot)
    values(item.family_id,item.id,item.child_id,today_local,'MISSED',item.title,item.penalty_amount)
    on conflict (obligation_id,child_id,scheduled_date) do nothing
    returning id into occurrence_uuid;
    if occurrence_uuid is null then continue; end if;

    select coalesce(sum(amount),0) into available_balance
    from public.ledger_entries where child_id=item.child_id and account='available';
    penalty_to_apply := least(item.penalty_amount,greatest(available_balance,0))::integer;
    if penalty_to_apply > 0 then
      insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
      values(item.family_id,item.child_id,'ADJUSTMENT',penalty_to_apply,
        left('Obligación incumplida · '||item.title,250),occurrence_uuid,null)
      returning id into transaction_uuid;
      insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
      values(transaction_uuid,item.family_id,item.child_id,'available',-penalty_to_apply);
    end if;
  end loop;
end
$$;
revoke all on function public.process_due_obligations() from public,anon,authenticated;

create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('process-due-obligations','* * * * *','select public.process_due_obligations()');

