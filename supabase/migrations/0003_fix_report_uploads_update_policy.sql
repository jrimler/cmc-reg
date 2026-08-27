-- Fix: report_uploads had SELECT and INSERT policies but no UPDATE policy.
-- With RLS enabled and no UPDATE policy, Postgres silently matches zero rows
-- on any UPDATE from an app (non-superuser) session — no error, it just
-- does nothing. That's why row_count stayed stuck at its default of 0 even
-- though the actual report data inserted fine.

create policy "report_uploads updatable by admins only"
  on report_uploads for update
  to authenticated
  using (is_admin())
  with check (is_admin());
