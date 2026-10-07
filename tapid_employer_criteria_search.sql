-- TapID employer experience search. Existing accounts and data are preserved.
begin;

-- Usage counts only; no search text or student content is stored here.
create table if not exists public.employer_search_usage (
 recruiter_user_id uuid not null references auth.users(id) on delete cascade,
 window_start timestamptz not null,
 requests integer not null default 0,
 primary key(recruiter_user_id,window_start)
);
alter table public.employer_search_usage enable row level security;
revoke all on public.employer_search_usage from public,anon,authenticated;
grant select,insert,update,delete on public.employer_search_usage to service_role;

create or replace function public.claim_employer_search(p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare minute_start timestamptz:=date_trunc('minute',now()); day_start timestamptz:=date_trunc('day',now()); used integer;
begin
 if not exists(select 1 from public.employer_recruiters er where er.user_id=p_actor and er.verification_status='verified') then
  raise exception 'Verified employer access required' using errcode='42501';
 end if;
 -- Serialize each recruiter's usage across concurrent function instances.
 perform pg_advisory_xact_lock(hashtextextended('tapid-search:'||p_actor::text,0));
 select coalesce(sum(requests),0)::integer into used from public.employer_search_usage
 where recruiter_user_id=p_actor and window_start>=day_start;
 if used>=40 then return false; end if;
 select requests into used from public.employer_search_usage where recruiter_user_id=p_actor and window_start=minute_start;
 if coalesce(used,0)>=6 then return false; end if;
 insert into public.employer_search_usage(recruiter_user_id,window_start,requests) values(p_actor,minute_start,1)
 on conflict(recruiter_user_id,window_start) do update set requests=public.employer_search_usage.requests+1;
 delete from public.employer_search_usage where recruiter_user_id=p_actor and window_start<now()-interval '2 days';
 return true;
end;
$$;
revoke all on function public.claim_employer_search(uuid) from public,anon,authenticated;
grant execute on function public.claim_employer_search(uuid) to service_role;

-- No caller-supplied company or student IDs. Each request is scoped by auth.uid().
-- Only active public profiles and public, visible work sections are returned.
create or replace function public.employer_search_documents()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare employer_company bigint; result jsonb;
begin
 select er.company_id into employer_company from public.employer_recruiters er
 where er.user_id=auth.uid() and er.verification_status='verified';
 if employer_company is null then raise exception 'Verified employer access required' using errcode='42501'; end if;
 select coalesce(jsonb_agg(candidate.doc order by candidate.id),'[]'::jsonb) into result
 from (
  select p.id,jsonb_build_object('id',p.id,'username',p.username,
   'name',trim(concat_ws(' ',p.first_name,p.last_name)), 'major',p.major,'year',p.school_year,
   'entries',coalesce((
    select jsonb_agg(entry.doc order by entry.kind,entry.id)
    from (
     select 'experience' as kind,e.id::text as id,jsonb_build_object('id','experience:'||e.id,'kind','Experience',
      'title',e.title,'organization',to_jsonb(e)->>'company',
      'fields',jsonb_build_object('title',e.title,'overview',to_jsonb(e)->>'overview',
       'role',to_jsonb(e)->>'role_description','work',to_jsonb(e)->>'work_description',
       'problems',to_jsonb(e)->>'problems_solved','accomplishments',to_jsonb(e)->>'accomplishments'),
      'start_date',to_jsonb(e)->>'start_date','end_date',to_jsonb(e)->>'end_date') as doc
     from public.experiences e where e.user_id=p.id and e.is_public and coalesce(p.show_experiences,true)
     union all
     select 'project',j.id::text,jsonb_build_object('id','project:'||j.id,'kind','Project',
      'title',j.title,'organization',to_jsonb(j)->>'course_or_org',
      'fields',jsonb_build_object('title',j.title,'problem',to_jsonb(j)->>'problem',
       'role',to_jsonb(j)->>'role_description','process',to_jsonb(j)->>'process','result',to_jsonb(j)->>'result'),
      'start_date',to_jsonb(j)->>'start_date','end_date',to_jsonb(j)->>'end_date')
     from public.projects j where j.user_id=p.id and j.is_public and coalesce(p.show_projects,true)
     union all
     select 'skill',s.id::text,jsonb_build_object('id','skill:'||s.id,'kind','Skill','title',s.name,
      'organization',null,'fields',jsonb_build_object('name',s.name),'start_date',null,'end_date',null)
     from public.skills s where s.user_id=p.id and s.is_public and coalesce(p.show_skills,true)
    ) entry
   ),'[]'::jsonb)) as doc
  from public.profiles p where p.profile_active and p.card_activated
   and exists(select 1 from public.employer_connections ec where ec.company_id=employer_company and ec.student_user_id=p.id)
 ) candidate;
 return result;
end;
$$;
revoke all on function public.employer_search_documents() from public,anon;
grant execute on function public.employer_search_documents() to authenticated;
notify pgrst,'reload schema';
commit;
