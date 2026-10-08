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


notify pgrst, 'reload schema';
commit;
