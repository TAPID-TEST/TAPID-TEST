begin;

-- Company profiles contain public recruiting information, not private recruiter data.
drop policy if exists "Authenticated users can view company profiles" on public.companies;
create policy "Authenticated users can view company profiles"
on public.companies for select to authenticated using (true);

alter table public.companies add column if not exists careers_url text;
alter table public.companies add column if not exists employee_size text;
alter table public.companies add column if not exists culture text;
alter table public.companies add column if not exists student_message text;
grant update (description,website,careers_url,employee_size,culture,student_message,industries,locations,recruiting_majors,opportunities,updated_at) on public.companies to authenticated;

alter table public.employer_connections add column if not exists priority text not null default 'normal' check(priority in ('low','normal','high'));
alter table public.employer_connections add column if not exists next_follow_up_at date;
grant update (candidate_status,priority,next_follow_up_at,private_notes,updated_at) on public.employer_connections to authenticated;

-- A connection has one current employer-verified milestone. Moving from
-- Interview to Offer updates that milestone instead of creating a second row.
delete from public.career_outcomes a
using public.career_outcomes b
where a.employer_connection_id=b.employer_connection_id
  and a.employer_connection_id is not null
  and (a.updated_at<b.updated_at or (a.updated_at=b.updated_at and a.id<b.id));

drop index if exists public.career_outcomes_employer_milestone_unique;
create unique index if not exists career_outcomes_current_employer_milestone_unique
on public.career_outcomes(employer_connection_id)
where employer_connection_id is not null;

create or replace function public.sync_verified_career_outcome()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_outcome_type text; v_company_name text;
begin
  if tg_op='UPDATE' and new.candidate_status is not distinct from old.candidate_status then return new; end if;
  v_outcome_type:=case new.candidate_status when 'interview' then 'interview' when 'internship' then 'internship' when 'offer' then 'offer' when 'accepted_offer' then 'accepted_offer' when 'job' then 'job' else null end;
  if v_outcome_type is null then
    delete from public.career_outcomes where employer_connection_id=new.id;
    return new;
  end if;
  select name into v_company_name from public.companies where id=new.company_id;
  insert into public.career_outcomes(student_user_id,career_fair_id,employer_connection_id,outcome_type,company_name,outcome_date,notes,is_public,verification_status,created_at,updated_at)
  values(new.student_user_id,new.career_fair_id,new.id,v_outcome_type,coalesce(v_company_name,'Employer'),current_date,case when new.event_name is not null then 'Verified through '||new.event_name else 'Verified by employer' end,false,'verified',now(),now())
  on conflict (employer_connection_id) where employer_connection_id is not null
  do update set outcome_type=excluded.outcome_type,career_fair_id=excluded.career_fair_id,company_name=excluded.company_name,outcome_date=excluded.outcome_date,notes=excluded.notes,is_public=false,verification_status='verified',updated_at=now();
  return new;
end;$$;

commit;
