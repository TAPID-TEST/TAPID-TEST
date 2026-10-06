-- TapID university workspace upgrade, 2026-10-06.
-- Run the entire file in the Supabase SQL Editor before publishing the website.
-- Existing accounts, usernames, and card serials are preserved. No deletions.
begin;

-- Run once in Supabase SQL Editor. Safe to rerun; existing cards are preserved.
-- Keep Authentication > Email > Confirm email enabled.

alter table public.card_issuance alter column issued_by drop not null;
alter table public.card_issuance add column if not exists issuance_source text not null default 'university';
create sequence if not exists public.tapid_calpoly_serial_seq;
revoke all on sequence public.tapid_calpoly_serial_seq from public, anon, authenticated;

create or replace function public.ensure_calpoly_card_for_user(p_user uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_profile public.profiles%rowtype;
  v_serial text;
  v_number text;
begin
  -- Never trust the profile's contact email or client-controlled user metadata.
  if not exists (
    select 1 from auth.users u where u.id=p_user
      and u.email_confirmed_at is not null
      and lower(split_part(u.email,'@',2))='calpoly.edu'
      and array_length(string_to_array(u.email,'@'),1)=2
  ) then return null; end if;
  if exists(select 1 from public.university_admins where user_id=p_user)
     or exists(select 1 from public.employer_recruiters where user_id=p_user)
  then return null; end if;

  -- Serialize simultaneous requests from two student tabs.
  select * into v_profile from public.profiles where id=p_user for update;
  if found and nullif(trim(v_profile.school),'') is null then
    update public.profiles set school='Cal Poly',updated_at=now() where id=p_user;
    v_profile.school := 'Cal Poly';
  end if;
  if not found or nullif(trim(v_profile.username),'') is null
     or coalesce(lower(trim(v_profile.school)),'') not in
       ('cal poly','cal poly san luis obispo','cal poly, san luis obispo',
        'california polytechnic state university','california polytechnic state university, san luis obispo')
  then return null; end if;

  select card_serial into v_serial from public.card_issuance
    where student_user_id=p_user and status in ('issued','activated')
    order by issued_at desc,id desc limit 1;
  if found then return v_serial; end if;
  -- Do not automatically replace a revoked, lost, or replaced card.
  if exists(select 1 from public.card_issuance where student_user_id=p_user)
  then return null; end if;

  loop
    v_number := nextval('public.tapid_calpoly_serial_seq'::regclass)::text;
    v_serial := 'CP-' || lpad(v_number,greatest(8,length(v_number)),'0');
    insert into public.card_issuance(student_user_id,school_name,issued_by,card_serial,issuance_source,notes)
    values(p_user,v_profile.school,null,v_serial,'calpoly_email',
      'Automatically assigned after confirmation of a calpoly.edu email.')
    on conflict(card_serial) do nothing;
    exit when found;
  end loop;
  return v_serial;
end;
$$;
revoke all on function public.ensure_calpoly_card_for_user(uuid) from public,anon,authenticated;

create or replace function public.ensure_my_calpoly_card()
returns text language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in to continue'; end if;
  return public.ensure_calpoly_card_for_user(auth.uid());
end;
$$;
revoke all on function public.ensure_my_calpoly_card() from public,anon;
grant execute on function public.ensure_my_calpoly_card() to authenticated;

-- Email confirmation verifies affiliation; it does not prove current enrollment.
create or replace function public.public_profile_verification(p_username text)
returns table(school_name text,verification_label text)
language sql stable security definer set search_path = '' as $$
  select ci.school_name,
    case when ci.issuance_source='calpoly_email' then 'Cal Poly email verified'
      when p.school_year='Alumni' then 'Verified Alumni' else 'Verified Student' end
  from public.profiles p join public.card_issuance ci on ci.student_user_id=p.id
  join auth.users u on u.id=p.id
  where lower(p.username)=lower(trim(p_username))
    and p.profile_active and p.card_activated and ci.status='activated'
    and (ci.issuance_source<>'calpoly_email' or
      (u.email_confirmed_at is not null and lower(split_part(u.email,'@',2))='calpoly.edu'))
  order by ci.activated_at desc nulls last,ci.issued_at desc limit 1;
$$;
revoke all on function public.public_profile_verification(text) from public;
grant execute on function public.public_profile_verification(text) to anon,authenticated;

-- Also assign cards to existing eligible student accounts, including your demo.
do $$
declare v_user uuid;
begin
  for v_user in select p.id from public.profiles p join auth.users u on u.id=p.id
    where u.email_confirmed_at is not null and lower(split_part(u.email,'@',2))='calpoly.edu'
  loop perform public.ensure_calpoly_card_for_user(v_user); end loop;
end;
$$;


-- TapID fair reports and employer approval workspace.
-- Student-card dependencies are installed above in this same transaction.

create or replace function public.tapid_school_key(p_school text)
returns text language sql immutable set search_path='' as $$
  select case when lower(trim(coalesce(p_school,''))) in
    ('cal poly','cal poly san luis obispo','cal poly, san luis obispo',
     'california polytechnic state university','california polytechnic state university, san luis obispo')
    then 'cal poly' else lower(trim(coalesce(p_school,''))) end;
$$;
revoke all on function public.tapid_school_key(text) from public,anon,authenticated;

alter table public.employer_recruiters
  add column if not exists requested_school text not null default 'Cal Poly',
  add column if not exists review_reason text,
  add column if not exists reviewed_at timestamptz;

create table if not exists public.employer_approval_history(
  id bigint generated always as identity primary key,
  recruiter_user_id uuid not null references public.employer_recruiters(user_id) on delete cascade,
  school_name text not null,
  reviewer_user_id uuid references auth.users(id) on delete set null,
  status text not null check(status in ('verified','rejected')),
  reason text,
  created_at timestamptz not null default now()
);
alter table public.employer_approval_history enable row level security;
revoke all on public.employer_approval_history from anon,authenticated;
create index if not exists employer_approval_recruiter_time_idx on public.employer_approval_history(recruiter_user_id,created_at desc);
create index if not exists candidate_activity_relation_time_idx on public.candidate_activity(student_user_id,company_id,created_at);

-- Verification cannot be self-assigned through ordinary REST updates.
revoke insert,update on public.employer_recruiters from authenticated;
grant update(recruiter_name,title,phone,current_event_name,updated_at) on public.employer_recruiters to authenticated;

create or replace function public.tapid_available_universities()
returns table(school_name text) language sql stable security definer set search_path='' as $$
  select min(ua.school_name) from public.university_admins ua
  where ua.verification_status='verified'
  group by public.tapid_school_key(ua.school_name) order by min(ua.school_name);
$$;
revoke all on function public.tapid_available_universities() from public;
grant execute on function public.tapid_available_universities() to anon,authenticated;

create or replace function public.register_employer(p_company_name text,p_recruiter_name text,p_recruiter_email text)
returns public.employer_recruiters language plpgsql security definer set search_path='' as $$
declare v_company bigint;v_auth auth.users%rowtype;v_row public.employer_recruiters%rowtype;v_school text;
begin
  select * into v_auth from auth.users where id=auth.uid();
  if not found or v_auth.email_confirmed_at is null then raise exception 'Confirm your work email before continuing'; end if;
  if lower(trim(p_recruiter_email))<>lower(v_auth.email) then raise exception 'Recruiter email must match the signed-in account'; end if;
  if exists(select 1 from public.profiles where id=auth.uid()) or exists(select 1 from public.university_admins where user_id=auth.uid())
  then raise exception 'Use a separate employer account'; end if;
  -- An already registered identity is immutable here. Do not transfer an approved
  -- recruiter to a newly typed company or change their approval jurisdiction.
  select * into v_row from public.employer_recruiters where user_id=auth.uid();
  if found then return v_row; end if;
  if nullif(trim(p_company_name),'') is null or nullif(trim(p_recruiter_name),'') is null then raise exception 'Company and recruiter name are required'; end if;
  select min(ua.school_name) into v_school from public.university_admins ua
  where ua.verification_status='verified' and public.tapid_school_key(ua.school_name)=
    public.tapid_school_key(coalesce(nullif(v_auth.raw_user_meta_data->>'employer_school',''),'Cal Poly'));
  if v_school is null then raise exception 'This university is not available for employer review yet'; end if;
  insert into public.companies(name,normalized_name,website)
  values(trim(p_company_name),lower(regexp_replace(trim(p_company_name),'\s+',' ','g')),
    case when v_auth.raw_user_meta_data->>'company_website' ~ '^https?://' then v_auth.raw_user_meta_data->>'company_website' else null end)
  on conflict(normalized_name) do nothing returning id into v_company;
  if v_company is null then select id into v_company from public.companies where normalized_name=lower(regexp_replace(trim(p_company_name),'\s+',' ','g')); end if;
  insert into public.employer_recruiters(user_id,company_id,recruiter_name,recruiter_email,verification_status,requested_school)
  values(auth.uid(),v_company,trim(p_recruiter_name),lower(v_auth.email),'pending',v_school)
  on conflict(user_id) do nothing;
  select * into v_row from public.employer_recruiters where user_id=auth.uid();
  return v_row;
end;$$;
revoke all on function public.register_employer(text,text,text) from public;
grant execute on function public.register_employer(text,text,text) to authenticated;

create or replace function public.university_employer_approvals()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_result jsonb;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',er.user_id,'company_name',c.name,'recruiter_name',er.recruiter_name,
    'title',er.title,'email',u.email,'email_confirmed',u.email_confirmed_at is not null,
    'website',c.website,'description',c.description,'status',er.verification_status,
    'requested_at',er.created_at,'reviewed_at',er.reviewed_at,'reason',er.review_reason,
    'history',(select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'reason',h.reason,'at',h.created_at) order by h.created_at desc),'[]'::jsonb)
      from public.employer_approval_history h where h.recruiter_user_id=er.user_id
      and public.tapid_school_key(h.school_name)=public.tapid_school_key(v_school))
  ) order by er.created_at),'[]'::jsonb) into v_result
  from public.employer_recruiters er join public.companies c on c.id=er.company_id
  join auth.users u on u.id=er.user_id
  where public.tapid_school_key(er.requested_school)=public.tapid_school_key(v_school);
  return v_result;
end;$$;
revoke all on function public.university_employer_approvals() from public;
grant execute on function public.university_employer_approvals() to authenticated;

create or replace function public.review_employer_account(p_user_id uuid,p_status text,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_school text;v_row public.employer_recruiters%rowtype;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  if p_status not in ('verified','rejected') then raise exception 'Invalid approval status'; end if;
  if p_status='rejected' and nullif(trim(p_reason),'') is null then raise exception 'A decline reason is required'; end if;
  if length(coalesce(p_reason,''))>500 then raise exception 'Keep the message to 500 characters'; end if;
  select * into v_row from public.employer_recruiters where user_id=p_user_id for update;
  if not found or public.tapid_school_key(v_row.requested_school)<>public.tapid_school_key(v_school) then raise exception 'Employer not found at your university'; end if;
  if p_status='verified' and not exists(select 1 from auth.users where id=p_user_id and email_confirmed_at is not null)
  then raise exception 'The employer must confirm their email first'; end if;
  if v_row.verification_status=p_status then return; end if;
  update public.employer_recruiters set verification_status=p_status,review_reason=nullif(trim(p_reason),''),
    reviewed_at=now(),verified_at=case when p_status='verified' then now() else null end,
    verified_by=case when p_status='verified' then auth.uid() else null end,updated_at=now()
  where user_id=p_user_id;
  insert into public.employer_approval_history(recruiter_user_id,school_name,reviewer_user_id,status,reason)
  values(p_user_id,v_school,auth.uid(),p_status,nullif(trim(p_reason),''));
end;$$;
revoke all on function public.review_employer_account(uuid,text,text) from public;
grant execute on function public.review_employer_account(uuid,text,text) to authenticated;

-- Additional restrictive policies keep an approved recruiter within the school
-- that reviewed their account, without broadening existing access policies.
create or replace function public.tapid_recruiter_access(p_company bigint,p_student uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.employer_recruiters er join public.profiles p on p.id=p_student
    where er.user_id=auth.uid() and er.company_id=p_company and er.verification_status='verified'
      and public.tapid_school_key(er.requested_school)=public.tapid_school_key(p.school));
$$;
revoke all on function public.tapid_recruiter_access(bigint,uuid) from public;
grant execute on function public.tapid_recruiter_access(bigint,uuid) to authenticated;
drop policy if exists "University-approved recruiter scope" on public.employer_connections;
create policy "University-approved recruiter scope" on public.employer_connections as restrictive for all to authenticated
using(student_user_id=auth.uid() or public.tapid_recruiter_access(company_id,student_user_id))
with check(public.tapid_recruiter_access(company_id,student_user_id));
drop policy if exists "University-approved message scope" on public.connection_messages;
create policy "University-approved message scope" on public.connection_messages as restrictive for all to authenticated
using(student_user_id=auth.uid() or public.tapid_recruiter_access(company_id,student_user_id))
with check(student_user_id=auth.uid() or public.tapid_recruiter_access(company_id,student_user_id));
drop policy if exists "University-approved activity scope" on public.candidate_activity;
create policy "University-approved activity scope" on public.candidate_activity as restrictive for select to authenticated
using(public.tapid_recruiter_access(company_id,student_user_id));

-- Protect mutations performed by existing SECURITY DEFINER connection RPCs too.
create or replace function public.tapid_guard_recruiter_scope()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is not null and exists(select 1 from public.employer_recruiters where user_id=auth.uid())
    and not public.tapid_recruiter_access(new.company_id,new.student_user_id)
  then raise exception 'University-approved employer access required for this student'; end if;
  return new;
end;$$;
revoke all on function public.tapid_guard_recruiter_scope() from public;
drop trigger if exists tapid_recruiter_scope on public.employer_connections;
create trigger tapid_recruiter_scope before insert or update on public.employer_connections for each row execute function public.tapid_guard_recruiter_scope();
drop trigger if exists tapid_message_scope on public.connection_messages;
create trigger tapid_message_scope before insert or update on public.connection_messages for each row execute function public.tapid_guard_recruiter_scope();

create or replace function public.employer_request_inbox()
returns table(request_id bigint,student_user_id uuid,event_name text,message text,requested_at timestamptz,
 first_name text,last_name text,username text,school text,major text,school_year text,graduation_year integer,bio text)
language plpgsql stable security definer set search_path='' as $$
begin
  if not exists(select 1 from public.employer_recruiters where user_id=auth.uid() and verification_status='verified') then raise exception 'Verified employer account required'; end if;
  return query select r.id,r.student_user_id,r.event_name,r.message,r.requested_at,p.first_name,p.last_name,p.username,p.school,p.major,p.school_year,p.graduation_year,p.bio
  from public.employer_connection_requests r join public.profiles p on p.id=r.student_user_id
  where r.status='pending' and p.profile_active and p.card_activated
    and public.tapid_recruiter_access(r.company_id,r.student_user_id)
  order by r.requested_at desc;
end;$$;
revoke all on function public.employer_request_inbox() from public;
grant execute on function public.employer_request_inbox() to authenticated;

-- Use the connection's event identifier when recording future stage changes.
-- Older name-only records remain explicitly unresolved when titles repeat.
create or replace function public.capture_candidate_status_activity()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and new.candidate_status is not distinct from old.candidate_status then return new; end if;
  insert into public.candidate_activity(student_user_id,company_id,recruiter_user_id,career_fair_id,event_name,activity_type,activity_label)
  values(new.student_user_id,new.company_id,new.recruiter_user_id,new.career_fair_id,new.event_name,new.candidate_status,
    case new.candidate_status when 'connected' then 'Connected with employer' when 'follow_up' then 'Follow-up planned'
      when 'contacted' then 'Employer made contact' when 'screening' then 'Under consideration' when 'interview' then 'Interview recorded'
      when 'offer' then 'Offer extended' when 'accepted_offer' then 'Offer accepted' when 'internship' then 'Internship confirmed'
      when 'job' then 'Hired' else 'Relationship closed' end);
  return new;
end;$$;
revoke all on function public.capture_candidate_status_activity() from public;

create or replace function public.university_fair_report()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_rows jsonb;v_events jsonb;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  with latest as (
    select distinct on(ec.student_user_id,ec.company_id,coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection')))))
      ec.*,min(ec.connected_at) over(partition by ec.student_user_id,ec.company_id,coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection'))))) as first_connected
    from public.employer_connections ec join public.profiles p on p.id=ec.student_user_id
    where public.tapid_school_key(p.school)=public.tapid_school_key(v_school)
    order by ec.student_user_id,ec.company_id,coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection')))),ec.updated_at desc nulls last,ec.id desc
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'student_key',md5(ec.student_user_id::text||':'||public.tapid_school_key(v_school)||':tapid-report'),
    'company_id',ec.company_id,'company_name',c.name,'event_name',coalesce(ec.event_name,'Direct connection'),
    'event_key',case when ec.career_fair_id is not null then 'fair:'||ec.career_fair_id::text
      when refs.matches=1 then 'event:'||refs.event_id::text else 'source:'||lower(trim(coalesce(ec.event_name,'Direct connection'))) end,
    'major',coalesce(p.major,'Unspecified'),'school_year',coalesce(p.school_year,'Unspecified'),
    'candidate_status',ec.candidate_status,'connected_at',ec.first_connected,'updated_at',ec.updated_at,
    'first_follow_up_at',activity.first_contact,'milestones',coalesce(activity.milestones,'[]'::jsonb)
  )),'[]'::jsonb) into v_rows
  from latest ec join public.profiles p on p.id=ec.student_user_id join public.companies c on c.id=ec.company_id
  left join lateral(select count(*) as matches,min(ie.id) as event_id from public.integration_events ie
    where public.tapid_school_key(ie.school_name)=public.tapid_school_key(v_school)
      and lower(trim(ie.event_name))=lower(trim(ec.event_name))) refs on true
  left join lateral(
    select min(ca.created_at) filter(where ca.activity_type in ('contacted','screening','interview','offer','accepted_offer','internship','job')
      or (ca.activity_type='message' and ca.metadata->>'sender_role'='employer')) as first_contact,
      jsonb_agg(jsonb_build_object('stage',ca.activity_type,'at',ca.created_at) order by ca.created_at)
        filter(where ca.activity_type not in ('message','follow_up')) as milestones
    from public.candidate_activity ca where ca.student_user_id=ec.student_user_id and ca.company_id=ec.company_id
      and ca.created_at>=ec.first_connected
      and ((ca.activity_type='message' and ca.event_name is null and not exists(
          select 1 from public.employer_connections newer where newer.student_user_id=ec.student_user_id
            and newer.company_id=ec.company_id and newer.connected_at>ec.first_connected
            and newer.connected_at<=ca.created_at
            and coalesce('fair:'||newer.career_fair_id::text,lower(trim(coalesce(newer.event_name,'Direct connection'))))<>
              coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection')))))) or
        (ca.career_fair_id is not null and ec.career_fair_id=ca.career_fair_id) or
        (ca.career_fair_id is null and lower(trim(coalesce(ca.event_name,'Direct connection')))=lower(trim(coalesce(ec.event_name,'Direct connection')))))
  ) activity on true;

  with catalog as (
    select 'fair:'||cf.id::text as key,cf.name as name,cf.starts_at as date,false as ambiguous
    from public.career_fairs cf where public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school)
      and (cf.is_published or exists(select 1 from jsonb_array_elements(v_rows) r where r->>'event_key'='fair:'||cf.id::text))
    union all
    select 'event:'||ie.id::text as key,ie.event_name as name,ie.starts_at as date,
      (select count(*)>1 from public.integration_events other where public.tapid_school_key(other.school_name)=public.tapid_school_key(v_school)
        and lower(trim(other.event_name))=lower(trim(ie.event_name))) as ambiguous
    from public.integration_events ie where public.tapid_school_key(ie.school_name)=public.tapid_school_key(v_school)
      and (exists(select 1 from jsonb_array_elements(v_rows) r where r->>'event_key'='event:'||ie.id::text)
        or not exists(select 1 from public.career_fairs cf where public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school)
          and lower(trim(cf.name))=lower(trim(ie.event_name)) and cf.starts_at is not distinct from ie.starts_at))
    union all
    select distinct r->>'event_key',r->>'event_name',null::timestamptz,
      exists(select 1 from public.integration_events ie where public.tapid_school_key(ie.school_name)=public.tapid_school_key(v_school)
        and lower(trim(ie.event_name))=lower(trim(r->>'event_name')))
    from jsonb_array_elements(v_rows) r where r->>'event_key' like 'source:%'
  )
  select coalesce(jsonb_agg(jsonb_build_object('key',key,'name',name,'date',date,'ambiguous',ambiguous)
    order by date desc nulls last,name),'[]'::jsonb) into v_events from catalog;
  return jsonb_build_object('rows',v_rows,'events',v_events,'generated_at',now());
end;$$;
revoke all on function public.university_fair_report() from public;
grant execute on function public.university_fair_report() to authenticated;

notify pgrst,'reload schema';

commit;

