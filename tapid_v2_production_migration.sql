-- TapID V2 production migration
-- Apply after the Sprint 6.13 migration. Designed to be idempotent.

begin;

-- ------------------------------------------------------------
-- Profile, privacy, and verification
-- ------------------------------------------------------------

alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists avatar_is_public boolean not null default true,
  add column if not exists show_location boolean not null default true,
  add column if not exists show_experiences boolean not null default true,
  add column if not exists show_projects boolean not null default true,
  add column if not exists show_skills boolean not null default true,
  add column if not exists show_organizations boolean not null default true,
  add column if not exists show_certifications boolean not null default true,
  add column if not exists show_recommendations boolean not null default true,
  add column if not exists show_outcomes boolean not null default false,
  add column if not exists alumni_since integer;

alter table public.employer_recruiters
  add column if not exists verification_status text not null default 'pending'
    check (verification_status in ('pending','verified','rejected')),
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references auth.users(id) on delete set null;

alter table public.university_admins
  add column if not exists verification_status text not null default 'verified'
    check (verification_status in ('pending','verified','rejected'));

-- Keep section-level privacy enforceable at the API layer, not only in the UI.
drop view if exists public.public_contacts;
create view public.public_contacts as
select c.user_id,
       case when c.show_email then c.email end as email,
       case when c.show_phone then c.phone end as phone,
       case when c.show_website then c.website end as website,
       case when p.show_location then c.city end as city,
       case when p.show_location then c.state end as state
from public.contacts c join public.profiles p on p.id=c.user_id
where p.profile_active and p.card_activated;
grant select on public.public_contacts to anon,authenticated;

drop policy if exists "Public can view public experiences" on public.experiences;
create policy "Public can view public experiences" on public.experiences for select to anon,authenticated
using (user_id=auth.uid() or (is_public and exists(select 1 from public.profiles p where p.id=user_id and p.profile_active and p.card_activated and p.show_experiences)));
drop policy if exists "Public can view public projects" on public.projects;
create policy "Public can view public projects" on public.projects for select to anon,authenticated
using (user_id=auth.uid() or (is_public and exists(select 1 from public.profiles p where p.id=user_id and p.profile_active and p.card_activated and p.show_projects)));
drop policy if exists "Public can view public skills" on public.skills;
create policy "Public can view public skills" on public.skills for select to anon,authenticated
using (user_id=auth.uid() or (is_public and exists(select 1 from public.profiles p where p.id=user_id and p.profile_active and p.card_activated and p.show_skills)));
drop policy if exists "Public can view public organizations" on public.organizations;
create policy "Public can view public organizations" on public.organizations for select to anon,authenticated
using (user_id=auth.uid() or (is_public and exists(select 1 from public.profiles p where p.id=user_id and p.profile_active and p.card_activated and p.show_organizations)));
drop policy if exists "Public can view public certifications" on public.certifications;
create policy "Public can view public certifications" on public.certifications for select to anon,authenticated
using (user_id=auth.uid() or (is_public and exists(select 1 from public.profiles p where p.id=user_id and p.profile_active and p.card_activated and p.show_certifications)));

drop policy if exists "Public can view visible experience skill links" on public.experience_skills;
create policy "Public can view visible experience skill links" on public.experience_skills for select to anon,authenticated using(exists(
  select 1 from public.experiences e join public.skills s on s.id=skill_id and s.user_id=e.user_id join public.profiles p on p.id=e.user_id
  where e.id=experience_id and (e.user_id=auth.uid() or (e.is_public and s.is_public and p.profile_active and p.card_activated and p.show_experiences and p.show_skills))
));
drop policy if exists "Public can view visible project skill links" on public.project_skills;
create policy "Public can view visible project skill links" on public.project_skills for select to anon,authenticated using(exists(
  select 1 from public.projects pr join public.skills s on s.id=skill_id and s.user_id=pr.user_id join public.profiles p on p.id=pr.user_id
  where pr.id=project_id and (pr.user_id=auth.uid() or (pr.is_public and s.is_public and p.profile_active and p.card_activated and p.show_projects and p.show_skills))
));

drop policy if exists "Public can view visible media" on public.media;
create policy "Public can view visible media" on public.media for select to anon,authenticated using(
  user_id=auth.uid()
  or exists(select 1 from public.experiences e join public.profiles p on p.id=e.user_id where e.id=experience_id and e.user_id=media.user_id and e.is_public and p.profile_active and p.card_activated and p.show_experiences)
  or exists(select 1 from public.projects pr join public.profiles p on p.id=pr.user_id where pr.id=project_id and pr.user_id=media.user_id and pr.is_public and p.profile_active and p.card_activated and p.show_projects)
  or exists(select 1 from public.certifications c join public.profiles p on p.id=c.user_id where c.id=certification_id and c.user_id=media.user_id and c.is_public and p.profile_active and p.card_activated and p.show_certifications)
);

-- ------------------------------------------------------------
-- University-managed career fairs and employer registration
-- ------------------------------------------------------------

create table if not exists public.career_fairs (
  id bigint generated always as identity primary key,
  school_name text not null,
  name text not null,
  starts_at timestamptz,
  ends_at timestamptz,
  location text,
  description text,
  is_published boolean not null default false,
  created_by uuid not null references public.university_admins(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_name, name, starts_at)
);

create table if not exists public.career_fair_employers (
  id bigint generated always as identity primary key,
  career_fair_id bigint not null references public.career_fairs(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete cascade,
  requested_by uuid references public.employer_recruiters(user_id) on delete set null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  booth text,
  approved_by uuid references public.university_admins(user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (career_fair_id, company_id)
);

alter table public.employer_connection_requests
  add column if not exists career_fair_id bigint references public.career_fairs(id) on delete set null;

alter table public.employer_connections
  add column if not exists career_fair_id bigint references public.career_fairs(id) on delete set null;

create table if not exists public.card_issuance (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  school_name text not null,
  issued_by uuid not null references public.university_admins(user_id) on delete restrict,
  card_serial text not null unique,
  issued_at timestamptz not null default now(),
  activated_at timestamptz,
  status text not null default 'issued' check (status in ('issued','activated','lost','replaced','revoked')),
  notes text,
  unique (student_user_id, card_serial)
);

-- ------------------------------------------------------------
-- Recommendations and student-reported outcomes
-- ------------------------------------------------------------

create table if not exists public.recommendations (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  experience_id bigint references public.experiences(id) on delete cascade,
  project_id bigint references public.projects(id) on delete cascade,
  author_name text not null,
  author_title text,
  author_organization text,
  author_email text,
  relationship text,
  recommendation_text text,
  letter_path text,
  status text not null default 'draft' check (status in ('draft','requested','submitted')),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (((experience_id is not null)::int + (project_id is not null)::int) <= 1)
);

create table if not exists public.career_outcomes (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  career_fair_id bigint references public.career_fairs(id) on delete set null,
  employer_connection_id bigint references public.employer_connections(id) on delete set null,
  outcome_type text not null check (outcome_type in ('interview','internship','offer','accepted_offer','job')),
  company_name text not null,
  title text,
  outcome_date date,
  notes text,
  is_public boolean not null default false,
  verification_status text not null default 'student_reported'
    check (verification_status in ('student_reported','verified','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.career_fairs enable row level security;
alter table public.career_fair_employers enable row level security;
alter table public.card_issuance enable row level security;
alter table public.recommendations enable row level security;
alter table public.career_outcomes enable row level security;

-- Student-owned records.
drop policy if exists "Students manage own recommendations" on public.recommendations;
create policy "Students manage own recommendations" on public.recommendations
for all to authenticated using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

drop policy if exists "Public can view public recommendations" on public.recommendations;
create policy "Public can view public recommendations" on public.recommendations
for select to anon, authenticated using (
  is_public = true and status = 'submitted' and exists (
    select 1 from public.profiles p where p.id = student_user_id
      and p.profile_active and p.card_activated and p.show_recommendations
  )
);

drop policy if exists "Students manage own outcomes" on public.career_outcomes;
create policy "Students manage own outcomes" on public.career_outcomes
for all to authenticated using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

drop policy if exists "Public can view public outcomes" on public.career_outcomes;
create policy "Public can view public outcomes" on public.career_outcomes
for select to anon, authenticated using (
  is_public = true and exists (
    select 1 from public.profiles p where p.id = student_user_id
      and p.profile_active and p.card_activated and p.show_outcomes
  )
);

-- Published fairs are visible to relevant students and verified employers.
drop policy if exists "Published career fairs are visible" on public.career_fairs;
create policy "Published career fairs are visible" on public.career_fairs
for select to authenticated using (
  is_published = true
  or exists (select 1 from public.university_admins ua where ua.user_id = auth.uid() and lower(trim(ua.school_name)) = lower(trim(career_fairs.school_name)))
);

drop policy if exists "University admins manage career fairs" on public.career_fairs;
create policy "University admins manage career fairs" on public.career_fairs
for all to authenticated
using (exists (select 1 from public.university_admins ua where ua.user_id = auth.uid() and ua.verification_status = 'verified' and lower(trim(ua.school_name)) = lower(trim(career_fairs.school_name))))
with check (exists (select 1 from public.university_admins ua where ua.user_id = auth.uid() and ua.verification_status = 'verified' and lower(trim(ua.school_name)) = lower(trim(career_fairs.school_name))));

drop policy if exists "Participants view career fair employers" on public.career_fair_employers;
create policy "Participants view career fair employers" on public.career_fair_employers
for select to authenticated using (
  status = 'approved'
  or exists (select 1 from public.employer_recruiters er where er.user_id = auth.uid() and er.company_id = career_fair_employers.company_id)
  or exists (
    select 1 from public.career_fairs cf join public.university_admins ua on lower(trim(ua.school_name)) = lower(trim(cf.school_name))
    where cf.id = career_fair_id and ua.user_id = auth.uid()
  )
);

drop policy if exists "Employers register for fairs" on public.career_fair_employers;
create policy "Employers register for fairs" on public.career_fair_employers
for insert to authenticated with check (
  exists (select 1 from public.employer_recruiters er where er.user_id = auth.uid() and er.company_id = company_id and er.verification_status = 'verified')
);

drop policy if exists "University admins review fair employers" on public.career_fair_employers;
create policy "University admins review fair employers" on public.career_fair_employers
for update to authenticated
using (exists (
  select 1 from public.career_fairs cf join public.university_admins ua on lower(trim(ua.school_name)) = lower(trim(cf.school_name))
  where cf.id = career_fair_id and ua.user_id = auth.uid() and ua.verification_status = 'verified'
))
with check (exists (
  select 1 from public.career_fairs cf join public.university_admins ua on lower(trim(ua.school_name)) = lower(trim(cf.school_name))
  where cf.id = career_fair_id and ua.user_id = auth.uid() and ua.verification_status = 'verified'
));

drop policy if exists "Students view own card issuance" on public.card_issuance;
create policy "Students view own card issuance" on public.card_issuance
for select to authenticated using (student_user_id = auth.uid());

drop policy if exists "University admins manage card issuance" on public.card_issuance;
create policy "University admins manage card issuance" on public.card_issuance
for all to authenticated
using (exists (select 1 from public.university_admins ua where ua.user_id=auth.uid() and ua.verification_status='verified' and lower(trim(ua.school_name))=lower(trim(card_issuance.school_name))))
with check (exists (select 1 from public.university_admins ua where ua.user_id=auth.uid() and ua.verification_status='verified' and lower(trim(ua.school_name))=lower(trim(card_issuance.school_name))));

-- ------------------------------------------------------------
-- Private object storage with policy-controlled signed URLs
-- ------------------------------------------------------------

update storage.buckets set public = false where id in ('resumes','media');
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('avatars','avatars',false,5242880,array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Owners manage avatar objects" on storage.objects;
create policy "Owners manage avatar objects" on storage.objects for all to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "Visible avatars can be read" on storage.objects;
create policy "Visible avatars can be read" on storage.objects for select to anon, authenticated
using (bucket_id='avatars' and exists (
  select 1 from public.profiles p where p.id::text=(storage.foldername(name))[1]
    and p.profile_active and p.card_activated and p.avatar_is_public and p.avatar_path=name
));

drop policy if exists "Visible resume objects can be read" on storage.objects;
create policy "Visible resume objects can be read" on storage.objects for select to anon, authenticated
using (bucket_id='resumes' and exists (
  select 1 from public.resumes r join public.profiles p on p.id=r.user_id
  where r.file_path=name and r.is_public and p.profile_active and p.card_activated
));

drop policy if exists "Owners manage resume objects" on storage.objects;
create policy "Owners manage resume objects" on storage.objects for all to authenticated
using (bucket_id='resumes' and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='resumes' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "Owners manage media objects" on storage.objects;
create policy "Owners manage media objects" on storage.objects for all to authenticated
using (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);

-- Link recommendation documents into the existing media table before the
-- object-access policy references the new parent type.
alter table public.media add column if not exists recommendation_id bigint references public.recommendations(id) on delete cascade;
alter table public.media drop constraint if exists media_parent_check;
alter table public.media add constraint media_parent_check check (
  ((experience_id is not null)::int + (project_id is not null)::int +
   (certification_id is not null)::int + (recommendation_id is not null)::int) = 1
);

drop policy if exists "Public can view visible media" on public.media;
create policy "Public can view visible media" on public.media for select to anon,authenticated using(
  user_id=auth.uid()
  or exists(select 1 from public.experiences e join public.profiles p on p.id=e.user_id where e.id=experience_id and e.user_id=media.user_id and e.is_public and p.profile_active and p.card_activated and p.show_experiences)
  or exists(select 1 from public.projects pr join public.profiles p on p.id=pr.user_id where pr.id=project_id and pr.user_id=media.user_id and pr.is_public and p.profile_active and p.card_activated and p.show_projects)
  or exists(select 1 from public.certifications c join public.profiles p on p.id=c.user_id where c.id=certification_id and c.user_id=media.user_id and c.is_public and p.profile_active and p.card_activated and p.show_certifications)
  or exists(select 1 from public.recommendations r join public.profiles p on p.id=r.student_user_id where r.id=recommendation_id and r.student_user_id=media.user_id and r.is_public and r.status='submitted' and p.profile_active and p.card_activated and p.show_recommendations)
);

drop policy if exists "Visible media objects can be read" on storage.objects;
create policy "Visible media objects can be read" on storage.objects for select to anon, authenticated
using (bucket_id='media' and exists (
  select 1 from public.media m join public.profiles p on p.id=m.user_id
  where m.file_path=name and p.profile_active and p.card_activated and (
    exists (select 1 from public.experiences e where e.id=m.experience_id and e.is_public and p.show_experiences)
    or exists (select 1 from public.projects pr where pr.id=m.project_id and pr.is_public and p.show_projects)
    or exists (select 1 from public.certifications c where c.id=m.certification_id and c.is_public and p.show_certifications)
    or exists (select 1 from public.recommendations rec where rec.id=m.recommendation_id and rec.is_public and rec.status='submitted' and p.show_recommendations)
  )
));

-- ------------------------------------------------------------
-- Account lifecycle
-- ------------------------------------------------------------

create or replace function public.delete_my_tapid_account()
returns void language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  delete from storage.objects where bucket_id in ('avatars','resumes','media') and (storage.foldername(name))[1]=v_uid::text;
  delete from auth.users where id=v_uid;
end;
$$;
revoke all on function public.delete_my_tapid_account() from public;
grant execute on function public.delete_my_tapid_account() to authenticated;

-- Aggregate student-reported outcomes without exposing individual records.
create or replace function public.university_outcome_summary()
returns table (outcome_type text, outcomes bigint, verified bigint)
language plpgsql stable security definer set search_path=public as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;
  return query
  select o.outcome_type, count(*)::bigint,
         count(*) filter (where o.verification_status='verified')::bigint
  from public.career_outcomes o join public.profiles p on p.id=o.student_user_id
  where lower(trim(coalesce(p.school,'')))=lower(trim(v_school))
  group by o.outcome_type order by count(*) desc;
end;
$$;
revoke all on function public.university_outcome_summary() from public;
grant execute on function public.university_outcome_summary() to authenticated;

create or replace function public.register_company_for_fair(p_career_fair_id bigint)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_recruiter public.employer_recruiters; v_id bigint;
begin
  select * into v_recruiter from public.employer_recruiters where user_id=auth.uid();
  if not found then raise exception 'Employer account required'; end if;
  if not exists(select 1 from public.career_fairs where id=p_career_fair_id and is_published) then raise exception 'Career fair is unavailable'; end if;
  insert into public.career_fair_employers(career_fair_id,company_id,requested_by)
  values(p_career_fair_id,v_recruiter.company_id,auth.uid())
  on conflict(career_fair_id,company_id) do update set requested_by=auth.uid(),status='pending',updated_at=now()
  returning id into v_id;
  return v_id;
end;$$;
revoke all on function public.register_company_for_fair(bigint) from public;
grant execute on function public.register_company_for_fair(bigint) to authenticated;

create or replace function public.university_registration_inbox()
returns table(registration_id bigint,career_fair_id bigint,event_name text,company_id bigint,company_name text,status text,requested_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
declare v_school text;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;
  return query select cfe.id,cf.id,cf.name,c.id,c.name,cfe.status,cfe.created_at
  from public.career_fair_employers cfe join public.career_fairs cf on cf.id=cfe.career_fair_id join public.companies c on c.id=cfe.company_id
  where lower(trim(cf.school_name))=lower(trim(v_school)) order by cfe.created_at desc;
end;$$;
revoke all on function public.university_registration_inbox() from public;
grant execute on function public.university_registration_inbox() to authenticated;

create or replace function public.review_fair_registration(p_registration_id bigint,p_status text,p_booth text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_school text;
begin
  if p_status not in ('approved','rejected') then raise exception 'Invalid review status'; end if;
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;
  update public.career_fair_employers cfe set status=p_status,booth=nullif(trim(coalesce(p_booth,'')),''),approved_by=auth.uid(),updated_at=now()
  from public.career_fairs cf where cfe.id=p_registration_id and cf.id=cfe.career_fair_id and lower(trim(cf.school_name))=lower(trim(v_school));
  if not found then raise exception 'Registration not found'; end if;
  if p_status='approved' then
    update public.employer_recruiters er set verification_status='verified',verified_at=coalesce(er.verified_at,now()),verified_by=auth.uid(),updated_at=now()
    from public.career_fair_employers cfe where cfe.id=p_registration_id and er.company_id=cfe.company_id;
  end if;
end;$$;
revoke all on function public.review_fair_registration(bigint,text,text) from public;
grant execute on function public.review_fair_registration(bigint,text,text) to authenticated;

create or replace function public.issue_tapid_card(p_username text,p_card_serial text,p_notes text default null)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_school text;v_student uuid;v_id bigint;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;
  select p.id into v_student from public.profiles p where lower(p.username)=lower(trim(p_username)) and lower(trim(p.school))=lower(trim(v_school));
  if v_student is null then raise exception 'No student at your university has that TapID username'; end if;
  insert into public.card_issuance(student_user_id,school_name,issued_by,card_serial,notes)
  values(v_student,v_school,auth.uid(),trim(p_card_serial),nullif(trim(coalesce(p_notes,'')),'')) returning id into v_id;
  return v_id;
end;$$;
revoke all on function public.issue_tapid_card(text,text,text) from public;
grant execute on function public.issue_tapid_card(text,text,text) to authenticated;

create or replace function public.activate_issued_tapid_card(p_card_serial text)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.card_issuance set status='activated',activated_at=now()
  where student_user_id=auth.uid() and card_serial=trim(p_card_serial) and status='issued';
  if not found then raise exception 'Card serial was not issued to this account or is already unavailable'; end if;
  update public.profiles set card_activated=true,profile_active=true,activated_at=now(),updated_at=now() where id=auth.uid();
end;$$;
revoke all on function public.activate_issued_tapid_card(text) from public;
grant execute on function public.activate_issued_tapid_card(text) to authenticated;

create or replace function public.enforce_verified_recruiter_connection()
returns trigger language plpgsql set search_path=public as $$
begin
  if not exists(select 1 from public.employer_recruiters er where er.user_id=new.recruiter_user_id and er.verification_status='verified') then
    raise exception 'Verified employer account required';
  end if;
  return new;
end;$$;
drop trigger if exists require_verified_recruiter_connection on public.employer_connections;
create trigger require_verified_recruiter_connection before insert on public.employer_connections
for each row execute function public.enforce_verified_recruiter_connection();

-- Official student directory: only approved employers at published fairs for
-- the student's own university. Recruiter contact details never leave this RPC.
create or replace function public.student_event_employer_directory()
returns table(event_name text,company_id bigint,company_name text,request_status text,request_id bigint)
language plpgsql stable security definer set search_path=public as $$
declare v_school text;
begin
  select p.school into v_school from public.profiles p where p.id=auth.uid();
  if v_school is null then raise exception 'Student account required'; end if;
  return query select cf.name,c.id,c.name,req.status,req.id
  from public.career_fairs cf join public.career_fair_employers cfe on cfe.career_fair_id=cf.id and cfe.status='approved'
  join public.companies c on c.id=cfe.company_id
  left join public.employer_connection_requests req on req.student_user_id=auth.uid() and req.company_id=c.id and req.career_fair_id=cf.id
  where cf.is_published and lower(trim(cf.school_name))=lower(trim(v_school))
  order by cf.starts_at nulls last,lower(c.name);
end;$$;
revoke all on function public.student_event_employer_directory() from public;
grant execute on function public.student_event_employer_directory() to authenticated;

create or replace function public.request_employer_connection(p_company_id bigint,p_event_name text,p_message text)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_id bigint;v_fair_id bigint;v_message text:=nullif(trim(coalesce(p_message,'')),'');
begin
  if auth.uid() is null or not exists(select 1 from public.profiles p where p.id=auth.uid() and p.profile_active and p.card_activated) then raise exception 'An active student TapID is required'; end if;
  if v_message is null or char_length(v_message)>500 then raise exception 'Message must contain 1 to 500 characters'; end if;
  select cf.id into v_fair_id from public.career_fairs cf
  join public.career_fair_employers cfe on cfe.career_fair_id=cf.id and cfe.company_id=p_company_id and cfe.status='approved'
  join public.profiles p on p.id=auth.uid()
  where cf.is_published and lower(trim(cf.name))=lower(trim(p_event_name)) and lower(trim(cf.school_name))=lower(trim(p.school)) limit 1;
  if v_fair_id is null then raise exception 'This employer is not approved for that event'; end if;
  insert into public.employer_connection_requests(student_user_id,company_id,event_name,message,career_fair_id)
  values(auth.uid(),p_company_id,trim(p_event_name),v_message,v_fair_id) returning id into v_id;
  return v_id;
exception when unique_violation then raise exception 'You already sent this employer a request for this event';
end;$$;
revoke all on function public.request_employer_connection(bigint,text,text) from public;
grant execute on function public.request_employer_connection(bigint,text,text) to authenticated;

grant select,insert,update,delete on public.career_fairs,public.career_fair_employers,public.card_issuance,public.recommendations,public.career_outcomes to authenticated;
grant usage,select on all sequences in schema public to authenticated;

commit;
