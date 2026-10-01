begin;

-- Employer identity fields used by the redesigned workspace.
alter table public.companies add column if not exists description text;
alter table public.companies add column if not exists website text;
alter table public.companies add column if not exists industries text[] not null default '{}';
alter table public.companies add column if not exists locations text[] not null default '{}';
alter table public.companies add column if not exists recruiting_majors text[] not null default '{}';
alter table public.companies add column if not exists opportunities text[] not null default '{}';
alter table public.companies add column if not exists updated_at timestamptz not null default now();
alter table public.employer_recruiters add column if not exists title text;
alter table public.employer_recruiters add column if not exists phone text;

drop policy if exists "Verified recruiters can update company profile" on public.companies;
create policy "Verified recruiters can update company profile"
on public.companies for update to authenticated
using (exists (select 1 from public.employer_recruiters er where er.user_id=auth.uid() and er.company_id=companies.id and er.verification_status='verified'))
with check (exists (select 1 from public.employer_recruiters er where er.user_id=auth.uid() and er.company_id=companies.id and er.verification_status='verified'));
grant update (description,website,industries,locations,recruiting_majors,opportunities,updated_at) on public.companies to authenticated;
grant update (recruiter_name,title,phone,updated_at) on public.employer_recruiters to authenticated;

-- Students may see the employer connections that belong to them. Recruiter
-- policies remain unchanged and universities still receive aggregates only.
drop policy if exists "Students can view own employer connections" on public.employer_connections;
create policy "Students can view own employer connections"
on public.employer_connections for select to authenticated
using (student_user_id = auth.uid());

create table if not exists public.connection_messages (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('student','employer')),
  body text not null check (char_length(trim(body)) between 1 and 2000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists connection_messages_thread_idx
on public.connection_messages (student_user_id, company_id, created_at);

alter table public.connection_messages enable row level security;

drop policy if exists "Connected participants can read messages" on public.connection_messages;
create policy "Connected participants can read messages"
on public.connection_messages for select to authenticated
using (
  exists (select 1 from public.employer_connections ec
          where ec.student_user_id = connection_messages.student_user_id
            and ec.company_id = connection_messages.company_id)
  and (
    auth.uid() = student_user_id
    or exists (select 1 from public.employer_recruiters er
               where er.user_id = auth.uid()
                 and er.company_id = connection_messages.company_id
                 and er.verification_status = 'verified')
  )
);

drop policy if exists "Connected participants can send messages" on public.connection_messages;
create policy "Connected participants can send messages"
on public.connection_messages for insert to authenticated
with check (
  sender_user_id = auth.uid()
  and exists (select 1 from public.employer_connections ec
              where ec.student_user_id = connection_messages.student_user_id
                and ec.company_id = connection_messages.company_id)
  and (
    (sender_role = 'student' and auth.uid() = student_user_id)
    or (sender_role = 'employer' and exists (
      select 1 from public.employer_recruiters er
      where er.user_id = auth.uid()
        and er.company_id = connection_messages.company_id
        and er.verification_status = 'verified'
    ))
  )
);

drop policy if exists "Connected participants can mark messages read" on public.connection_messages;
create policy "Connected participants can mark messages read"
on public.connection_messages for update to authenticated
using (
  (auth.uid() = student_user_id and sender_role = 'employer')
  or (sender_role = 'student' and exists (
    select 1 from public.employer_recruiters er
    where er.user_id = auth.uid()
      and er.company_id = connection_messages.company_id
      and er.verification_status = 'verified'
  ))
)
with check (
  student_user_id = student_user_id and company_id = company_id
);

grant select, insert on public.connection_messages to authenticated;
grant update (read_at) on public.connection_messages to authenticated;
grant usage, select on sequence public.connection_messages_id_seq to authenticated;

-- Allow message alerts to use the existing student notification system.
alter table public.student_notifications
  drop constraint if exists student_notifications_notification_type_check;
alter table public.student_notifications
  add constraint student_notifications_notification_type_check
  check (notification_type in ('connection','outcome','career_fair','card','profile','message'));

create or replace function public.notify_student_of_employer_message()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_company text;
begin
  if new.sender_role <> 'employer' then return new; end if;
  select name into v_company from public.companies where id = new.company_id;
  insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata)
  values(new.student_user_id,'message','New employer message',
         coalesce(v_company,'An employer') || ' sent you a message.','dashboard.html#messages',
         jsonb_build_object('company_id',new.company_id,'message_id',new.id));
  return new;
end;
$$;

drop trigger if exists notify_student_of_employer_message_trigger on public.connection_messages;
create trigger notify_student_of_employer_message_trigger
after insert on public.connection_messages for each row
execute function public.notify_student_of_employer_message();

-- Immutable recruiting activity creates a useful timeline for employers while
-- allowing universities to receive aggregate engagement data without seeing
-- recruiter notes or private message contents.
create table if not exists public.candidate_activity (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete cascade,
  recruiter_user_id uuid references auth.users(id) on delete set null,
  career_fair_id bigint references public.career_fairs(id) on delete set null,
  event_name text,
  activity_type text not null check (activity_type in ('connected','message','follow_up','interview','internship','offer','accepted_offer','job','passed')),
  activity_label text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists candidate_activity_company_created_idx on public.candidate_activity(company_id,created_at desc);
create index if not exists candidate_activity_student_created_idx on public.candidate_activity(student_user_id,created_at desc);
alter table public.candidate_activity enable row level security;
drop policy if exists "Company recruiters can view candidate activity" on public.candidate_activity;
create policy "Company recruiters can view candidate activity" on public.candidate_activity for select to authenticated
using (exists(select 1 from public.employer_recruiters er where er.user_id=auth.uid() and er.company_id=candidate_activity.company_id));
grant select on public.candidate_activity to authenticated;

create or replace function public.capture_candidate_status_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_fair bigint;
begin
  if tg_op='UPDATE' and new.candidate_status is not distinct from old.candidate_status then return new; end if;
  select cf.id into v_fair from public.career_fairs cf where lower(cf.name)=lower(new.event_name) limit 1;
  insert into public.candidate_activity(student_user_id,company_id,recruiter_user_id,career_fair_id,event_name,activity_type,activity_label)
  values(new.student_user_id,new.company_id,new.recruiter_user_id,v_fair,new.event_name,new.candidate_status,
    case new.candidate_status when 'connected' then 'Connected with employer' when 'follow_up' then 'Moved to follow-up' when 'interview' then 'Advanced to interview' when 'internship' then 'Internship recorded' when 'offer' then 'Offer recorded' when 'accepted_offer' then 'Offer accepted' when 'job' then 'Hired' when 'passed' then 'Recruiting process closed' else 'Candidate status updated' end);
  return new;
end;$$;
drop trigger if exists capture_candidate_status_activity_trigger on public.employer_connections;
create trigger capture_candidate_status_activity_trigger after insert or update of candidate_status on public.employer_connections for each row execute function public.capture_candidate_status_activity();

create or replace function public.capture_message_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.candidate_activity(student_user_id,company_id,recruiter_user_id,activity_type,activity_label,metadata)
  values(new.student_user_id,new.company_id,case when new.sender_role='employer' then new.sender_user_id else null end,'message',case when new.sender_role='employer' then 'Employer sent a message' else 'Student replied' end,jsonb_build_object('sender_role',new.sender_role));
  return new;
end;$$;
drop trigger if exists capture_message_activity_trigger on public.connection_messages;
create trigger capture_message_activity_trigger after insert on public.connection_messages for each row execute function public.capture_message_activity();

insert into public.candidate_activity(student_user_id,company_id,recruiter_user_id,event_name,activity_type,activity_label,created_at)
select ec.student_user_id,ec.company_id,ec.recruiter_user_id,ec.event_name,'connected','Connected with employer',ec.connected_at
from public.employer_connections ec
where not exists(select 1 from public.candidate_activity ca where ca.student_user_id=ec.student_user_id and ca.company_id=ec.company_id and ca.activity_type='connected');

-- Privacy-safe university analytics: useful engagement totals, never private
-- message bodies or recruiter notes. Results are scoped to the admin's school.
create or replace function public.university_recruiting_engagement()
returns table(company_id bigint,company_name text,total_connections bigint,total_messages bigint,follow_ups bigint,interviews bigint,internships bigint,offers bigint,hires bigint,last_activity_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_school text;
begin
  select school_name into v_school from public.university_admins where user_id=auth.uid() and verification_status='verified';
  if v_school is null then raise exception 'Verified university access required'; end if;
  return query
  select c.id,c.name,
    count(distinct (ec.student_user_id::text||':'||ec.company_id::text)),
    count(*) filter(where ca.activity_type='message'),count(*) filter(where ca.activity_type='follow_up'),
    count(*) filter(where ca.activity_type='interview'),count(*) filter(where ca.activity_type='internship'),
    count(*) filter(where ca.activity_type in ('offer','accepted_offer')),count(*) filter(where ca.activity_type='job'),max(ca.created_at)
  from public.companies c join public.employer_connections ec on ec.company_id=c.id
  join public.profiles p on p.id=ec.student_user_id and lower(trim(p.school))=lower(trim(v_school))
  left join public.candidate_activity ca on ca.company_id=ec.company_id and ca.student_user_id=ec.student_user_id
  group by c.id,c.name order by count(distinct ec.student_user_id) desc;
end;$$;
revoke all on function public.university_recruiting_engagement() from public;
grant execute on function public.university_recruiting_engagement() to authenticated;

commit;
