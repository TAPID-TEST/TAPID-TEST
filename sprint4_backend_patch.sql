-- ============================================
-- TAPID SPRINT 4 BACKEND PATCH
-- Two-way connections hardening
-- ============================================

-- Visitors may create a connection for an active profile, but they may not
-- write the private_notes field. Only the profile owner can later edit notes.
drop policy if exists "Visitors can submit connections" on public.connections;

create policy "Visitors can submit connections"
on public.connections
for insert
to anon, authenticated
with check (
  private_notes is null
  and exists (
    select 1
    from public.profiles p
    where p.id = profile_owner_id
      and p.profile_active = true
  )
);
