-- Store the app's existing JSON backup as one private snapshot per account.
create table if not exists public.finance_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  schema_version integer not null default 1 check (schema_version >= 1),
  updated_at timestamptz not null default now()
);

alter table public.finance_backups enable row level security;
revoke all on public.finance_backups from anon;
grant select, insert, update, delete on public.finance_backups to authenticated;

drop policy if exists finance_backups_select_own on public.finance_backups;
create policy finance_backups_select_own
  on public.finance_backups for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists finance_backups_insert_own on public.finance_backups;
create policy finance_backups_insert_own
  on public.finance_backups for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists finance_backups_update_own on public.finance_backups;
create policy finance_backups_update_own
  on public.finance_backups for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists finance_backups_delete_own on public.finance_backups;
create policy finance_backups_delete_own
  on public.finance_backups for delete to authenticated
  using ((select auth.uid()) = user_id);
