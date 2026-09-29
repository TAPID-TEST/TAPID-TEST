-- ============================================
-- TAPID SPRINT 6.11
-- University aggregate analytics layer
-- ============================================

-- University administrators are manually approved. There is intentionally
-- no public signup/insert policy for this table.
create table if not exists public.university_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  school_name text not null,
  admin_name text,
  created_at timestamptz not null default now()
);

alter table public.university_admins enable row level security;

drop policy if exists "University admins can view own admin record" on public.university_admins;
create policy "University admins can view own admin record"
on public.university_admins
for select to authenticated
using (user_id = auth.uid());

-- University auth users should not receive student profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data->>'user_type', 'student') in ('employer', 'university') then
    return new;
  end if;

  insert into public.profiles (id, username, first_name, last_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'username',''), 'user-' || left(new.id::text, 8)),
    nullif(new.raw_user_meta_data->>'first_name',''),
    nullif(new.raw_user_meta_data->>'last_name','')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- Helper used internally by aggregate functions.
create or replace function public.current_university_school()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ua.school_name
  from public.university_admins ua
  where ua.user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.current_university_school() from public;
grant execute on function public.current_university_school() to authenticated;

-- High-level dashboard metrics.
create or replace function public.university_overview()
returns table (
  students bigint,
  connected_students bigint,
  professional_connections bigint,
  employers bigint,
  events bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then
    raise exception 'University administrator access required';
  end if;

  return query
  select
    (select count(*)
       from public.profiles p
      where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
        and p.onboarding_complete = true)::bigint,
    (select count(distinct ec.student_user_id)
       from public.employer_connections ec
       join public.profiles p on p.id = ec.student_user_id
      where lower(trim(coalesce(p.school,''))) = lower(trim(v_school)))::bigint,
    (select count(*)
       from public.employer_connections ec
       join public.profiles p on p.id = ec.student_user_id
      where lower(trim(coalesce(p.school,''))) = lower(trim(v_school)))::bigint,
    (select count(distinct ec.company_id)
       from public.employer_connections ec
       join public.profiles p on p.id = ec.student_user_id
      where lower(trim(coalesce(p.school,''))) = lower(trim(v_school)))::bigint,
    (select count(distinct lower(trim(ec.event_name)))
       from public.employer_connections ec
       join public.profiles p on p.id = ec.student_user_id
      where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
        and nullif(trim(coalesce(ec.event_name,'')), '') is not null)::bigint;
end;
$$;

create or replace function public.university_company_engagement()
returns table (
  company_name text,
  connections bigint,
  students bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;

  return query
  select c.name,
         count(ec.id)::bigint,
         count(distinct ec.student_user_id)::bigint
    from public.employer_connections ec
    join public.companies c on c.id = ec.company_id
    join public.profiles p on p.id = ec.student_user_id
   where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
   group by c.id, c.name
   order by count(ec.id) desc, c.name asc;
end;
$$;

create or replace function public.university_event_engagement()
returns table (
  event_name text,
  connections bigint,
  students bigint,
  employers bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;

  return query
  select coalesce(nullif(trim(ec.event_name),''), 'Unspecified') as event_name,
         count(ec.id)::bigint,
         count(distinct ec.student_user_id)::bigint,
         count(distinct ec.company_id)::bigint
    from public.employer_connections ec
    join public.profiles p on p.id = ec.student_user_id
   where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
   group by coalesce(nullif(trim(ec.event_name),''), 'Unspecified')
   order by count(ec.id) desc, event_name asc;
end;
$$;

create or replace function public.university_major_engagement()
returns table (
  major text,
  connections bigint,
  students bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;

  return query
  select coalesce(nullif(trim(p.major),''), 'Unspecified') as major,
         count(ec.id)::bigint,
         count(distinct ec.student_user_id)::bigint
    from public.employer_connections ec
    join public.profiles p on p.id = ec.student_user_id
   where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
   group by coalesce(nullif(trim(p.major),''), 'Unspecified')
   order by count(ec.id) desc, major asc;
end;
$$;

create or replace function public.university_year_engagement()
returns table (
  school_year text,
  connections bigint,
  students bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;

  return query
  select coalesce(nullif(trim(p.school_year),''), 'Unspecified') as school_year,
         count(ec.id)::bigint,
         count(distinct ec.student_user_id)::bigint
    from public.employer_connections ec
    join public.profiles p on p.id = ec.student_user_id
   where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
   group by coalesce(nullif(trim(p.school_year),''), 'Unspecified')
   order by count(ec.id) desc, school_year asc;
end;
$$;

-- Aggregate recruiter pipeline signals. These are NOT student-reported career outcomes.
create or replace function public.university_recruiter_signals()
returns table (
  candidate_status text,
  connections bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;

  return query
  select ec.candidate_status,
         count(ec.id)::bigint
    from public.employer_connections ec
    join public.profiles p on p.id = ec.student_user_id
   where lower(trim(coalesce(p.school,''))) = lower(trim(v_school))
   group by ec.candidate_status
   order by count(ec.id) desc;
end;
$$;

revoke all on function public.university_overview() from public;
revoke all on function public.university_company_engagement() from public;
revoke all on function public.university_event_engagement() from public;
revoke all on function public.university_major_engagement() from public;
revoke all on function public.university_year_engagement() from public;
revoke all on function public.university_recruiter_signals() from public;

grant execute on function public.university_overview() to authenticated;
grant execute on function public.university_company_engagement() to authenticated;
grant execute on function public.university_event_engagement() to authenticated;
grant execute on function public.university_major_engagement() to authenticated;
grant execute on function public.university_year_engagement() to authenticated;
grant execute on function public.university_recruiter_signals() to authenticated;

-- IMPORTANT: no SELECT policy is added for university admins on employer_connections,
-- profiles, or private student connections. University reporting is served only
-- through the aggregate functions above.
