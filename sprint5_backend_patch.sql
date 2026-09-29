-- ============================================
-- TAPID SPRINT 5 BACKEND PATCH
-- Orientation completion + card activation + public visibility hardening
-- ============================================

alter table public.profiles
  add column if not exists onboarding_complete boolean not null default false,
  add column if not exists card_activated boolean not null default false,
  add column if not exists activated_at timestamptz;

-- Preserve already-completed prototype accounts as onboarded.
update public.profiles
set onboarding_complete = true
where onboarding_complete = false
  and first_name is not null
  and last_name is not null
  and username is not null
  and school is not null
  and major is not null
  and school_year is not null
  and graduation_year is not null;

-- A profile is publicly discoverable only after card activation and while live.
drop policy if exists "Public can view active profiles" on public.profiles;
create policy "Public can view active profiles"
on public.profiles
for select
to anon, authenticated
using (
  id = auth.uid()
  or (profile_active = true and card_activated = true)
);

-- Public contact view follows both card activation and profile availability.
drop view if exists public.public_contacts;
create view public.public_contacts as
select
  c.user_id,
  case when c.show_email = true then c.email else null end as email,
  case when c.show_phone = true then c.phone else null end as phone,
  case when c.show_website = true then c.website else null end as website,
  c.city,
  c.state
from public.contacts c
join public.profiles p on p.id = c.user_id
where p.profile_active = true
  and p.card_activated = true;
grant select on public.public_contacts to anon, authenticated;

-- Helper pattern: public content requires an activated/live profile; owner can always read their own.
drop policy if exists "Public can view public resumes" on public.resumes;
create policy "Public can view public resumes" on public.resumes for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public links" on public.links;
create policy "Public can view public links" on public.links for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public experiences" on public.experiences;
create policy "Public can view public experiences" on public.experiences for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public projects" on public.projects;
create policy "Public can view public projects" on public.projects for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public skills" on public.skills;
create policy "Public can view public skills" on public.skills for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public organizations" on public.organizations;
create policy "Public can view public organizations" on public.organizations for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

drop policy if exists "Public can view public certifications" on public.certifications;
create policy "Public can view public certifications" on public.certifications for select to anon, authenticated
using (user_id = auth.uid() or (is_public = true and exists (select 1 from public.profiles p where p.id=user_id and p.profile_active=true and p.card_activated=true)));

-- Evidence-link visibility also follows activation/live state.
drop policy if exists "Public can view visible experience skill links" on public.experience_skills;
create policy "Public can view visible experience skill links"
on public.experience_skills for select to anon, authenticated
using (exists (
  select 1 from public.experiences e
  join public.skills s on s.id=skill_id and s.user_id=e.user_id
  join public.profiles p on p.id=e.user_id
  where e.id=experience_id
    and (e.user_id=auth.uid() or (e.is_public=true and s.is_public=true and p.profile_active=true and p.card_activated=true))
));

drop policy if exists "Public can view visible project skill links" on public.project_skills;
create policy "Public can view visible project skill links"
on public.project_skills for select to anon, authenticated
using (exists (
  select 1 from public.projects pr
  join public.skills s on s.id=skill_id and s.user_id=pr.user_id
  join public.profiles p on p.id=pr.user_id
  where pr.id=project_id
    and (pr.user_id=auth.uid() or (pr.is_public=true and s.is_public=true and p.profile_active=true and p.card_activated=true))
));

-- Media metadata visibility follows the visible parent and activated profile.
drop policy if exists "Public can view visible media" on public.media;
create policy "Public can view visible media"
on public.media for select to anon, authenticated
using (
  user_id=auth.uid()
  or exists (select 1 from public.experiences e join public.profiles p on p.id=e.user_id where e.id=experience_id and e.user_id=media.user_id and e.is_public=true and p.profile_active=true and p.card_activated=true)
  or exists (select 1 from public.projects pr join public.profiles p on p.id=pr.user_id where pr.id=project_id and pr.user_id=media.user_id and pr.is_public=true and p.profile_active=true and p.card_activated=true)
  or exists (select 1 from public.certifications c join public.profiles p on p.id=c.user_id where c.id=certification_id and c.user_id=media.user_id and c.is_public=true and p.profile_active=true and p.card_activated=true)
);

-- Visitors can connect only to a live, activated profile and cannot set private notes.
drop policy if exists "Visitors can submit connections" on public.connections;
create policy "Visitors can submit connections"
on public.connections for insert to anon, authenticated
with check (
  private_notes is null
  and exists (select 1 from public.profiles p where p.id=profile_owner_id and p.profile_active=true and p.card_activated=true)
);
