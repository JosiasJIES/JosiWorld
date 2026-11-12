drop index if exists public.diary_entries_child_date_idx;
create index diary_entries_child_family_date_idx
  on public.diary_entries(child_id, family_id, entry_date desc);
