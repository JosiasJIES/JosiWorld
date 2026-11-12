create table public.child_invites (
  token uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  username text not null unique,
  display_name text not null,
  avatar text not null default '🦊',
  birth_date date,
  created_at timestamptz not null default now()
);
alter table public.child_invites enable row level security;
revoke all on public.child_invites from anon, authenticated;
create index ledger_entries_goal_idx on public.ledger_entries(goal_id) where goal_id is not null;
create index task_submissions_child_idx on public.task_submissions(child_id, submitted_at desc);
create index redemptions_child_idx on public.reward_redemptions(child_id, requested_at desc);
create index ledger_entries_transaction_idx on public.ledger_entries(transaction_id);
create index ledger_entries_family_idx on public.ledger_entries(family_id);
create index ledger_transactions_family_idx on public.ledger_transactions(family_id);
create index child_achievements_achievement_idx on public.child_achievements(achievement_id);

create or replace function public.handle_new_parent()
returns trigger language plpgsql security definer set search_path = '' as $$
declare family_id uuid; invite public.child_invites;
begin
  if new.raw_user_meta_data ? 'child_invite_token' then
    select * into invite from public.child_invites where token=(new.raw_user_meta_data->>'child_invite_token')::uuid for update;
    if not found or split_part(new.email,'@',1) <> invite.username then raise exception 'INVALID_CHILD_INVITE'; end if;
    insert into public.profiles(id, family_id, role, display_name, username, avatar, birth_date)
    values(new.id, invite.family_id, 'CHILD', invite.display_name, invite.username, invite.avatar, invite.birth_date);
    delete from public.child_invites where token=invite.token;
    return new;
  end if;
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

create or replace function public.move_savings(goal_uuid uuid, amount_to_move integer, deposit boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare g public.savings_goals; available bigint; tx uuid; k public.ledger_kind;
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

create or replace function public.unlock_achievements(target_child uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare current_xp integer; approved_tasks integer;
begin
  select xp into current_xp from public.profiles where id=target_child and role='CHILD';
  select count(*) into approved_tasks from public.task_submissions where child_id=target_child and status='APPROVED';
  insert into public.child_achievements(child_id,achievement_id)
  select target_child,a.id from public.achievements a
  where current_xp >= a.xp_required and approved_tasks >= a.tasks_required
  on conflict(child_id,achievement_id) do nothing;
end
$$;
revoke all on function public.unlock_achievements(uuid) from public, anon, authenticated;

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
    perform public.unlock_achievements(s.child_id);
  end if;
end
$$;

create or replace function public.review_redemption(redemption_uuid uuid, approve boolean, decision_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare r public.reward_redemptions; available bigint; tx uuid;
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

revoke all on function public.handle_new_parent() from public, anon, authenticated;
revoke all on function public.unlock_achievements(uuid) from public, anon, authenticated;
