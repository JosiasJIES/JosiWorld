-- Preserve task history independently from the task definition.
alter table public.task_submissions
  add column task_title_snapshot text not null default '';
update public.task_submissions s
set task_title_snapshot = t.title
from public.tasks t
where s.task_id = t.id and s.task_title_snapshot = '';
alter table public.task_submissions alter column task_id drop not null;
alter table public.task_submissions drop constraint task_submissions_task_id_fkey;
alter table public.task_submissions add constraint task_submissions_task_id_fkey
  foreign key (task_id) references public.tasks(id) on delete set null;

alter table public.extra_task_claims alter column task_id drop not null;
alter table public.extra_task_claims drop constraint extra_task_claims_task_id_family_id_fkey;
alter table public.extra_task_claims add constraint extra_task_claims_task_id_family_id_fkey
  foreign key (task_id, family_id) references public.tasks(id, family_id)
  on delete set null (task_id);

create or replace function public.request_task(task_uuid uuid, submission_note text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare task_row public.tasks; submission_id uuid;
begin
  perform 1 from public.profiles where id=(select auth.uid()) and role='CHILD' and is_active for update;
  if not found then raise exception 'CHILD_ONLY'; end if;
  select * into task_row from public.tasks where id=task_uuid and active for share;
  if not found then raise exception 'TASK_UNAVAILABLE'; end if;
  if (select family_id from public.profiles where id=(select auth.uid())) <> task_row.family_id then raise exception 'FAMILY_MISMATCH'; end if;
  if task_row.assigned_child_id is not null and task_row.assigned_child_id <> (select auth.uid()) then raise exception 'TASK_NOT_ASSIGNED'; end if;
  if task_row.frequency='once' and exists(select 1 from public.task_submissions where task_id=task_uuid and child_id=(select auth.uid()) and status <> 'REJECTED') then raise exception 'TASK_ALREADY_DONE'; end if;
  if task_row.frequency='daily' and exists(select 1 from public.task_submissions where task_id=task_uuid and child_id=(select auth.uid()) and status <> 'REJECTED' and submitted_at >= date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') then raise exception 'TASK_ALREADY_DONE_TODAY'; end if;
  insert into public.task_submissions(family_id,task_id,task_title_snapshot,child_id,note,amount_snapshot)
  values(task_row.family_id,task_row.id,task_row.title,(select auth.uid()),left(coalesce(submission_note,''),500),task_row.amount)
  returning id into submission_id;
  return submission_id;
end
$$;
