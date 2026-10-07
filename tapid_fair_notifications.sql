begin;
alter table public.student_notifications add column if not exists fair_notice_key text;
-- Reuse existing publication alerts so installing this patch does not duplicate them.
with existing as (
 select id,row_number() over(partition by student_user_id,metadata->>'career_fair_id' order by id) as row_rank
 from public.student_notifications where notification_type='career_fair'
 and metadata ? 'career_fair_id' and fair_notice_key is null
)
update public.student_notifications n set fair_notice_key='fair:'||(n.metadata->>'career_fair_id')||':published'
from existing e where e.id=n.id and e.row_rank=1 and not exists(select 1 from public.student_notifications prior
 where prior.student_user_id=n.student_user_id and prior.fair_notice_key='fair:'||(n.metadata->>'career_fair_id')||':published');
create unique index if not exists student_fair_notice_unique
 on public.student_notifications(student_user_id,fair_notice_key) where fair_notice_key is not null;
create table if not exists public.employer_fair_notifications (
 id bigint generated always as identity primary key,
 recruiter_user_id uuid not null references public.employer_recruiters(user_id) on delete cascade,
 career_fair_id bigint not null references public.career_fairs(id) on delete cascade,
 notice_key text not null,
 title text not null,body text not null,read_at timestamptz,created_at timestamptz not null default now(),
 unique(recruiter_user_id,notice_key)
);
alter table public.employer_fair_notifications enable row level security;
revoke all on public.employer_fair_notifications from public,anon,authenticated;
grant select on public.employer_fair_notifications to authenticated;
grant update(read_at) on public.employer_fair_notifications to authenticated;
drop policy if exists "Own recruiter fair notifications" on public.employer_fair_notifications;
create policy "Own recruiter fair notifications" on public.employer_fair_notifications
 for select to authenticated using(recruiter_user_id=auth.uid());
drop policy if exists "Read own recruiter fair notifications" on public.employer_fair_notifications;
create policy "Read own recruiter fair notifications" on public.employer_fair_notifications
 for update to authenticated using(recruiter_user_id=auth.uid()) with check(recruiter_user_id=auth.uid());

-- The university-managed roster and older approved rosters form one fair directory.
create or replace function public.tapid_fair_roster()
returns table(career_fair_id bigint,company_id bigint,company_name text)
language sql stable security definer set search_path='' as $$
 select distinct on (roster.fair_id,roster.identity_key) roster.fair_id,roster.company_id,roster.company_name
 from (
  select ie.career_fair_id as fair_id,iee.company_id,iee.company_name,
   coalesce('id:'||iee.company_id::text,'name:'||lower(trim(iee.company_name))) as identity_key
  from public.integration_events ie join public.integration_event_employers iee on iee.integration_event_id=ie.id
  where ie.career_fair_id is not null
  union all
  select cfe.career_fair_id,cfe.company_id,c.name,'id:'||cfe.company_id::text
  from public.career_fair_employers cfe join public.companies c on c.id=cfe.company_id where cfe.status='approved'
 ) roster order by roster.fair_id,roster.identity_key,roster.company_name;
$$;
revoke all on function public.tapid_fair_roster() from public,anon,authenticated;

create or replace function public.refresh_fair_notifications(p_fair bigint default null,p_user uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 -- A calendar-day boundary in the fair's local timezone controls each reminder.
 with fairs as (
  select cf.*,(cf.starts_at at time zone 'America/Los_Angeles')::date-
   (now() at time zone 'America/Los_Angeles')::date as days_until
  from public.career_fairs cf where cf.is_published and (p_fair is null or cf.id=p_fair)
   and (coalesce(cf.ends_at,cf.starts_at+interval '1 day') is null or coalesce(cf.ends_at,cf.starts_at+interval '1 day')>=now())
 ), notices as (
  select f.*, 'published'::text as phase,'New career fair'::text as notice_title from fairs f
  union all
  select f.*,case when days_until=0 then 'today' when days_until=1 then 'tomorrow' else 'week' end,
   case when days_until=0 then 'Career fair today' when days_until=1 then 'Career fair tomorrow' else 'Career fair this week' end
  from fairs f where f.days_until between 0 and 7
 )
 insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata,fair_notice_key)
 select p.id,'career_fair',n.notice_title,n.name||case when n.starts_at is null then ' · Date to be announced'
 else ' · '||to_char(n.starts_at at time zone 'America/Los_Angeles','Mon DD, YYYY HH12:MI AM') end||
 case when n.location is null then '' else ' · '||n.location end,
 'dashboard.html#career-fairs',jsonb_build_object('career_fair_id',n.id,'phase',n.phase),
 'fair:'||n.id::text||':'||n.phase||case when n.phase='published' then '' else ':'||extract(epoch from n.starts_at)::text end
 from notices n join public.profiles p on public.tapid_school_key(p.school)=public.tapid_school_key(n.school_name)
 left join public.notification_preferences np on np.student_user_id=p.id
 where (p_user is null or p.id=p_user) and coalesce(np.career_fair_updates,true)
 on conflict(student_user_id,fair_notice_key) where fair_notice_key is not null do nothing;

 with fairs as (
  select cf.*,(cf.starts_at at time zone 'America/Los_Angeles')::date-
   (now() at time zone 'America/Los_Angeles')::date as days_until
  from public.career_fairs cf where cf.is_published and (p_fair is null or cf.id=p_fair)
   and (coalesce(cf.ends_at,cf.starts_at+interval '1 day') is null or coalesce(cf.ends_at,cf.starts_at+interval '1 day')>=now())
 ), notices as (
  select f.*,'listed'::text as phase,'Your company is listed for a career fair'::text as notice_title from fairs f
  union all
  select f.*,case when days_until=0 then 'today' when days_until=1 then 'tomorrow' else 'week' end,
   case when days_until=0 then 'Career fair today' when days_until=1 then 'Career fair tomorrow' else 'Career fair this week' end
  from fairs f where f.days_until between 0 and 7
 )
 insert into public.employer_fair_notifications(recruiter_user_id,career_fair_id,notice_key,title,body)
 select er.user_id,n.id,'fair:'||n.id::text||':'||n.phase||case when n.phase='listed' then '' else ':'||extract(epoch from n.starts_at)::text end,
 n.notice_title,n.name||case when n.starts_at is null then ' · Date to be announced'
 else ' · '||to_char(n.starts_at at time zone 'America/Los_Angeles','Mon DD, YYYY HH12:MI AM') end||
 case when n.location is null then '' else ' · '||n.location end
 from notices n join public.tapid_fair_roster() roster on roster.career_fair_id=n.id
 join public.employer_recruiters er on er.company_id=roster.company_id
  and er.verification_status='verified' and public.tapid_school_key(er.requested_school)=public.tapid_school_key(n.school_name)
 where p_user is null or er.user_id=p_user
 on conflict(recruiter_user_id,notice_key) do nothing;
end;$$;
revoke all on function public.refresh_fair_notifications(bigint,uuid) from public,anon,authenticated;
grant execute on function public.refresh_fair_notifications(bigint,uuid) to service_role;

create or replace function public.notify_published_career_fair()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.is_published then perform public.refresh_fair_notifications(new.id,null); end if;
 return new;
end;$$;
drop trigger if exists notify_published_career_fair_trigger on public.career_fairs;
create trigger notify_published_career_fair_trigger after insert or update of is_published,starts_at,ends_at,location,name
 on public.career_fairs for each row execute function public.notify_published_career_fair();
revoke all on function public.notify_published_career_fair() from public,anon,authenticated;

create or replace function public.notify_fair_roster_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare fair_id bigint;
begin
 if tg_table_name='integration_event_employers' then
  select ie.career_fair_id into fair_id from public.integration_events ie where ie.id=new.integration_event_id;
 else fair_id:=new.career_fair_id; end if;
 if fair_id is not null then perform public.refresh_fair_notifications(fair_id,null); end if;
 return new;
end;$$;
revoke all on function public.notify_fair_roster_change() from public,anon,authenticated;
drop trigger if exists notify_imported_fair_roster on public.integration_event_employers;
create trigger notify_imported_fair_roster after insert or update of company_id on public.integration_event_employers
 for each row execute function public.notify_fair_roster_change();
drop trigger if exists notify_approved_fair_roster on public.career_fair_employers;
create trigger notify_approved_fair_roster after insert or update of status on public.career_fair_employers
 for each row execute function public.notify_fair_roster_change();

create or replace function public.my_fair_workspace()
returns jsonb language plpgsql security definer set search_path='' as $$
declare school text; employer_company bigint; is_student boolean; fairs jsonb; directory jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select p.school into school from public.profiles p where p.id=auth.uid();is_student:=found;
 if not is_student then
  select er.requested_school,er.company_id into school,employer_company from public.employer_recruiters er
  where er.user_id=auth.uid() and er.verification_status='verified';
  if not found then raise exception 'Approved employer or student account required'; end if;
 end if;
 perform public.refresh_fair_notifications(null,auth.uid());
 select coalesce(jsonb_agg(to_jsonb(f) order by f.starts_at nulls last,f.name),'[]'::jsonb) into fairs from (
  select cf.id,cf.name,cf.starts_at,cf.ends_at,cf.location,cf.description from public.career_fairs cf
  where cf.is_published and public.tapid_school_key(cf.school_name)=public.tapid_school_key(school)
  and (coalesce(cf.ends_at,cf.starts_at+interval '1 day') is null or coalesce(cf.ends_at,cf.starts_at+interval '1 day')>=now())
  and (is_student or exists(select 1 from public.tapid_fair_roster() r where r.career_fair_id=cf.id and r.company_id=employer_company))
 ) f;
 select coalesce(jsonb_agg(to_jsonb(entry) order by entry.event_name,entry.company_name),'[]'::jsonb) into directory from (
  select cf.id as career_fair_id,cf.name as event_name,r.company_id,r.company_name,
   exists(select 1 from public.employer_recruiters er where er.company_id=r.company_id and er.verification_status='verified'
    and public.tapid_school_key(er.requested_school)=public.tapid_school_key(school)) as can_connect,
   req.status as request_status,req.id as request_id
  from public.career_fairs cf join public.tapid_fair_roster() r on r.career_fair_id=cf.id
  left join lateral (select q.status,q.id from public.employer_connection_requests q where q.student_user_id=auth.uid()
   and q.company_id=r.company_id and (q.career_fair_id=cf.id or (q.career_fair_id is null and q.event_name=cf.name)) order by q.id desc limit 1) req on true
  where is_student and cf.is_published and public.tapid_school_key(cf.school_name)=public.tapid_school_key(school)
   and (coalesce(cf.ends_at,cf.starts_at+interval '1 day') is null or coalesce(cf.ends_at,cf.starts_at+interval '1 day')>=now())
 ) entry;
 return jsonb_build_object('fairs',fairs,'directory',directory);
end;$$;
revoke all on function public.my_fair_workspace() from public,anon;
grant execute on function public.my_fair_workspace() to authenticated;

create or replace function public.request_fair_employer_connection(p_fair_id bigint,p_company_id bigint,p_message text)
returns bigint language plpgsql security definer set search_path='' as $$
declare fair public.career_fairs; student public.profiles; request_id bigint;
begin
 select * into student from public.profiles p where p.id=auth.uid() and p.profile_active and p.card_activated;
 if not found then raise exception 'An active student TapID is required'; end if;
 if nullif(trim(p_message),'') is null or length(trim(p_message))>500 then raise exception 'Message must contain 1 to 500 characters'; end if;
 select * into fair from public.career_fairs cf where cf.id=p_fair_id and cf.is_published
  and public.tapid_school_key(cf.school_name)=public.tapid_school_key(student.school)
  and (coalesce(cf.ends_at,cf.starts_at+interval '1 day') is null or coalesce(cf.ends_at,cf.starts_at+interval '1 day')>=now());
 if not found then raise exception 'Published upcoming fair required'; end if;
 if not exists(select 1 from public.tapid_fair_roster() r where r.career_fair_id=fair.id and r.company_id=p_company_id)
  or not exists(select 1 from public.employer_recruiters er where er.company_id=p_company_id and er.verification_status='verified'
   and public.tapid_school_key(er.requested_school)=public.tapid_school_key(student.school)) then
  raise exception 'Approved employer listed for this fair required';
 end if;
 if exists(select 1 from public.employer_connection_requests q where q.student_user_id=auth.uid() and q.company_id=p_company_id
  and (q.career_fair_id=fair.id or (q.career_fair_id is null and q.event_name=fair.name))) then
  raise exception 'You already sent this employer a request for this fair';
 end if;
 insert into public.employer_connection_requests(student_user_id,company_id,event_name,message,career_fair_id)
 values(auth.uid(),p_company_id,fair.name,trim(p_message),fair.id) returning id into request_id;
 return request_id;
exception when unique_violation then raise exception 'You already sent this employer a request for this fair';
end;$$;
revoke all on function public.request_fair_employer_connection(bigint,bigint,text) from public,anon;
grant execute on function public.request_fair_employer_connection(bigint,bigint,text) to authenticated;
select public.refresh_fair_notifications(null,null);
-- Install the background reminder job when Cron is available. Opening either
-- dashboard also refreshes reminders, so a missing Cron module does not break it.
do $schedule$
begin
 begin
  create extension if not exists pg_cron;
  perform cron.schedule('tapid-career-fair-reminders','0 * * * *',
   'select public.refresh_fair_notifications(null,null);');
 exception when others then
  raise warning 'Background reminders not scheduled: %. Enable pg_cron and run tapid_fair_reminder_schedule.sql.',sqlerrm;
 end;
end;
$schedule$;
notify pgrst,'reload schema';
commit;
