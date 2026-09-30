-- TapID V3 verification, analytics, and role hardening
-- Apply after tapid_v2_production_migration.sql. Idempotent.

begin;

-- New university administrators must be explicitly verified. Existing rows keep
-- their current values from the V2 migration.
alter table public.university_admins
  alter column verification_status set default 'pending';

-- Every university aggregate/admin RPC uses this helper, so verification is
-- enforced centrally without exposing student-level relationship records.
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
    and ua.verification_status = 'verified'
  limit 1;
$$;

revoke all on function public.current_university_school() from public;
grant execute on function public.current_university_school() to authenticated;

-- Prevent an authenticated user from registering an unrelated address as the
-- recruiter's contact address. Company verification still occurs through the
-- university career-fair approval workflow.
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
  v_auth_email text;
  v_row public.employer_recruiters;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_auth_email := lower(trim(coalesce(auth.jwt()->>'email', '')));
  if v_auth_email = '' or v_auth_email <> lower(trim(coalesce(p_recruiter_email, ''))) then
    raise exception 'Recruiter email must match the signed-in account';
  end if;

  v_normalized := lower(regexp_replace(trim(p_company_name), '\s+', ' ', 'g'));
  if v_normalized = '' or trim(coalesce(p_recruiter_name, '')) = '' then
    raise exception 'Company and recruiter name are required';
  end if;

  insert into public.companies (name, normalized_name)
  values (trim(p_company_name), v_normalized)
  on conflict (normalized_name) do update set name = public.companies.name
  returning id into v_company_id;

  insert into public.employer_recruiters (
    user_id,
    company_id,
    recruiter_name,
    recruiter_email
  ) values (
    auth.uid(),
    v_company_id,
    trim(p_recruiter_name),
    v_auth_email
  )
  on conflict (user_id) do update set
    company_id = excluded.company_id,
    recruiter_name = excluded.recruiter_name,
    recruiter_email = excluded.recruiter_email,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.register_employer(text,text,text) from public;
grant execute on function public.register_employer(text,text,text) to authenticated;

-- Browser sessions may edit only ordinary recruiter preferences. Verification,
-- company ownership, and identity fields remain writable only through trusted
-- RPCs such as register_employer() and review_fair_registration().
revoke update on public.employer_recruiters from authenticated;
grant update (recruiter_name, current_event_name, updated_at)
on public.employer_recruiters to authenticated;

-- Candidate workspaces expose only status and private notes as editable fields.
-- This prevents a recruiter from reassigning a connection to another company,
-- recruiter, student, or event through the REST API.
revoke update on public.employer_connections from authenticated;
grant update (candidate_status, private_notes, updated_at)
on public.employer_connections to authenticated;

-- A direct in-person employer connection requires a verified recruiter and an
-- approved registration for the recruiter's selected official event.
create or replace function public.connect_employer_to_student(
  p_student_user_id uuid
)
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
  v_fair_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_recruiter
  from public.employer_recruiters
  where user_id = auth.uid()
    and verification_status = 'verified';

  if not found then
    raise exception 'Verified employer account required';
  end if;

  v_event := nullif(trim(coalesce(v_recruiter.current_event_name, '')), '');
  if v_event is null then
    raise exception 'Select an approved current career fair before connecting';
  end if;

  select cf.id into v_fair_id
  from public.career_fairs cf
  join public.career_fair_employers cfe
    on cfe.career_fair_id = cf.id
   and cfe.company_id = v_recruiter.company_id
   and cfe.status = 'approved'
  where cf.is_published
    and lower(trim(cf.name)) = lower(v_event)
  limit 1;

  if v_fair_id is null then
    raise exception 'Your company is not approved for the selected career fair';
  end if;

  select * into v_company
  from public.companies
  where id = v_recruiter.company_id;

  select * into v_student
  from public.profiles
  where id = p_student_user_id;

  if not found
     or v_student.profile_active is not true
     or v_student.card_activated is not true then
    raise exception 'Student profile is unavailable';
  end if;

  select ec.id into v_employer_connection_id
  from public.employer_connections ec
  where ec.recruiter_user_id = auth.uid()
    and ec.student_user_id = p_student_user_id
    and coalesce(lower(trim(ec.event_name)), '') = lower(v_event)
  limit 1;

  if v_employer_connection_id is null then
    insert into public.employer_connections (
      company_id,
      recruiter_user_id,
      student_user_id,
      event_name,
      career_fair_id
    ) values (
      v_recruiter.company_id,
      auth.uid(),
      p_student_user_id,
      v_event,
      v_fair_id
    )
    returning id into v_employer_connection_id;
  else
    update public.employer_connections
    set career_fair_id = coalesce(career_fair_id, v_fair_id),
        updated_at = now()
    where id = v_employer_connection_id;
  end if;

  if not exists (
    select 1
    from public.connections c
    where c.profile_owner_id = p_student_user_id
      and lower(coalesce(c.email, '')) = lower(v_recruiter.recruiter_email)
      and lower(coalesce(c.company, '')) = lower(v_company.name)
      and lower(coalesce(c.where_met, '')) = lower(v_event)
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

revoke all on function public.connect_employer_to_student(uuid) from public;
grant execute on function public.connect_employer_to_student(uuid) to authenticated;

-- Re-check verification and the official event approval inside the request
-- decision RPC. Declining and accepting are both reserved for verified company
-- recruiters, and acceptance carries the official career_fair_id forward.
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
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_recruiter
  from public.employer_recruiters
  where user_id = auth.uid()
    and verification_status = 'verified';

  if not found then
    raise exception 'Verified employer account required';
  end if;

  select * into v_request
  from public.employer_connection_requests
  where id = p_request_id
    and company_id = v_recruiter.company_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'This request has already been reviewed';
  end if;

  if v_request.career_fair_id is null or not exists (
    select 1
    from public.career_fairs cf
    join public.career_fair_employers cfe
      on cfe.career_fair_id = cf.id
     and cfe.company_id = v_recruiter.company_id
     and cfe.status = 'approved'
    where cf.id = v_request.career_fair_id
      and cf.is_published
  ) then
    raise exception 'The company is no longer approved for this career fair';
  end if;

  if p_accept is not true then
    update public.employer_connection_requests
    set status = 'declined',
        responded_by = auth.uid(),
        responded_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  select * into v_company
  from public.companies
  where id = v_recruiter.company_id;

  select * into v_student
  from public.profiles
  where id = v_request.student_user_id;

  if not found
     or v_student.profile_active is not true
     or v_student.card_activated is not true then
    raise exception 'Student profile is unavailable';
  end if;

  select ec.id into v_connection_id
  from public.employer_connections ec
  where ec.recruiter_user_id = auth.uid()
    and ec.student_user_id = v_request.student_user_id
    and coalesce(lower(trim(ec.event_name)), '') = lower(trim(v_request.event_name))
  limit 1;

  if v_connection_id is null then
    insert into public.employer_connections (
      company_id,
      recruiter_user_id,
      student_user_id,
      event_name,
      career_fair_id
    ) values (
      v_recruiter.company_id,
      auth.uid(),
      v_request.student_user_id,
      v_request.event_name,
      v_request.career_fair_id
    )
    returning id into v_connection_id;
  else
    update public.employer_connections
    set career_fair_id = coalesce(career_fair_id, v_request.career_fair_id),
        updated_at = now()
    where id = v_connection_id;
  end if;

  if not exists (
    select 1
    from public.connections c
    where c.profile_owner_id = v_request.student_user_id
      and lower(coalesce(c.email, '')) = lower(v_recruiter.recruiter_email)
      and lower(coalesce(c.company, '')) = lower(v_company.name)
      and lower(coalesce(c.where_met, '')) = lower(v_request.event_name)
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

-- Pending or rejected recruiters may register for a fair, but they cannot read
-- candidate workspaces or student requests until a university verifies them.
drop policy if exists "Company recruiters can view employer connections"
on public.employer_connections;

create policy "Company recruiters can view employer connections"
on public.employer_connections
for select to authenticated
using (
  exists (
    select 1
    from public.employer_recruiters er
    where er.user_id = auth.uid()
      and er.company_id = employer_connections.company_id
      and er.verification_status = 'verified'
  )
);

drop policy if exists "Company recruiters can update employer connections"
on public.employer_connections;

create policy "Company recruiters can update employer connections"
on public.employer_connections
for update to authenticated
using (
  exists (
    select 1
    from public.employer_recruiters er
    where er.user_id = auth.uid()
      and er.company_id = employer_connections.company_id
      and er.verification_status = 'verified'
  )
)
with check (
  exists (
    select 1
    from public.employer_recruiters er
    where er.user_id = auth.uid()
      and er.company_id = employer_connections.company_id
      and er.verification_status = 'verified'
  )
);

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
      and er.verification_status = 'verified'
  )
);

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
  where er.user_id = auth.uid()
    and er.verification_status = 'verified';

  if v_company_id is null then
    raise exception 'Verified employer account required';
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

-- Aggregate requests separately from actual connections so universities can
-- measure demand without treating pending/declined requests as relationships.
create or replace function public.university_request_engagement()
returns table (
  company_name text,
  direct_connections bigint,
  requests bigint,
  accepted_requests bigint,
  declined_requests bigint,
  pending_requests bigint
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
    raise exception 'Verified university administrator access required';
  end if;

  return query
  with company_requests as (
    select
      r.company_id,
      count(*)::bigint as requests,
      count(*) filter (where r.status = 'accepted')::bigint as accepted_requests,
      count(*) filter (where r.status = 'declined')::bigint as declined_requests,
      count(*) filter (where r.status = 'pending')::bigint as pending_requests
    from public.employer_connection_requests r
    join public.profiles p on p.id = r.student_user_id
    where lower(trim(coalesce(p.school, ''))) = lower(trim(v_school))
    group by r.company_id
  ), company_connections as (
    select ec.company_id, count(*)::bigint as direct_connections
    from public.employer_connections ec
    join public.profiles p on p.id = ec.student_user_id
    where lower(trim(coalesce(p.school, ''))) = lower(trim(v_school))
      and not exists (
        select 1
        from public.employer_connection_requests r
        where r.student_user_id = ec.student_user_id
          and r.company_id = ec.company_id
          and r.status = 'accepted'
          and lower(trim(r.event_name)) = lower(trim(coalesce(ec.event_name, '')))
      )
    group by ec.company_id
  )
  select
    c.name,
    coalesce(cc.direct_connections, 0),
    coalesce(cr.requests, 0),
    coalesce(cr.accepted_requests, 0),
    coalesce(cr.declined_requests, 0),
    coalesce(cr.pending_requests, 0)
  from public.companies c
  left join company_requests cr on cr.company_id = c.id
  left join company_connections cc on cc.company_id = c.id
  where cr.company_id is not null or cc.company_id is not null
  order by (coalesce(cc.direct_connections, 0) + coalesce(cr.requests, 0)) desc,
           lower(c.name);
end;
$$;

revoke all on function public.university_request_engagement() from public;
grant execute on function public.university_request_engagement() to authenticated;

commit;
