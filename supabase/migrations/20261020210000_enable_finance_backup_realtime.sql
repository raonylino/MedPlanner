-- Let authenticated app sessions learn about snapshot changes from the web
-- app (or another device). Realtime delivery still follows the table's RLS.
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'finance_backups'
  ) then
    alter publication supabase_realtime add table public.finance_backups;
  end if;
end;
$$;
