begin;

-- TapID V10.1: pilot-ready relationship workflow and reporting layer.
-- The university's existing platform remains the source of record for event
-- registration, payments, booths, jobs, applications and scheduling.

alter table public.employer_connections
  add column if not exists relationship_owner text,
  add column if not exists next_action text;

create index if not exists employer_connections_company_stage_idx
  on public.employer_connections(company_id,candidate_status);
create index if not exists employer_connections_follow_up_idx
  on public.employer_connections(company_id,next_follow_up_at)
  where next_follow_up_at is not null;

-- One current employer-created milestone per relationship. The activity log
-- preserves history, while this row represents the current reported outcome.
delete from public.career_outcomes a
using public.career_outcomes b
where a.employer_connection_id=b.employer_connection_id
  and a.employer_connection_id is not null
  and (a.updated_at<b.updated_at or (a.updated_at=b.updated_at and a.id<b.id));

create unique index if not exists career_outcomes_current_employer_milestone_unique
  on public.career_outcomes(employer_connection_id)
  where employer_connection_id is not null;

create or replace function public.sync_verified_career_outcome()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_outcome_type text; v_company_name text;
begin
  if tg_op='UPDATE' and new.candidate_status is not distinct from old.candidate_status then return new; end if;
  v_outcome_type:=case new.candidate_status
    when 'interview' then 'interview' when 'internship' then 'internship'
    when 'offer' then 'offer' when 'accepted_offer' then 'accepted_offer'
    when 'job' then 'job' else null end;
  if v_outcome_type is null then
    delete from public.career_outcomes where employer_connection_id=new.id;
    return new;
  end if;
  select name into v_company_name from public.companies where id=new.company_id;
  insert into public.career_outcomes(student_user_id,career_fair_id,employer_connection_id,outcome_type,company_name,outcome_date,notes,is_public,verification_status,created_at,updated_at)
  values(new.student_user_id,new.career_fair_id,new.id,v_outcome_type,coalesce(v_company_name,'Employer'),current_date,
    case when new.event_name is not null then 'Employer reported after '||new.event_name else 'Employer reported' end,
    false,'verified',now(),now())
  on conflict (employer_connection_id) where employer_connection_id is not null
  do update set outcome_type=excluded.outcome_type,career_fair_id=excluded.career_fair_id,
    company_name=excluded.company_name,outcome_date=excluded.outcome_date,notes=excluded.notes,
    is_public=false,verification_status='verified',updated_at=now();
  return new;
end;$$;

drop trigger if exists sync_verified_career_outcome_trigger on public.employer_connections;
create trigger sync_verified_career_outcome_trigger
after insert or update of candidate_status on public.employer_connections
for each row execute function public.sync_verified_career_outcome();

-- A controlled CSV-import endpoint. It imports reference data only and can be
-- called solely by a verified administrator for their own school.
create or replace function public.import_integration_event_employer(
  p_external_event_id text,p_event_name text,p_starts_at timestamptz,p_location text,
  p_external_employer_id text,p_company_name text)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_school text; v_event_id bigint; v_company_id bigint;
begin
  select school_name into v_school from public.university_admins
  where user_id=auth.uid() and verification_status='verified';
  if v_school is null then raise exception 'Verified university access required'; end if;
  if nullif(trim(p_external_event_id),'') is null or nullif(trim(p_event_name),'') is null or nullif(trim(p_company_name),'') is null then
    raise exception 'Event ID, event name and company name are required';
  end if;
  insert into public.integration_events(school_name,source_system,external_event_id,event_name,starts_at,location,imported_by)
  values(v_school,'csv',trim(p_external_event_id),trim(p_event_name),p_starts_at,nullif(trim(p_location),''),auth.uid())
  on conflict(school_name,source_system,external_event_id)
  do update set event_name=excluded.event_name,starts_at=excluded.starts_at,location=excluded.location,imported_at=now()
  returning id into v_event_id;
  select id into v_company_id from public.companies where lower(trim(name))=lower(trim(p_company_name)) limit 1;
  insert into public.integration_event_employers(integration_event_id,external_employer_id,company_name,company_id)
  values(v_event_id,nullif(trim(p_external_employer_id),''),trim(p_company_name),v_company_id)
  on conflict(integration_event_id,company_name)
  do update set external_employer_id=excluded.external_employer_id,company_id=coalesce(excluded.company_id,integration_event_employers.company_id),imported_at=now();
  return v_event_id;
end;$$;
revoke all on function public.import_integration_event_employer(text,text,timestamptz,text,text,text) from public;
grant execute on function public.import_integration_event_employer(text,text,timestamptz,text,text,text) to authenticated;

-- Privacy-safe row set used by the filterable university report. Student names,
-- usernames, messages, contact details and recruiter notes are excluded.
create or replace function public.university_relationship_report()
returns table(
  student_key text,company_id bigint,company_name text,event_name text,
  major text,school_year text,candidate_status text,connected_at timestamptz,
  updated_at timestamptz,first_follow_up_at timestamptz,days_to_first_follow_up numeric)
language plpgsql security definer set search_path=public as $$
declare v_school text;
begin
  select school_name into v_school from public.university_admins
  where user_id=auth.uid() and verification_status='verified';
  if v_school is null then raise exception 'Verified university access required'; end if;
  return query
  select md5(ec.student_user_id::text||':'||lower(trim(v_school))||':tapid-report'),ec.company_id,c.name,coalesce(ec.event_name,'Direct connection'),
    coalesce(p.major,'Unspecified'),coalesce(p.school_year,'Unspecified'),ec.candidate_status,
    ec.connected_at,ec.updated_at,fa.first_at,
    case when fa.first_at is null then null else round(extract(epoch from (fa.first_at-ec.connected_at))/86400.0,1) end
  from public.employer_connections ec
  join public.profiles p on p.id=ec.student_user_id and lower(trim(p.school))=lower(trim(v_school))
  join public.companies c on c.id=ec.company_id
  left join lateral (
    select min(ca.created_at) first_at from public.candidate_activity ca
    where ca.student_user_id=ec.student_user_id and ca.company_id=ec.company_id
      and ca.activity_type in ('message','follow_up','contacted','screening','interview','internship','offer','accepted_offer','job')
  ) fa on true
  order by ec.connected_at desc;
end;$$;
revoke all on function public.university_relationship_report() from public;
grant execute on function public.university_relationship_report() to authenticated;

-- Company names are public recruiting information and are needed so students
-- see the organization name in messaging instead of a generic label.
drop policy if exists "Authenticated users can view company profiles" on public.companies;
create policy "Authenticated users can view company profiles"
on public.companies for select to authenticated using (true);

commit;
