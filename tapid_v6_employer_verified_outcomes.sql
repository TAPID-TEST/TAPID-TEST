-- TapID V6: employer-verified career outcomes
-- Run once in the correct Supabase project's SQL Editor.

begin;

-- Employers need outcome-specific statuses in addition to workflow statuses.
alter table public.employer_connections
  drop constraint if exists employer_connections_candidate_status_check;

alter table public.employer_connections
  add constraint employer_connections_candidate_status_check
  check (candidate_status in (
    'connected','follow_up','interview','internship','offer',
    'accepted_offer','job','passed'
  ));

-- One verified milestone of each kind per employer connection.
create unique index if not exists career_outcomes_employer_milestone_unique
on public.career_outcomes (employer_connection_id, outcome_type)
where employer_connection_id is not null;

-- Students may read verified outcomes and choose public visibility, but cannot
-- create, rewrite, or delete the employer-verified record.
drop policy if exists "Students manage own outcomes" on public.career_outcomes;
drop policy if exists "Students view own outcomes" on public.career_outcomes;
drop policy if exists "Students control verified outcome visibility" on public.career_outcomes;

create policy "Students view own outcomes"
on public.career_outcomes
for select to authenticated
using (student_user_id = auth.uid());

create policy "Students control verified outcome visibility"
on public.career_outcomes
for update to authenticated
using (student_user_id = auth.uid() and verification_status = 'verified')
with check (student_user_id = auth.uid() and verification_status = 'verified');

drop policy if exists "Public can view public outcomes" on public.career_outcomes;
create policy "Public can view public outcomes"
on public.career_outcomes
for select to anon, authenticated
using (
  is_public = true
  and verification_status = 'verified'
  and exists (
    select 1 from public.profiles p
    where p.id = student_user_id
      and p.profile_active
      and p.card_activated
      and p.show_outcomes
  )
);

revoke insert, delete, update on public.career_outcomes from authenticated;
grant select on public.career_outcomes to authenticated;
grant update (is_public, updated_at) on public.career_outcomes to authenticated;

-- University reporting counts only employer-verified milestones.
create or replace function public.university_outcome_summary()
returns table (outcome_type text, outcomes bigint, verified bigint)
language plpgsql stable security definer set search_path=public as $$
declare v_school text;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'University administrator access required'; end if;
  return query
  select o.outcome_type, count(*)::bigint, count(*)::bigint
  from public.career_outcomes o
  join public.profiles p on p.id=o.student_user_id
  where lower(trim(coalesce(p.school,'')))=lower(trim(v_school))
    and o.verification_status='verified'
  group by o.outcome_type
  order by count(*) desc;
end;
$$;

revoke all on function public.university_outcome_summary() from public;
grant execute on function public.university_outcome_summary() to authenticated;

create or replace function public.sync_verified_career_outcome()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_outcome_type text;
  v_company_name text;
begin
  if tg_op = 'UPDATE' and new.candidate_status is not distinct from old.candidate_status then
    return new;
  end if;

  v_outcome_type := case new.candidate_status
    when 'interview' then 'interview'
    when 'internship' then 'internship'
    when 'offer' then 'offer'
    when 'accepted_offer' then 'accepted_offer'
    when 'job' then 'job'
    else null
  end;

  if v_outcome_type is null then
    return new;
  end if;

  select c.name into v_company_name
  from public.companies c
  where c.id = new.company_id;

  insert into public.career_outcomes (
    student_user_id,
    career_fair_id,
    employer_connection_id,
    outcome_type,
    company_name,
    outcome_date,
    notes,
    is_public,
    verification_status,
    created_at,
    updated_at
  ) values (
    new.student_user_id,
    new.career_fair_id,
    new.id,
    v_outcome_type,
    coalesce(v_company_name, 'Employer'),
    current_date,
    case when new.event_name is not null then 'Verified through ' || new.event_name else 'Verified by employer' end,
    false,
    'verified',
    now(),
    now()
  )
  on conflict (employer_connection_id, outcome_type)
    where employer_connection_id is not null
  do update set
    career_fair_id = excluded.career_fair_id,
    company_name = excluded.company_name,
    outcome_date = excluded.outcome_date,
    notes = excluded.notes,
    verification_status = 'verified',
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists sync_verified_career_outcome_trigger
on public.employer_connections;

create trigger sync_verified_career_outcome_trigger
after insert or update of candidate_status
on public.employer_connections
for each row execute function public.sync_verified_career_outcome();

commit;
