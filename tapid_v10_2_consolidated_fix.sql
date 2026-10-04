-- TapID V10.2 consolidated employer-workspace compatibility patch
-- Safe to run more than once.
begin;

alter table public.companies
  add column if not exists description text,
  add column if not exists website text,
  add column if not exists careers_url text,
  add column if not exists employee_size text,
  add column if not exists culture text,
  add column if not exists student_message text,
  add column if not exists industries text[] not null default '{}',
  add column if not exists locations text[] not null default '{}',
  add column if not exists recruiting_majors text[] not null default '{}',
  add column if not exists opportunities text[] not null default '{}',
  add column if not exists updated_at timestamptz not null default now();

alter table public.employer_connections
  add column if not exists priority text not null default 'normal',
  add column if not exists relationship_owner text,
  add column if not exists next_follow_up_at timestamptz,
  add column if not exists next_action text,
  add column if not exists private_notes text,
  add column if not exists updated_at timestamptz not null default now();

grant update (
  description, website, careers_url, employee_size, culture,
  student_message, industries, locations, recruiting_majors,
  opportunities, updated_at
) on public.companies to authenticated;

grant update (
  candidate_status, priority, relationship_owner, next_follow_up_at,
  next_action, private_notes, updated_at
) on public.employer_connections to authenticated;

notify pgrst, 'reload schema';
commit;
