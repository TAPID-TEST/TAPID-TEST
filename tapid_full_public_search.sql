begin;
-- Career interests: narrative answers, retaining all existing saved preferences.
alter table public.student_opportunity_preferences
 add column if not exists opportunity_statement text,
 add column if not exists career_goal_statement text,
 add column if not exists additional_context text,
 add column if not exists interests_format text default 'legacy';
alter table public.student_opportunity_preferences drop constraint if exists student_opportunity_preferences_statement_length;
alter table public.student_opportunity_preferences drop constraint if exists student_opportunity_preferences_goal_length;
alter table public.student_opportunity_preferences drop constraint if exists student_opportunity_preferences_context_length;
alter table public.student_opportunity_preferences
 add constraint student_opportunity_preferences_statement_length check (opportunity_statement is null or char_length(opportunity_statement)<=1200),
 add constraint student_opportunity_preferences_goal_length check (career_goal_statement is null or char_length(career_goal_statement)<=1200),
 add constraint student_opportunity_preferences_context_length check (additional_context is null or char_length(additional_context)<=1200);
-- Whitelist public presentation fields, never raw records or private writer contact fields.
create or replace function public.tapid_search_public_fields(document jsonb, allowed_keys text[])
returns jsonb language sql immutable set search_path='' as $fields$
 select coalesce(jsonb_object_agg(e.key,case when jsonb_typeof(e.value)='array'
  then (select string_agg(v.value, ', ') from jsonb_array_elements_text(e.value) v(value))
  else e.value #>> '{}' end),'{}'::jsonb)
 from jsonb_each(document) e where e.key=any(allowed_keys) and e.value<>'null'::jsonb;
$fields$;
revoke all on function public.tapid_search_public_fields(jsonb,text[]) from public,anon,authenticated;

create or replace function public.employer_search_documents()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare employer_company bigint; result jsonb;
begin
 if auth.uid() is null then raise exception 'Search session missing' using errcode='42501', detail='TAPID_SESSION_MISSING'; end if;
 select er.company_id into employer_company from public.employer_recruiters er
 where er.user_id=auth.uid() and er.verification_status='verified';
 if employer_company is null then raise exception 'Verified employer access required' using errcode='42501', detail='TAPID_RECRUITER_UNVERIFIED'; end if;
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
   'public_documents',coalesce((select jsonb_agg(x.document) from (
    select jsonb_build_object('entry_id','recommendation:'||r.id,'kind','Recommendation','title','Letter by '||r.author_name,'path',r.letter_path,'bucket','media') document
    from public.recommendations r where r.student_user_id=p.id and r.is_public and r.status='submitted' and coalesce(p.show_recommendations,true)
      and r.letter_path is not null and split_part(r.letter_path,'/',1)=p.id::text
    union all
    select jsonb_build_object('entry_id','media:'||m.id,'kind','Public attachment','title',coalesce(nullif(m.caption,''),'Public document'),'path',m.file_path,'bucket','media')
    from public.media m where m.user_id=p.id and split_part(m.file_path,'/',1)=p.id::text
      and (to_jsonb(m)->>'media_type'='pdf' or lower(m.file_path) like '%.pdf')
      and coalesce((to_jsonb(m)->>'is_public')::boolean,true)
      and (
       exists(select 1 from public.experiences e where e.id=m.experience_id and e.user_id=p.id and e.is_public and coalesce(p.show_experiences,true))
       or exists(select 1 from public.projects j where j.id=m.project_id and j.user_id=p.id and j.is_public and coalesce(p.show_projects,true))
       or exists(select 1 from public.certifications c where c.id=m.certification_id and c.user_id=p.id and c.is_public and coalesce(p.show_certifications,true))
      )
   ) x),'[]'::jsonb),
   'entries',coalesce((
    select jsonb_agg(entry.doc order by entry.kind,entry.id)
    from (
     select 'experience' as kind,e.id::text as id,jsonb_build_object('id','experience:'||e.id,'kind','Experience',
      'title',e.title,'organization',to_jsonb(e)->>'company',
      'fields',public.tapid_search_public_fields(to_jsonb(e),array['title','company','experience_type','location','overview','role_description','work_description','problems_solved','accomplishments','lessons_learned','is_current']),
      'start_date',to_jsonb(e)->>'start_date','end_date',to_jsonb(e)->>'end_date') as doc
     from public.experiences e where e.user_id=p.id and e.is_public and coalesce(p.show_experiences,true)
     union all
     select 'project',j.id::text,jsonb_build_object('id','project:'||j.id,'kind','Project',
      'title',j.title,'organization',to_jsonb(j)->>'course_or_org',
      'fields',public.tapid_search_public_fields(to_jsonb(j),array['title','course_or_org','problem','role_description','process','result','lessons_learned','team_size','external_url']),
      'start_date',to_jsonb(j)->>'start_date','end_date',to_jsonb(j)->>'end_date')
     from public.projects j where j.user_id=p.id and j.is_public and coalesce(p.show_projects,true)
     union all
     select 'skill',s.id::text,jsonb_build_object('id','skill:'||s.id,'kind','Skill','title',s.name,
      'organization',null,'fields',public.tapid_search_public_fields(to_jsonb(s),array['name','category','proficiency','description']),'start_date',null,'end_date',null)
     from public.skills s where s.user_id=p.id and s.is_public and coalesce(p.show_skills,true)

     union all
     select 'profile',p.id::text,jsonb_build_object('id','profile:'||p.id,'kind','Profile','title','Public bio',
      'fields',public.tapid_search_public_fields(to_jsonb(p),array['bio','major','school_year','graduation_year','headline']))
     union all
     select 'organization',o.id::text,jsonb_build_object('id','organization:'||o.id,'kind','Organization',
      'title',o.name,'organization',o.name,'start_date',to_jsonb(o)->>'start_date','end_date',to_jsonb(o)->>'end_date',
      'fields',public.tapid_search_public_fields(to_jsonb(o),array['name','role','description','accomplishments','is_current']))
     from public.organizations o where o.user_id=p.id and o.is_public and coalesce(p.show_organizations,true)
     union all
     select 'certification',c.id::text,jsonb_build_object('id','certification:'||c.id,'kind','Certification',
      'title',c.name,'organization',to_jsonb(c)->>'issuer',
      'fields',public.tapid_search_public_fields(to_jsonb(c),array['name','issuer','issued_date','issue_date','expiration_date','credential_id','credential_url','description']))
     from public.certifications c where c.user_id=p.id and c.is_public and coalesce(p.show_certifications,true)
     union all
     select 'recommendation',r.id::text,jsonb_build_object('id','recommendation:'||r.id,'kind','Recommendation',
      'title','Recommendation by '||r.author_name,'organization',r.author_organization,
      'fields',public.tapid_search_public_fields(to_jsonb(r),array['author_name','author_title','author_organization','relationship','recommendation_text']))
     from public.recommendations r where r.student_user_id=p.id and r.is_public and r.status='submitted' and coalesce(p.show_recommendations,true)
     union all
     select 'opportunity',o.student_user_id::text,jsonb_build_object('id','opportunity:'||o.student_user_id,'kind','Career interests','title','Career interests',
      'fields',public.tapid_search_public_fields(to_jsonb(o),array['opportunity_statement','career_goal_statement','additional_context','preferred_locations','available_start_date','willing_to_relocate'] || case when coalesce(o.interests_format,'legacy')<>'narrative' and nullif(trim(o.opportunity_statement),'') is null then array['opportunity_types','desired_roles','industries'] else array[]::text[] end))
     from public.student_opportunity_preferences o where o.student_user_id=p.id and o.is_public
     union all
     select 'link',l.id::text,jsonb_build_object('id','link:'||l.id,'kind','Professional link','title',coalesce(to_jsonb(l)->>'label','Professional link'),
      'fields',public.tapid_search_public_fields(to_jsonb(l),array['label','title','url','description']))
     from public.links l where l.user_id=p.id and l.is_public and coalesce((to_jsonb(p)->>'show_links')::boolean,true)
     union all
     select 'outcome',o.id::text,jsonb_build_object('id','outcome:'||o.id,'kind','Public outcome','title',o.outcome_type,
      'organization',o.company_name,'fields',public.tapid_search_public_fields(to_jsonb(o),array['title','company_name','outcome_type','outcome_date','notes']))
     from public.career_outcomes o where o.student_user_id=p.id and o.is_public and o.verification_status='verified' and p.show_outcomes is true

     union all
     select 'media',m.id::text,jsonb_build_object('id','media:'||m.id,'kind','Public media caption','title','Project or experience media',
      'fields',public.tapid_search_public_fields(to_jsonb(m),array['caption']))
     from public.media m where m.user_id=p.id and coalesce((to_jsonb(m)->>'is_public')::boolean,true) and nullif(m.caption,'') is not null
      and (exists(select 1 from public.experiences e where e.id=m.experience_id and e.user_id=p.id and e.is_public and coalesce(p.show_experiences,true))
       or exists(select 1 from public.projects j where j.id=m.project_id and j.user_id=p.id and j.is_public and coalesce(p.show_projects,true))
       or exists(select 1 from public.certifications c where c.id=m.certification_id and c.user_id=p.id and c.is_public and coalesce(p.show_certifications,true)))
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


create or replace function public.university_student_directory_filtered(
  p_search text default '',p_major text default '',p_year text default '',p_state text default '',p_page integer default 0,p_college text default ''
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_rows jsonb;v_total bigint;v_page integer:=greatest(0,coalesce(p_page,0));
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  if coalesce(p_state,'') not in ('','unconfirmed','setup','ready','active','connected','no-connections','never-connected') then raise exception 'Invalid student filter'; end if;
  with matched as (
    select s.* from public.tapid_university_student_rows(v_school) s
    where (coalesce(p_search,'')='' or position(lower(trim(p_search)) in lower(s.student_name||' '||coalesce(s.username,'')))>0)
      and (coalesce(p_college,'')='' or public.tapid_program_college(v_school,s.major)=p_college)
      and (coalesce(p_major,'')='' or s.major=p_major) and (coalesce(p_year,'')='' or s.class_year=p_year)
      and (coalesce(p_state,'')='' or
        (p_state='unconfirmed' and not s.email_confirmed) or
        (p_state='setup' and s.email_confirmed and not s.public_active and not s.basics_complete) or
        (p_state='ready' and s.email_confirmed and s.basics_complete and not s.public_active) or
        (p_state='active' and s.public_active) or (p_state='connected' and s.connections>0) or
        (p_state='no-connections' and s.public_active and s.connections=0) or (p_state='never-connected' and s.connections=0))
  ),page_rows as (select * from matched order by joined_at desc,user_id limit 50 offset v_page*50)
  select (select count(*) from matched),coalesce(jsonb_agg(jsonb_build_object(
    'name',s.student_name,'username',case when s.public_active then s.username else null end,
    'college',public.tapid_program_college(v_school,s.major),'joined_at',s.joined_at,'major',s.major,'class_year',s.class_year,
    'email_confirmed',s.email_confirmed,'card_assigned',s.card_assigned,'public_active',s.public_active,
    'status',case when not s.email_confirmed then 'Confirm email' when s.public_active then 'Active'
      when not s.basics_complete then 'Finish basics' else 'Activate profile' end,
    'connections',s.connections,'last_connection_at',s.last_connection_at
  ) order by s.joined_at desc,s.user_id),'[]'::jsonb) into v_total,v_rows from page_rows s;
  return jsonb_build_object('rows',v_rows,'total',v_total,'page',v_page,'page_size',50);
end;$$;
revoke all on function public.university_student_directory_filtered(text,text,text,text,integer,text) from public,anon;
grant execute on function public.university_student_directory_filtered(text,text,text,text,integer,text) to authenticated;


create or replace function public.university_fair_report_v2()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_report jsonb; v_events jsonb; v_school text;
begin
 v_school:=public.current_university_school();
 if v_school is null then raise exception 'Verified university access required' using errcode='42501'; end if;
 v_report:=public.university_fair_report();
 select coalesce(jsonb_agg(e.value||jsonb_build_object('ends_at',case when e.value->>'key' like 'fair:%' then
  (select cf.ends_at from public.career_fairs cf where 'fair:'||cf.id::text=e.value->>'key'
   and public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school)) else null end)),'[]'::jsonb)
 into v_events from jsonb_array_elements(coalesce(v_report->'events','[]'::jsonb)) e;
 return v_report||jsonb_build_object('events',v_events);
end;$$;
revoke all on function public.university_fair_report_v2() from public,anon;
grant execute on function public.university_fair_report_v2() to authenticated;

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


notify pgrst, 'reload schema';
commit;
