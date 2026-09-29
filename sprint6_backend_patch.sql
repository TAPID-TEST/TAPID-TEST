-- ============================================
-- TAPID SPRINT 6 BACKEND PATCH
-- Employer portal + mutual career-fair connections
-- ============================================

-- 1) Companies are normalized once so future university analytics do not split
--    simple casing/spacing variants such as "Kiewit" and "KIEWIT".
create table if not exists public.companies (
  id bigint generated always as identity primary key,
  name text not null,
  normalized_name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.employer_recruiters (
  user_id uuid primary key references auth.users(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete restrict,
  recruiter_name text not null,
  recruiter_email text not null,
  current_event_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employer_connections (
  id bigint generated always as identity primary key,
  company_id bigint not null references public.companies(id) on delete cascade,
  recruiter_user_id uuid not null references public.employer_recruiters(user_id) on delete cascade,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  event_name text,
  candidate_status text not null default 'connected'
    check (candidate_status in ('connected','follow_up','interview','offer','passed')),
  private_notes text,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Prevent repeated taps by the same recruiter from making duplicate rows for the same event.
create unique index if not exists employer_connections_unique_recruiter_student_event
on public.employer_connections (
  recruiter_user_id,
  student_user_id,
  coalesce(lower(event_name), '')
);

alter table public.companies enable row level security;
alter table public.employer_recruiters enable row level security;
alter table public.employer_connections enable row level security;

-- 2) Student account trigger: employer auth users should NOT receive student profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data->>'user_type', 'student') = 'employer' then
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

-- 3) Employer registration RPC. It normalizes company names centrally.
create or replace function public.register_employer(
  p_company_name text,
  p_recruiter_name text,
  p_recruiter_email text
)
returns public.employer_recruiters
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id bigint;
  v_normalized text;
  v_row public.employer_recruiters;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_normalized := lower(regexp_replace(trim(p_company_name), '\\s+', ' ', 'g'));
  if v_normalized = '' or trim(coalesce(p_recruiter_name,'')) = '' or trim(coalesce(p_recruiter_email,'')) = '' then
    raise exception 'Company, recruiter name, and email are required';
  end if;

  insert into public.companies (name, normalized_name)
  values (trim(p_company_name), v_normalized)
  on conflict (normalized_name) do update set name = public.companies.name
  returning id into v_company_id;

  insert into public.employer_recruiters (user_id, company_id, recruiter_name, recruiter_email)
  values (auth.uid(), v_company_id, trim(p_recruiter_name), trim(p_recruiter_email))
  on conflict (user_id) do update set
    company_id = excluded.company_id,
    recruiter_name = excluded.recruiter_name,
    recruiter_email = excluded.recruiter_email,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.register_employer(text,text,text) to authenticated;

-- 4) Mutual employer/student connection RPC.
--    One action saves the student to the employer portal AND creates a student-side
--    connection so the student can see the recruiter/company in My Connections.
create or replace function public.connect_employer_to_student(p_student_user_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recruiter public.employer_recruiters;
  v_company public.companies;
  v_student public.profiles;
  v_employer_connection_id bigint;
  v_event text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_recruiter
  from public.employer_recruiters
  where user_id = auth.uid();

  if not found then
    raise exception 'Employer account required';
  end if;

  select * into v_company from public.companies where id = v_recruiter.company_id;
  select * into v_student from public.profiles where id = p_student_user_id;

  if not found or v_student.profile_active is not true or v_student.card_activated is not true then
    raise exception 'Student profile is unavailable';
  end if;

  v_event := nullif(trim(coalesce(v_recruiter.current_event_name,'')), '');

  select ec.id into v_employer_connection_id
  from public.employer_connections ec
  where ec.recruiter_user_id = auth.uid()
    and ec.student_user_id = p_student_user_id
    and coalesce(lower(ec.event_name), '') = coalesce(lower(v_event), '')
  limit 1;

  if v_employer_connection_id is null then
    insert into public.employer_connections (
      company_id, recruiter_user_id, student_user_id, event_name
    ) values (
      v_recruiter.company_id, auth.uid(), p_student_user_id, v_event
    )
    returning id into v_employer_connection_id;
  else
    update public.employer_connections
    set updated_at = now()
    where id = v_employer_connection_id;
  end if;

  -- Mirror to the student's existing private connection list only if this same
  -- recruiter/student/event pair has not already created one.
  if not exists (
    select 1 from public.connections c
    where c.profile_owner_id = p_student_user_id
      and lower(coalesce(c.email,'')) = lower(v_recruiter.recruiter_email)
      and lower(coalesce(c.company,'')) = lower(v_company.name)
      and lower(coalesce(c.where_met,'')) = lower(coalesce(v_event,''))
  ) then
    insert into public.connections (
      profile_owner_id,
      visitor_name,
      company,
      email,
      where_met,
      message,
      private_notes
    ) values (
      p_student_user_id,
      v_recruiter.recruiter_name,
      v_company.name,
      v_recruiter.recruiter_email,
      v_event,
      'Connected through the TapID employer portal.',
      null
    );
  end if;

  return v_employer_connection_id;
end;
$$;

grant execute on function public.connect_employer_to_student(uuid) to authenticated;

-- 5) RLS. Recruiters can see their employer identity and all candidates saved by
--    recruiters at the same company. Notes/status are company-private.
drop policy if exists "Recruiters can view own company" on public.companies;
create policy "Recruiters can view own company"
on public.companies for select to authenticated
using (
  exists (
    select 1 from public.employer_recruiters er
    where er.user_id = auth.uid() and er.company_id = companies.id
  )
);

drop policy if exists "Recruiters can view own recruiter record" on public.employer_recruiters;
create policy "Recruiters can view own recruiter record"
on public.employer_recruiters for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Recruiters can update own recruiter record" on public.employer_recruiters;
create policy "Recruiters can update own recruiter record"
on public.employer_recruiters for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Company recruiters can view employer connections" on public.employer_connections;
create policy "Company recruiters can view employer connections"
on public.employer_connections for select to authenticated
using (
  exists (
    select 1 from public.employer_recruiters er
    where er.user_id = auth.uid() and er.company_id = employer_connections.company_id
  )
);

drop policy if exists "Company recruiters can update employer connections" on public.employer_connections;
create policy "Company recruiters can update employer connections"
on public.employer_connections for update to authenticated
using (
  exists (
    select 1 from public.employer_recruiters er
    where er.user_id = auth.uid() and er.company_id = employer_connections.company_id
  )
)
with check (
  exists (
    select 1 from public.employer_recruiters er
    where er.user_id = auth.uid() and er.company_id = employer_connections.company_id
  )
);

-- No public SELECT policies are created for employer_connections. University
-- analytics can later be served through a dedicated aggregate/admin layer rather
-- than exposing individual recruiter/student interaction records.


-- Explicit privileges for browser-authenticated recruiter sessions.
grant select on public.companies to authenticated;
grant select, update on public.employer_recruiters to authenticated;
grant select, update on public.employer_connections to authenticated;
