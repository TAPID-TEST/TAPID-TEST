-- Run once in the Supabase SQL Editor after the university workspace migrations.
begin;
create table if not exists public.employer_approval_email_jobs (
  history_id bigint primary key references public.employer_approval_history(id) on delete cascade,
  recruiter_user_id uuid not null references public.employer_recruiters(user_id) on delete cascade,
  school_name text not null,
  state text not null default 'pending' check (state in ('pending','sending','sent','failed')),
  claimed_at timestamptz,
  first_attempt_at timestamptz,
  payload jsonb,
  provider_id text,
  last_error text,
  sent_at timestamptz
);
alter table public.employer_approval_email_jobs enable row level security;
revoke all on public.employer_approval_email_jobs from public, anon, authenticated;
grant all on public.employer_approval_email_jobs to service_role;

create or replace function public.queue_employer_approval_email()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'verified' then
    insert into public.employer_approval_email_jobs(history_id,recruiter_user_id,school_name)
    values(new.id,new.recruiter_user_id,new.school_name) on conflict do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.queue_employer_approval_email() from public,anon,authenticated;
drop trigger if exists queue_approval_email on public.employer_approval_history;
create trigger queue_approval_email after insert on public.employer_approval_history
for each row execute function public.queue_employer_approval_email();

create or replace function public.university_approval_email_status()
returns table(user_id uuid,state text,last_error text,sent_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare school text := public.current_university_school();
begin
  if school is null then raise exception 'University administrator access required'; end if;
  return query
  select distinct on (j.recruiter_user_id) j.recruiter_user_id,j.state,j.last_error,j.sent_at
  from public.employer_approval_email_jobs j
  where public.tapid_school_key(j.school_name)=public.tapid_school_key(school)
  order by j.recruiter_user_id,j.history_id desc;
end;
$$;
revoke all on function public.university_approval_email_status() from public,anon;
grant execute on function public.university_approval_email_status() to authenticated;

-- Only the server function can claim a job. The actor is the server-validated JWT user.
create or replace function public.claim_employer_approval_email(p_actor uuid,p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  school text; recruiter public.employer_recruiters; decision public.employer_approval_history;
  job public.employer_approval_email_jobs; recipient text; confirmed timestamptz;
begin
  select ua.school_name into school from public.university_admins ua
  where ua.user_id=p_actor and ua.verification_status='verified';
  if school is null then raise exception 'University administrator access required'; end if;
  select * into recruiter from public.employer_recruiters r where r.user_id=p_user for update;
  if not found or recruiter.verification_status<>'verified'
    or public.tapid_school_key(recruiter.requested_school)<>public.tapid_school_key(school) then
    raise exception 'Approved employer in your university required';
  end if;
  select * into decision from public.employer_approval_history h
  where h.recruiter_user_id=p_user order by h.id desc limit 1;
  if not found or decision.status<>'verified' then raise exception 'Approval decision required'; end if;
  select u.email,u.email_confirmed_at into recipient,confirmed from auth.users u where u.id=p_user;
  if recipient is null or confirmed is null then raise exception 'Confirmed employer email required'; end if;
  insert into public.employer_approval_email_jobs(history_id,recruiter_user_id,school_name)
  values(decision.id,p_user,school) on conflict do nothing;
  select * into job from public.employer_approval_email_jobs j where j.history_id=decision.id for update;
  if job.state='sent' then return jsonb_build_object('state','sent','history_id',job.history_id); end if;
  if job.state='sending' and job.claimed_at>now()-interval '5 minutes' then
    return jsonb_build_object('state','sending','history_id',job.history_id);
  end if;
  -- Provider deduplication lasts 24 hours. Avoid resending an uncertain older attempt.
  if job.first_attempt_at<now()-interval '23 hours' then
    raise exception 'Email attempt needs manual review before retrying';
  end if;
  update public.employer_approval_email_jobs j set state='sending',claimed_at=now(),
    first_attempt_at=coalesce(j.first_attempt_at,now()),last_error=null,
    payload=coalesce(j.payload,jsonb_build_object('to',recipient,'school',school))
  where j.history_id=job.history_id returning * into job;
  return jsonb_build_object('state','claimed','history_id',job.history_id,'payload',job.payload);
end;
$$;
revoke all on function public.claim_employer_approval_email(uuid,uuid) from public,anon,authenticated;
grant execute on function public.claim_employer_approval_email(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;
