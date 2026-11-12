create table public.diary_prompts (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  question text not null check (char_length(btrim(question)) between 3 and 180),
  position integer not null default 0,
  created_at timestamptz not null default now()
);
create index diary_prompts_family_position_idx on public.diary_prompts(family_id, position, created_at);

create table public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null,
  entry_date date not null,
  answers jsonb not null default '[]'::jsonb
    check (jsonb_typeof(answers) = 'array' and jsonb_array_length(answers) <= 16),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint diary_entries_child_family_fkey foreign key (child_id, family_id)
    references public.profiles(id, family_id) on delete cascade,
  constraint diary_entries_one_per_child_per_day unique (child_id, entry_date)
);
create index diary_entries_family_date_idx on public.diary_entries(family_id, entry_date desc);
create index diary_entries_child_date_idx on public.diary_entries(child_id, entry_date desc);

alter table public.diary_prompts enable row level security;
alter table public.diary_entries enable row level security;

create policy diary_prompts_family_read on public.diary_prompts
  for select to authenticated
  using (public.is_family_parent(family_id) or public.is_family_child(family_id));
create policy diary_prompts_parent_insert on public.diary_prompts
  for insert to authenticated
  with check (public.is_family_parent(family_id));
create policy diary_prompts_parent_update on public.diary_prompts
  for update to authenticated
  using (public.is_family_parent(family_id))
  with check (public.is_family_parent(family_id));
create policy diary_prompts_parent_delete on public.diary_prompts
  for delete to authenticated
  using (public.is_family_parent(family_id));

create policy diary_entries_family_read on public.diary_entries
  for select to authenticated
  using (
    (child_id = (select auth.uid()) and public.is_family_child(family_id))
    or public.is_family_parent(family_id)
  );
create policy diary_entries_child_insert on public.diary_entries
  for insert to authenticated
  with check (child_id = (select auth.uid()) and public.is_family_child(family_id));
create policy diary_entries_child_update on public.diary_entries
  for update to authenticated
  using (child_id = (select auth.uid()) and public.is_family_child(family_id))
  with check (child_id = (select auth.uid()) and public.is_family_child(family_id));

grant select, insert, update, delete on public.diary_prompts to authenticated;
grant select, insert, update on public.diary_entries to authenticated;

create or replace function public.seed_diary_prompts_for_family()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.diary_prompts(family_id, question, position)
  values
    (new.id, '¿Qué aprendiste hoy?', 1),
    (new.id, '¿Cuál fue tu parte favorita del día?', 2),
    (new.id, '¿Cómo te sentiste hoy?', 3);
  return new;
end
$$;
revoke all on function public.seed_diary_prompts_for_family() from public, anon, authenticated;
create trigger families_seed_diary_prompts
  after insert on public.families
  for each row execute function public.seed_diary_prompts_for_family();

insert into public.diary_prompts(family_id, question, position)
select f.id, prompt.question, prompt.position
from public.families f
cross join (values
  ('¿Qué aprendiste hoy?', 1),
  ('¿Cuál fue tu parte favorita del día?', 2),
  ('¿Cómo te sentiste hoy?', 3)
) as prompt(question, position)
where not exists (select 1 from public.diary_prompts p where p.family_id = f.id);
