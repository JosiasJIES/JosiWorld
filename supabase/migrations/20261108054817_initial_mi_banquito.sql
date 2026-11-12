create extension if not exists pgcrypto with schema extensions;

create type public.app_role as enum ('PARENT', 'CHILD');
create type public.request_status as enum ('PENDING', 'APPROVED', 'REJECTED');
create type public.ledger_kind as enum ('TASK_REWARD', 'REDEMPTION', 'SAVINGS_DEPOSIT', 'SAVINGS_WITHDRAWAL', 'ADJUSTMENT');

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Mi familia',
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  currency_name text not null default 'MON',
  currency_symbol text not null default 'M',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  role public.app_role not null,
  display_name text not null,
  username text unique,
  avatar text not null default '🦊',
  birth_date date,
  is_active boolean not null default true,
  xp integer not null default 0 check (xp >= 0),
  created_at timestamptz not null default now(),
  constraint child_username_required check (role <> 'CHILD' or username is not null)
);
create index profiles_family_role_idx on public.profiles(family_id, role);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  description text not null default '',
  amount integer not null check (amount > 0),
  category text not null default 'Responsabilidades',
  frequency text not null default 'once' check (frequency in ('once','daily','weekly','custom')),
  due_at timestamptz,
  assigned_child_id uuid references public.profiles(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index tasks_family_active_idx on public.tasks(family_id, active);

create table public.task_submissions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete restrict,
  child_id uuid not null references public.profiles(id) on delete restrict,
  status public.request_status not null default 'PENDING',
  note text not null default '',
  amount_snapshot integer not null check (amount_snapshot > 0),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text
);
create index task_submissions_family_status_idx on public.task_submissions(family_id, status, submitted_at desc);
create index task_submissions_task_child_date_idx on public.task_submissions(task_id, child_id, submitted_at desc);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  description text not null default '',
  price integer not null check (price > 0),
  category text not null default 'Experiencias',
  assigned_child_id uuid references public.profiles(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index rewards_family_active_idx on public.rewards(family_id, active);

create table public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  reward_id uuid not null references public.rewards(id) on delete restrict,
  child_id uuid not null references public.profiles(id) on delete restrict,
  status public.request_status not null default 'PENDING',
  price_snapshot integer not null check (price_snapshot > 0),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text
);
create index redemptions_family_status_idx on public.reward_redemptions(family_id, status, requested_at desc);

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  target_amount integer not null check (target_amount > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index savings_goals_child_idx on public.savings_goals(child_id, active);

create table public.ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.profiles(id) on delete restrict,
  kind public.ledger_kind not null,
  amount integer not null check (amount > 0),
  description text not null,
  source_id uuid,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(kind, source_id)
);
create index ledger_transactions_child_date_idx on public.ledger_transactions(child_id, created_at desc);

create table public.ledger_entries (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references public.ledger_transactions(id) on delete restrict,
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.profiles(id) on delete restrict,
  account text not null check (account in ('available','savings')),
  amount integer not null check (amount <> 0),
  goal_id uuid references public.savings_goals(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index ledger_entries_child_account_idx on public.ledger_entries(child_id, account);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text not null,
  xp_required integer not null default 0,
  tasks_required integer not null default 0
);
create table public.child_achievements (
  child_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete restrict,
  unlocked_at timestamptz not null default now(),
  primary key(child_id, achievement_id)
);

create table public.app_settings (
  family_id uuid primary key references public.families(id) on delete cascade,
  level_xp_step integer not null default 100 check (level_xp_step > 0),
  updated_at timestamptz not null default now()
);

create or replace function public.is_family_parent(target_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.family_id = target_family and p.role = 'PARENT' and p.is_active)
$$;

create or replace function public.is_family_child(target_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.family_id = target_family and p.role = 'CHILD' and p.is_active)
$$;

create or replace function public.is_self_child(target_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.id = target_id and p.role = 'CHILD' and p.is_active)
$$;

create or replace function public.handle_new_parent()
returns trigger language plpgsql security definer set search_path = '' as $$
declare family_id uuid;
begin
  insert into public.families(owner_id, name) values (new.id, coalesce(nullif(new.raw_user_meta_data->>'family_name',''), 'Mi familia')) returning id into family_id;
  insert into public.profiles(id, family_id, role, display_name) values (new.id, family_id, 'PARENT', coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1)));
  insert into public.app_settings(family_id) values (family_id);
  insert into public.tasks(family_id,title,description,amount,category) values
    (family_id,'Leer 10 páginas','Elige un libro y disfruta la lectura.',10,'Lectura'),
    (family_id,'Practicar matemáticas','Completa tu práctica de hoy.',15,'Matemáticas'),
    (family_id,'Ordenar materiales','Deja tu espacio listo.',5,'Hogar'),
    (family_id,'Aprender algo nuevo','Cuéntale a tu familia qué descubriste.',15,'Aprendizaje'),
    (family_id,'Avanzar en un proyecto','Dedica tiempo a una idea que te entusiasme.',20,'Proyectos');
  insert into public.rewards(family_id,title,description,price,category) values
    (family_id,'15 minutos de celular','Tiempo de pantalla acordado con tu familia.',40,'Tiempo de pantalla'),
    (family_id,'30 minutos de Minecraft','Una sesión de juego.',60,'Videojuegos'),
    (family_id,'20 minutos de Plants vs Zombies','Una sesión de juego.',40,'Videojuegos'),
    (family_id,'Salida al parque','Elige un parque para visitar.',150,'Experiencias'),
    (family_id,'Actividad familiar','Elijan juntos una actividad.',100,'Experiencias');
  return new;
end
$$;
create trigger on_auth_user_created_parent after insert on auth.users for each row execute function public.handle_new_parent();

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
  insert into public.task_submissions(family_id,task_id,child_id,note,amount_snapshot)
  values(task_row.family_id,task_row.id,(select auth.uid()),left(coalesce(submission_note,''),500),task_row.amount)
  returning id into submission_id;
  return submission_id;
end
$$;

create or replace function public.review_task(submission_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare s public.task_submissions;
begin
  select * into s from public.task_submissions where id=submission_uuid for update;
  if not found or not public.is_family_parent(s.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if s.status <> 'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  update public.task_submissions set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(), reviewed_by=(select auth.uid()), review_note=left(coalesce(decision_note,''),500) where id=s.id;
  if approve then
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(s.family_id,s.child_id,'TASK_REWARD',s.amount_snapshot,'Tarea aprobada',s.id,(select auth.uid()));
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    select id,s.family_id,s.child_id,'available',s.amount_snapshot from public.ledger_transactions where kind='TASK_REWARD' and source_id=s.id;
    update public.profiles set xp=xp+10 where id=s.child_id;
    insert into public.child_achievements(child_id,achievement_id)
    select s.child_id,a.id from public.achievements a where a.code='first_task'
    and (select count(*) from public.task_submissions ts where ts.child_id=s.child_id and ts.status='APPROVED')=1 on conflict do nothing;
  end if;
end
$$;

create or replace function public.request_redemption(reward_uuid uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare r public.rewards; reserved integer; available integer; redemption_id uuid;
begin
  perform 1 from public.profiles where id=(select auth.uid()) and role='CHILD' and is_active for update;
  if not found then raise exception 'NOT_AUTHORIZED'; end if;
  select * into r from public.rewards where id=reward_uuid and active for share;
  if not found or not public.is_self_child((select auth.uid())) then raise exception 'NOT_AUTHORIZED'; end if;
  if (select family_id from public.profiles where id=(select auth.uid())) <> r.family_id then raise exception 'FAMILY_MISMATCH'; end if;
  if r.assigned_child_id is not null and r.assigned_child_id <> (select auth.uid()) then raise exception 'REWARD_NOT_AVAILABLE'; end if;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=(select auth.uid()) and account='available';
  if available < r.price then raise exception 'INSUFFICIENT_BALANCE'; end if;
  insert into public.reward_redemptions(family_id,reward_id,child_id,price_snapshot)
  values(r.family_id,r.id,(select auth.uid()),r.price) returning id into redemption_id;
  return redemption_id;
end
$$;

create or replace function public.review_redemption(redemption_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare r public.reward_redemptions; available integer; tx uuid;
begin
  select * into r from public.reward_redemptions where id=redemption_uuid for update;
  if not found or not public.is_family_parent(r.family_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if r.status <> 'PENDING' then raise exception 'ALREADY_REVIEWED'; end if;
  if approve then
    perform 1 from public.profiles where id=r.child_id for update;
    select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=r.child_id and account='available';
    if available < r.price_snapshot then raise exception 'INSUFFICIENT_BALANCE'; end if;
    insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
    values(r.family_id,r.child_id,'REDEMPTION',r.price_snapshot,'Canje aprobado',r.id,(select auth.uid())) returning id into tx;
    insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount)
    values(tx,r.family_id,r.child_id,'available',-r.price_snapshot);
  end if;
  update public.reward_redemptions set status=case when approve then 'APPROVED'::public.request_status else 'REJECTED'::public.request_status end,
    reviewed_at=now(), reviewed_by=(select auth.uid()), review_note=left(coalesce(decision_note,''),500) where id=r.id;
end
$$;

create or replace function public.move_savings(goal_uuid uuid, amount_to_move integer, deposit boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare g public.savings_goals; available integer; tx uuid; k public.ledger_kind;
begin
  if amount_to_move <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  select * into g from public.savings_goals where id=goal_uuid and active for update;
  if not found or (g.child_id <> (select auth.uid()) and not public.is_family_parent(g.family_id)) then raise exception 'NOT_AUTHORIZED'; end if;
  perform 1 from public.profiles where id=g.child_id for update;
  select coalesce(sum(amount),0) into available from public.ledger_entries where child_id=g.child_id and account=case when deposit then 'available' else 'savings' end;
  if available < amount_to_move then raise exception 'INSUFFICIENT_BALANCE'; end if;
  k := case when deposit then 'SAVINGS_DEPOSIT'::public.ledger_kind else 'SAVINGS_WITHDRAWAL'::public.ledger_kind end;
  insert into public.ledger_transactions(family_id,child_id,kind,amount,description,source_id,created_by)
  values(g.family_id,g.child_id,k,amount_to_move,case when deposit then 'Ahorro para ' else 'Retiro de ' end||g.title,gen_random_uuid(),(select auth.uid())) returning id into tx;
  insert into public.ledger_entries(transaction_id,family_id,child_id,account,amount,goal_id) values
    (tx,g.family_id,g.child_id,case when deposit then 'available' else 'savings' end,-amount_to_move,g.id),
    (tx,g.family_id,g.child_id,case when deposit then 'savings' else 'available' end,amount_to_move,g.id);
end
$$;

create or replace view public.child_balances with (security_invoker=true) as
select p.id as child_id,p.family_id,
  coalesce(sum(e.amount) filter(where e.account='available'),0)::bigint as available_balance,
  coalesce(sum(e.amount) filter(where e.account='savings'),0)::bigint as savings_balance
from public.profiles p left join public.ledger_entries e on e.child_id=p.id where p.role='CHILD' group by p.id,p.family_id;

alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.task_submissions enable row level security;
alter table public.rewards enable row level security;
alter table public.reward_redemptions enable row level security;
alter table public.savings_goals enable row level security;
alter table public.ledger_transactions enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.achievements enable row level security;
alter table public.child_achievements enable row level security;
alter table public.app_settings enable row level security;

create policy family_select on public.families for select to authenticated using (public.is_family_parent(id) or public.is_family_child(id));
create policy family_update on public.families for update to authenticated using (public.is_family_parent(id)) with check (public.is_family_parent(id));
create policy profiles_select on public.profiles for select to authenticated using (id=(select auth.uid()) or (role='CHILD' and public.is_family_parent(family_id)));
create policy profiles_parent_update on public.profiles for update to authenticated using (role='CHILD' and public.is_family_parent(family_id)) with check (role='CHILD' and public.is_family_parent(family_id));
create policy tasks_read on public.tasks for select to authenticated using (public.is_family_parent(family_id) or (active and public.is_family_child(family_id) and (assigned_child_id is null or assigned_child_id=(select auth.uid()))));
create policy tasks_parent_write on public.tasks for all to authenticated using (public.is_family_parent(family_id)) with check (public.is_family_parent(family_id));
create policy task_submissions_read on public.task_submissions for select to authenticated using (public.is_family_parent(family_id) or child_id=(select auth.uid()));
create policy rewards_read on public.rewards for select to authenticated using (public.is_family_parent(family_id) or (active and public.is_family_child(family_id) and (assigned_child_id is null or assigned_child_id=(select auth.uid()))));
create policy rewards_parent_write on public.rewards for all to authenticated using (public.is_family_parent(family_id)) with check (public.is_family_parent(family_id));
create policy redemptions_read on public.reward_redemptions for select to authenticated using (public.is_family_parent(family_id) or child_id=(select auth.uid()));
create policy savings_read on public.savings_goals for select to authenticated using (child_id=(select auth.uid()) or public.is_family_parent(family_id));
create policy savings_parent_write on public.savings_goals for all to authenticated using (public.is_family_parent(family_id)) with check (public.is_family_parent(family_id));
create policy savings_child_create on public.savings_goals for insert to authenticated with check (child_id=(select auth.uid()) and public.is_family_child(family_id));
create policy ledger_tx_read on public.ledger_transactions for select to authenticated using (child_id=(select auth.uid()) or public.is_family_parent(family_id));
create policy ledger_entries_read on public.ledger_entries for select to authenticated using (child_id=(select auth.uid()) or public.is_family_parent(family_id));
create policy achievements_read on public.achievements for select to authenticated using (true);
create policy child_achievements_read on public.child_achievements for select to authenticated using (child_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=child_achievements.child_id and public.is_family_parent(p.family_id)));
create policy settings_read on public.app_settings for select to authenticated using (public.is_family_parent(family_id) or public.is_family_child(family_id));
create policy settings_parent_update on public.app_settings for update to authenticated using (public.is_family_parent(family_id)) with check (public.is_family_parent(family_id));

revoke all on public.ledger_transactions, public.ledger_entries from anon, authenticated;
grant select on public.ledger_transactions, public.ledger_entries to authenticated;
revoke insert, update, delete on public.profiles, public.task_submissions, public.reward_redemptions from anon, authenticated;
grant select on public.profiles, public.task_submissions, public.reward_redemptions to authenticated;
grant update(display_name, avatar, birth_date, is_active) on public.profiles to authenticated;
grant update(name, currency_name, currency_symbol) on public.families to authenticated;
grant insert(family_id, child_id, title, target_amount) on public.savings_goals to authenticated;
revoke all on function public.handle_new_parent() from public, anon, authenticated;
revoke all on function public.is_family_parent(uuid), public.is_family_child(uuid), public.is_self_child(uuid) from public, anon;
grant execute on function public.is_family_parent(uuid), public.is_family_child(uuid), public.is_self_child(uuid) to authenticated;
revoke all on function public.request_task(uuid,text), public.review_task(uuid,boolean,text), public.request_redemption(uuid), public.review_redemption(uuid,boolean,text), public.move_savings(uuid,integer,boolean) from public, anon;
grant execute on function public.request_task(uuid,text), public.review_task(uuid,boolean,text), public.request_redemption(uuid), public.review_redemption(uuid,boolean,text), public.move_savings(uuid,integer,boolean) to authenticated;
grant select on public.child_balances to authenticated;

insert into public.achievements(code,title,description,xp_required,tasks_required) values
('first_task','¡Primera tarea!','Completaste tu primera tarea aprobada.',0,1),
('xp_100','Aprendiz constante','Alcanza 100 puntos de experiencia.',100,0),
('xp_500','Gran ahorrador de experiencias','Alcanza 500 puntos de experiencia.',500,0)
on conflict(code) do nothing;
