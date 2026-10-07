begin;

-- Candidate Match receives only the signed-in approved recruiter's connected public profiles.
-- Stage, event, priority and action filters are applied together to each relationship server-side.
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
   'name',trim(concat_ws(' ',p.first_name,p.last_name)), 'major',p.major,'year',p.school_year,'school',p.school,
   'is_favorite',exists(select 1 from public.employer_student_favorites f where f.recruiter_user_id=auth.uid() and f.student_user_id=p.id),
   'relationships',coalesce((select jsonb_agg(jsonb_build_object(
    'event',coalesce(ec.event_name,cf.name,'Direct connection'),'stage',ec.candidate_status,'priority',ec.priority,
    'needs_action',((ec.next_follow_up_at is not null and ec.next_follow_up_at::date <= (now() at time zone 'America/Los_Angeles')::date
      and ec.candidate_status not in ('job','passed')) or exists(select 1 from public.connection_messages m
      where m.company_id=employer_company and m.student_user_id=p.id and m.sender_role='student' and m.read_at is null))))
    from public.employer_connections ec left join public.career_fairs cf on cf.id=ec.career_fair_id
    where ec.company_id=employer_company and ec.student_user_id=p.id),'[]'::jsonb),
   'events',coalesce((select jsonb_agg(distinct coalesce(ec.event_name,cf.name,'Direct connection'))
    from public.employer_connections ec left join public.career_fairs cf on cf.id=ec.career_fair_id
    where ec.company_id=employer_company and ec.student_user_id=p.id),'[]'::jsonb),
   'resume_path',(select r.file_path from public.resumes r where r.user_id=p.id and r.is_public and split_part(r.file_path,'/',1)=p.id::text
    and coalesce((to_jsonb(p)->>'show_resume')::boolean,true) limit 1),
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


-- First outbound message advances only new/planned connections. It never rolls back review or outcomes.
create or replace function public.tapid_message_marks_contacted()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.sender_role='employer' and exists(
  select 1 from public.employer_recruiters er where er.user_id=new.sender_user_id
   and er.company_id=new.company_id and er.verification_status='verified'
 ) then
  update public.employer_connections set candidate_status='contacted',updated_at=now()
  where company_id=new.company_id and student_user_id=new.student_user_id
   and candidate_status in ('connected','follow_up');
 end if;
 return new;
end;
$$;
revoke all on function public.tapid_message_marks_contacted() from public,anon,authenticated;
drop trigger if exists tapid_message_marks_contacted on public.connection_messages;
create trigger tapid_message_marks_contacted after insert on public.connection_messages
for each row execute function public.tapid_message_marks_contacted();

notify pgrst,'reload schema';
commit;
