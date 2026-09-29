-- ============================================
-- TAPID SPRINT 6.13
-- Career fair employer directory + connection requests
-- ============================================

create table if not exists public.employer_connection_requests (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete cascade,
  event_name text not null,
  message text not null,
  status text not null default 'pending'
    check (status in ('pending','accepted','declined')),
  responded_by uuid references public.employer_recruiters(user_id) on delete set null,
  requested_at timestamptz not null default now(),
  responded_at timestamptz
);

create unique index if not exists employer_request_one_per_student_company_event
on public.employer_connection_requests (
  student_user_id,
  company_id,
  lower(trim(event_name))
);

alter table public.employer_connection_requests enable row level security;

-- Students can see only their own request records.
drop policy if exists "Students can view own employer requests"
on public.employer_connection_requests;
create policy "Students can view own employer requests"
on public.employer_connection_requests
for select to authenticated
using (student_user_id = auth.uid());

-- Company recruiters can see requests sent to their company.
drop policy if exists "Company recruiters can view employer requests"
on public.employer_connection_requests;
create policy "Company recruiters can view employer requests"
on public.employer_connection_requests
for select to authenticated
using (
  exists (
    select 1
    from public.employer_recruiters er
    where er.user_id = auth.uid()
      and er.company_id = employer_connection_requests.company_id
  )
);

-- Directory: only event name + company identity + the current student's request status.
-- No recruiter names, emails, phone numbers, or other private data are returned.
create or replace function public.student_event_employer_directory()
returns table (
  event_name text,
  company_id bigint,
  company_name text,
  request_status text,
  request_id bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p where p.id = auth.uid()
  ) then
    raise exception 'Student account required';
  end if;

  return query
  with registered as (
    select distinct
      trim(er.current_event_name) as event_name,
      er.company_id
    from public.employer_recruiters er
    where nullif(trim(coalesce(er.current_event_name,'')), '') is not null
  )
  select
    r.event_name,
    c.id,
    c.name,
    req.status,
    req.id
  from registered r
  join public.companies c on c.id = r.company_id
  left join public.employer_connection_requests req
    on req.student_user_id = auth.uid()
   and req.company_id = c.id
   and lower(trim(req.event_name)) = lower(trim(r.event_name))
  order by lower(r.event_name), lower(c.name);
end;
$$;

revoke all on function public.student_event_employer_directory() from public;
grant execute on function public.student_event_employer_directory() to authenticated;

create or replace function public.request_employer_connection(
  p_company_id bigint,
  p_event_name text,
  p_message text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_event text := nullif(trim(coalesce(p_event_name,'')), '');
  v_message text := nullif(trim(coalesce(p_message,'')), '');
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.profile_active = true
      and p.card_activated = true
  ) then
    raise exception 'An active student TapID is required';
  end if;

  if v_event is null then raise exception 'Event is required'; end if;
  if v_message is null then raise exception 'Please include a short message'; end if;
  if char_length(v_message) > 500 then raise exception 'Message must be 500 characters or fewer'; end if;

  if not exists (
    select 1
    from public.employer_recruiters er
    where er.company_id = p_company_id
      and lower(trim(coalesce(er.current_event_name,''))) = lower(v_event)
  ) then
    raise exception 'This employer is not currently registered for that event';
  end if;

  if exists (
    select 1
    from public.employer_connection_requests r
    where r.student_user_id = auth.uid()
      and r.company_id = p_company_id
      and lower(trim(r.event_name)) = lower(v_event)
  ) then
    raise exception 'You already sent this employer a request for this event';
  end if;

  insert into public.employer_connection_requests (
    student_user_id, company_id, event_name, message
  ) values (
    auth.uid(), p_company_id, v_event, v_message
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.request_employer_connection(bigint,text,text) from public;
grant execute on function public.request_employer_connection(bigint,text,text) to authenticated;

-- Employer request inbox. Only public student identity is exposed before acceptance.
create or replace function public.employer_request_inbox()
returns table (
  request_id bigint,
  student_user_id uuid,
  event_name text,
  message text,
  requested_at timestamptz,
  first_name text,
  last_name text,
  username text,
  school text,
  major text,
  school_year text,
  graduation_year integer,
  bio text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company_id bigint;
begin
  select er.company_id into v_company_id
  from public.employer_recruiters er
  where er.user_id = auth.uid();

  if v_company_id is null then
    raise exception 'Employer account required';
  end if;

  return query
  select
    r.id,
    r.student_user_id,
    r.event_name,
    r.message,
    r.requested_at,
    p.first_name,
    p.last_name,
    p.username,
    p.school,
    p.major,
    p.school_year,
    p.graduation_year,
    p.bio
  from public.employer_connection_requests r
  join public.profiles p on p.id = r.student_user_id
  where r.company_id = v_company_id
    and r.status = 'pending'
    and p.profile_active = true
    and p.card_activated = true
  order by r.requested_at desc;
end;
$$;

revoke all on function public.employer_request_inbox() from public;
grant execute on function public.employer_request_inbox() to authenticated;

create or replace function public.respond_employer_connection_request(
  p_request_id bigint,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.employer_connection_requests;
  v_recruiter public.employer_recruiters;
  v_company public.companies;
  v_student public.profiles;
  v_connection_id bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_recruiter
  from public.employer_recruiters
  where user_id = auth.uid();

  if not found then raise exception 'Employer account required'; end if;

  select * into v_request
  from public.employer_connection_requests
  where id = p_request_id
    and company_id = v_recruiter.company_id
  for update;

  if not found then raise exception 'Request not found'; end if;
  if v_request.status <> 'pending' then raise exception 'This request has already been reviewed'; end if;

  if p_accept is not true then
    update public.employer_connection_requests
    set status = 'declined',
        responded_by = auth.uid(),
        responded_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  select * into v_company from public.companies where id = v_recruiter.company_id;
  select * into v_student from public.profiles where id = v_request.student_user_id;

  if not found or v_student.profile_active is not true or v_student.card_activated is not true then
    raise exception 'Student profile is unavailable';
  end if;

  -- A company request becomes a recruiter/student connection when a recruiter accepts.
  select ec.id into v_connection_id
  from public.employer_connections ec
  where ec.recruiter_user_id = auth.uid()
    and ec.student_user_id = v_request.student_user_id
    and coalesce(lower(ec.event_name), '') = lower(v_request.event_name)
  limit 1;

  if v_connection_id is null then
    insert into public.employer_connections (
      company_id, recruiter_user_id, student_user_id, event_name
    ) values (
      v_recruiter.company_id, auth.uid(), v_request.student_user_id, v_request.event_name
    )
    returning id into v_connection_id;
  end if;

  -- Only after acceptance does the student receive recruiter contact information.
  if not exists (
    select 1
    from public.connections c
    where c.profile_owner_id = v_request.student_user_id
      and lower(coalesce(c.email,'')) = lower(v_recruiter.recruiter_email)
      and lower(coalesce(c.company,'')) = lower(v_company.name)
      and lower(coalesce(c.where_met,'')) = lower(v_request.event_name)
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
      v_request.student_user_id,
      v_recruiter.recruiter_name,
      v_company.name,
      v_recruiter.recruiter_email,
      v_request.event_name,
      'Accepted your TapID connection request.',
      null
    );
  end if;

  update public.employer_connection_requests
  set status = 'accepted',
      responded_by = auth.uid(),
      responded_at = now()
  where id = p_request_id;

  return 'accepted';
end;
$$;

revoke all on function public.respond_employer_connection_request(bigint,boolean) from public;
grant execute on function public.respond_employer_connection_request(bigint,boolean) to authenticated;
