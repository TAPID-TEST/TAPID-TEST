begin;

-- V10 focuses TapID on the relationship created after a student and employer
-- meet. Existing university systems remain the source of record for event
-- registration, payments, booths, jobs, applications and scheduling.

alter table public.employer_connections
  add column if not exists relationship_owner text,
  add column if not exists next_action text;

alter table public.employer_connections drop constraint if exists employer_connections_candidate_status_check;
alter table public.employer_connections add constraint employer_connections_candidate_status_check
check (candidate_status in ('connected','follow_up','contacted','screening','interview','internship','offer','accepted_offer','job','passed'));

revoke update on public.employer_connections from authenticated;
grant update (candidate_status,priority,next_follow_up_at,relationship_owner,next_action,private_notes,updated_at)
on public.employer_connections to authenticated;

alter table public.candidate_activity drop constraint if exists candidate_activity_activity_type_check;
alter table public.candidate_activity add constraint candidate_activity_activity_type_check
check (activity_type in ('connected','message','follow_up','contacted','screening','interview','internship','offer','accepted_offer','job','passed'));

create or replace function public.capture_candidate_status_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_fair bigint;
begin
  if tg_op='UPDATE' and new.candidate_status is not distinct from old.candidate_status then return new; end if;
  select cf.id into v_fair from public.career_fairs cf where lower(cf.name)=lower(new.event_name) limit 1;
  insert into public.candidate_activity(student_user_id,company_id,recruiter_user_id,career_fair_id,event_name,activity_type,activity_label)
  values(new.student_user_id,new.company_id,new.recruiter_user_id,v_fair,new.event_name,new.candidate_status,
    case new.candidate_status
      when 'connected' then 'Connected with employer'
      when 'follow_up' then 'Follow-up planned'
      when 'contacted' then 'Employer made contact'
      when 'screening' then 'Moved to screening'
      when 'interview' then 'Advanced to interview'
      when 'internship' then 'Internship recorded'
      when 'offer' then 'Offer recorded'
      when 'accepted_offer' then 'Offer accepted'
      when 'job' then 'Hired'
      when 'passed' then 'Relationship closed'
      else 'Relationship stage updated' end);
  return new;
end;$$;

-- Minimal event-reference tables for CSV/API integration. They intentionally
-- exclude payment, booth, application, private-message and recruiter-note data.
create table if not exists public.integration_events (
  id bigint generated always as identity primary key,
  school_name text not null,
  source_system text not null default 'csv',
  external_event_id text not null,
  event_name text not null,
  starts_at timestamptz,
  location text,
  imported_by uuid references auth.users(id) on delete set null,
  imported_at timestamptz not null default now(),
  unique(school_name,source_system,external_event_id)
);

create table if not exists public.integration_event_employers (
  id bigint generated always as identity primary key,
  integration_event_id bigint not null references public.integration_events(id) on delete cascade,
  external_employer_id text,
  company_name text not null,
  company_id bigint references public.companies(id) on delete set null,
  imported_at timestamptz not null default now(),
  unique(integration_event_id,company_name)
);

alter table public.integration_events enable row level security;
alter table public.integration_event_employers enable row level security;

drop policy if exists "University admins manage integration events" on public.integration_events;
create policy "University admins manage integration events" on public.integration_events for all to authenticated
using (exists(select 1 from public.university_admins ua where ua.user_id=auth.uid() and ua.verification_status='verified' and lower(trim(ua.school_name))=lower(trim(integration_events.school_name))))
with check (exists(select 1 from public.university_admins ua where ua.user_id=auth.uid() and ua.verification_status='verified' and lower(trim(ua.school_name))=lower(trim(integration_events.school_name))));

drop policy if exists "University admins manage integrated employers" on public.integration_event_employers;
create policy "University admins manage integrated employers" on public.integration_event_employers for all to authenticated
using (exists(select 1 from public.integration_events ie join public.university_admins ua on lower(trim(ua.school_name))=lower(trim(ie.school_name)) where ie.id=integration_event_employers.integration_event_id and ua.user_id=auth.uid() and ua.verification_status='verified'))
with check (exists(select 1 from public.integration_events ie join public.university_admins ua on lower(trim(ua.school_name))=lower(trim(ie.school_name)) where ie.id=integration_event_employers.integration_event_id and ua.user_id=auth.uid() and ua.verification_status='verified'));

grant select,insert,update,delete on public.integration_events to authenticated;
grant select,insert,update,delete on public.integration_event_employers to authenticated;
grant usage,select on sequence public.integration_events_id_seq to authenticated;
grant usage,select on sequence public.integration_event_employers_id_seq to authenticated;

commit;
