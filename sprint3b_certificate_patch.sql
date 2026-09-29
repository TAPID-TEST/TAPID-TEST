-- TapID Sprint 3B - Certification document evidence
-- Adds certification attachments to the existing media system and allows PDFs in the media bucket.

alter table public.media
  add column if not exists certification_id bigint references public.certifications(id) on delete cascade;

alter table public.media
  drop constraint if exists media_parent_check;

alter table public.media
  add constraint media_parent_check check (
    ((experience_id is not null)::int +
     (project_id is not null)::int +
     (certification_id is not null)::int) = 1
  );

-- Keep the media bucket's existing image support and add PDF certificate documents.
update storage.buckets
set allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf']::text[]
where id = 'media';

-- Update public media metadata visibility so certification documents follow
-- the certification's public/private setting and the profile activation state.
drop policy if exists "Public can view visible media" on public.media;
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
  or exists (
    select 1
    from public.certifications c
    join public.profiles p on p.id = c.user_id
    where c.id = certification_id
      and c.user_id = media.user_id
      and c.is_public = true
      and p.profile_active = true
  )
);
