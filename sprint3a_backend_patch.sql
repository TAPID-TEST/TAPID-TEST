-- TapID Sprint 3A: make media metadata follow the visibility of its parent.
-- The Storage bucket itself remains public for this prototype; this policy
-- prevents anonymous API enumeration of media attached to hidden content.

drop policy if exists "Public can view media" on public.media;

create policy "Public can view visible media"
on public.media
for select
to anon, authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.experiences e
    join public.profiles p on p.id = e.user_id
    where e.id = experience_id
      and e.user_id = media.user_id
      and e.is_public = true
      and p.profile_active = true
  )
  or exists (
    select 1
    from public.projects pr
    join public.profiles p on p.id = pr.user_id
    where pr.id = project_id
      and pr.user_id = media.user_id
      and pr.is_public = true
      and p.profile_active = true
  )
);
