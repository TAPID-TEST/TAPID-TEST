-- TapID: canonical fair acceptance and useful university engagement analytics.
-- Run after the Candidate Match SQL update. No accounts are removed.
begin;
create or replace function public.respond_employer_connection_request(
  p_request_id bigint,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employer_connection_requests;
  v_recruiter public.employer_recruiters;
  v_company public.companies;
  v_student public.profiles;
  v_connection_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_recruiter
  from public.employer_recruiters
  where user_id = auth.uid()
    and verification_status = 'verified';

  if not found then
    raise exception 'Verified employer account required';
  end if;

  select * into v_request
  from public.employer_connection_requests
  where id = p_request_id
    and company_id = v_recruiter.company_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'This request has already been reviewed';
  end if;

  -- Declining a request remains possible after a fair roster changes.
  if p_accept is not true then
    update public.employer_connection_requests
    set status='declined', responded_by=auth.uid(), responded_at=now()
    where id=p_request_id;
    return 'declined';
  end if;

  -- Use the same canonical roster as fair listings and request creation.
  -- Past published fairs remain valid: follow-up often happens after the fair.
  if v_request.career_fair_id is null or not exists (
    select 1 from public.career_fairs cf
    join public.tapid_fair_roster() roster on roster.career_fair_id=cf.id
      and roster.company_id=v_recruiter.company_id
    join public.profiles p on p.id=v_request.student_user_id
    where cf.id=v_request.career_fair_id and cf.is_published
      and public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_recruiter.requested_school)
      and public.tapid_school_key(p.school)=public.tapid_school_key(cf.school_name)
  ) then
    raise exception 'Your company must be listed for this published career fair. Ask the university to check its employer roster.';
  end if;

  select * into v_company
  from public.companies
  where id = v_recruiter.company_id;

  select * into v_student
  from public.profiles
  where id = v_request.student_user_id;

  if not found
     or v_student.profile_active is not true
     or v_student.card_activated is not true then
    raise exception 'Student profile is unavailable';
  end if;

  select ec.id into v_connection_id
  from public.employer_connections ec
  where ec.company_id = v_recruiter.company_id
    and ec.recruiter_user_id = auth.uid()
    and ec.student_user_id = v_request.student_user_id
    and (ec.career_fair_id = v_request.career_fair_id or (ec.career_fair_id is null and coalesce(lower(ec.event_name), '') = coalesce(lower(v_request.event_name), '')))
  limit 1;

  if v_connection_id is null then
    insert into public.employer_connections (
      company_id,
      recruiter_user_id,
      student_user_id,
      event_name,
      career_fair_id
    ) values (
      v_recruiter.company_id,
      auth.uid(),
      v_request.student_user_id,
      v_request.event_name,
      v_request.career_fair_id
    )
    returning id into v_connection_id;
  else
    update public.employer_connections
    set career_fair_id = coalesce(career_fair_id, v_request.career_fair_id),
        updated_at = now()
    where id = v_connection_id;
  end if;

  if not exists (
    select 1
    from public.connections c
    where c.profile_owner_id = v_request.student_user_id
      and lower(coalesce(c.email, '')) = lower(v_recruiter.recruiter_email)
      and lower(coalesce(c.company, '')) = lower(v_company.name)
      and lower(coalesce(c.where_met, '')) = lower(v_request.event_name)
  ) then
    insert into public.connections (
      profile_owner_id,
      visitor_name,
      company,
      email,
      where_met,
      message,
      private_notes
    ) values (
      v_request.student_user_id,
      v_recruiter.recruiter_name,
      v_company.name,
      v_recruiter.recruiter_email,
      v_request.event_name,
      'Accepted your TapID connection request.',
      null
    );
  end if;

  update public.employer_connection_requests
  set status = 'accepted',
      responded_by = auth.uid(),
      responded_at = now()
  where id = p_request_id;

  return 'accepted';
end;
$$;

revoke all on function public.respond_employer_connection_request(bigint,boolean) from public;
grant execute on function public.respond_employer_connection_request(bigint,boolean) to authenticated;

-- Explicit program-to-college mapping. Unrecognized/free-text majors are never guessed.
create table if not exists public.tapid_program_colleges (
  school_key text not null, major_key text not null, college_name text not null,
  primary key(school_key,major_key)
);
alter table public.tapid_program_colleges enable row level security;
revoke all on public.tapid_program_colleges from public,anon,authenticated;
insert into public.tapid_program_colleges(school_key,major_key,college_name)
select 'cal poly',program.major,
 case program.college
 when 'engineering' then 'College of Engineering'
 when 'architecture' then 'College of Architecture and Environmental Design'
 when 'business' then 'Orfalea College of Business'
 when 'science' then 'Bailey College of Science and Mathematics'
 when 'agriculture' then 'College of Agriculture, Food and Environmental Sciences'
 when 'arts' then 'College of Liberal Arts' end
from (values
 ('civil engineering','engineering'),('mechanical engineering','engineering'),
 ('environmental engineering','engineering'),('electrical engineering','engineering'),
 ('aerospace engineering','engineering'),('biomedical engineering','engineering'),
 ('computer engineering','engineering'),('computer science','engineering'),
 ('software engineering','engineering'),('industrial engineering','engineering'),
 ('manufacturing engineering','engineering'),('materials engineering','engineering'),
 ('general engineering','engineering'),
 ('architecture','architecture'),('architectural engineering','architecture'),
 ('construction management','architecture'),('landscape architecture','architecture'),
 ('city and regional planning','architecture'),
 ('business administration','business'),('economics','business'),
 ('industrial technology and packaging','business'),
 ('biological sciences','science'),('biochemistry','science'),('chemistry','science'),
 ('kinesiology','science'),('public health','science'),('liberal studies','science'),
 ('mathematics','science'),('physics','science'),('statistics','science'),
 ('microbiology','science'),('marine sciences','science'),
 ('agricultural business','agriculture'),('agricultural communication','agriculture'),
 ('agricultural science','agriculture'),('agricultural systems management','agriculture'),
 ('animal science','agriculture'),('bioresource and agricultural engineering','agriculture'),
 ('dairy science','agriculture'),('environmental earth and soil sciences','agriculture'),
 ('environmental management and protection','agriculture'),('food science','agriculture'),
 ('forest and fire sciences','agriculture'),('nutrition','agriculture'),
 ('plant sciences','agriculture'),('wine and viticulture','agriculture'),
 ('art and design','arts'),('communication studies','arts'),('english','arts'),
 ('graphic communication','arts'),('history','arts'),('journalism','arts'),
 ('music','arts'),('philosophy','arts'),('political science','arts'),
 ('psychology','arts'),('child development','arts'),('sociology','arts'),
 ('spanish','arts'),('theatre arts','arts'),('comparative ethnic studies','arts'),
 ('anthropology and geography','arts')
) as program(major,college)
on conflict(school_key,major_key) do nothing;

create or replace function public.tapid_program_college(p_school text,p_major text)
returns text language sql stable security definer set search_path='' as $$
 select coalesce((select m.college_name from public.tapid_program_colleges m
 where m.school_key=public.tapid_school_key(p_school)
 and m.major_key=lower(regexp_replace(trim(p_major),'\s+',' ','g'))),'Unclassified major');
$$;
revoke all on function public.tapid_program_college(text,text) from public,anon,authenticated;

-- A connection counts once per student, company and fair/source, across recruiters.
-- The first recorded time is retained so repeated taps do not inflate monthly totals.
create or replace function public.tapid_university_connection_rows(p_school text)
returns table(student_user_id uuid,company_id bigint,source_key text,connected_at timestamptz)
language sql stable security definer set search_path='' as $$
 select ec.student_user_id,ec.company_id,
 coalesce('fair:'||ec.career_fair_id::text,
   'source:'||coalesce(nullif(lower(trim(ec.event_name)),''),'direct connection')),
 min(ec.connected_at)
 from public.employer_connections ec
 join public.tapid_university_student_rows(p_school) s on s.user_id=ec.student_user_id
 group by ec.student_user_id,ec.company_id,
 coalesce('fair:'||ec.career_fair_id::text,
   'source:'||coalesce(nullif(lower(trim(ec.event_name)),''),'direct connection'));
$$;
revoke all on function public.tapid_university_connection_rows(text) from public,anon,authenticated;

create or replace function public.university_engagement_report()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare school text; base jsonb; student_metrics jsonb; groups jsonb; growth jsonb; companies jsonb;
begin
 school:=public.current_university_school();
 if school is null then raise exception 'Verified university access required' using errcode='42501'; end if;
 base:=public.university_population_report();
 select jsonb_build_object(
  'connections',(select count(*) from public.tapid_university_connection_rows(school)),
  'students_connected_30_days',(select count(distinct r.student_user_id)
    from public.tapid_university_connection_rows(school) r where r.connected_at>=now()-interval '30 days'),
  'connections_30_days',(select count(*) from public.tapid_university_connection_rows(school) r
    where r.connected_at>=now()-interval '30 days'),
  'employers_reached',(select count(distinct r.company_id) from public.tapid_university_connection_rows(school) r),
  'approved_employers_students',(select count(distinct r.student_user_id) from public.tapid_university_connection_rows(school) r
    where exists(select 1 from public.employer_recruiters er where er.company_id=r.company_id and er.verification_status='verified'
      and public.tapid_school_key(er.requested_school)=public.tapid_school_key(school)))
 ) into student_metrics;
 with connection_rows as materialized (select * from public.tapid_university_connection_rows(school)),
 student_activity as (
  select s.user_id,s.major,s.class_year,
   public.tapid_program_college(school,s.major) as college,count(r.student_user_id) as volume
  from public.tapid_university_student_rows(school) s
  left join connection_rows r on r.student_user_id=s.user_id
  group by s.user_id,s.major,s.class_year
 )
 select coalesce(jsonb_agg(jsonb_build_object(
  'major',g.major,'year',g.class_year,'college',g.college,
  'accounts',g.accounts,'connected',g.connected,'connections',g.connections
 ) order by g.college,g.major,g.class_year),'[]'::jsonb) into groups
 from (select a.major,a.class_year,a.college,count(*) as accounts,
   count(*) filter(where a.volume>0) as connected,sum(a.volume) as connections
   from student_activity a group by a.major,a.class_year,a.college) g;
 select coalesce(jsonb_agg(jsonb_build_object(
   'month',g.month_label,'connections',g.connections,'students',g.students,'employers',g.employers
 ) order by g.month_label),'[]'::jsonb) into growth from (
  select to_char(months.month_start,'YYYY-MM') as month_label,
   count(r.student_user_id) as connections,
   count(distinct r.student_user_id) as students,
   count(distinct r.company_id) filter(where exists(select 1 from public.employer_recruiters er
    where er.company_id=r.company_id and er.verification_status='verified'
    and public.tapid_school_key(er.requested_school)=public.tapid_school_key(school))) as employers
  from generate_series(
   date_trunc('month',now() at time zone 'America/Los_Angeles')-interval '11 months',
   date_trunc('month',now() at time zone 'America/Los_Angeles'),interval '1 month'
  ) as months(month_start)
  left join public.tapid_university_connection_rows(school) r
   on date_trunc('month',r.connected_at at time zone 'America/Los_Angeles')=months.month_start
  group by months.month_start
 ) g;
 with connection_rows as materialized (select * from public.tapid_university_connection_rows(school)),
 student_rows as materialized (select * from public.tapid_university_student_rows(school))
 select coalesce(jsonb_agg(e.doc||jsonb_build_object(
   'connections',a.connections,'students',a.students,'events',a.events,
   'connections_30_days',a.recent_connections,'students_30_days',a.recent_students,
   'last_connection_at',a.last_at,
   'majors',coalesce((select jsonb_agg(jsonb_build_object('label',m.major,'connections',m.volume) order by m.volume desc,m.major)
      from (select s.major,count(*) as volume from connection_rows r
       join student_rows s on s.user_id=r.student_user_id
       where r.company_id=(e.doc->>'company_id')::bigint group by s.major) m),'[]'::jsonb)
 ) order by a.connections desc,e.doc->>'name'),'[]'::jsonb) into companies
 from jsonb_array_elements(base->'employers') as e(doc)
 left join lateral (
  select count(*) as connections,count(distinct r.student_user_id) as students,
   count(distinct r.source_key) filter(where r.source_key like 'fair:%') as events,
   count(*) filter(where r.connected_at>=now()-interval '30 days') as recent_connections,
   count(distinct r.student_user_id) filter(where r.connected_at>=now()-interval '30 days') as recent_students,
   max(r.connected_at) as last_at
  from connection_rows r where r.company_id=(e.doc->>'company_id')::bigint
 ) a on true;
 return base||jsonb_build_object('students',(base->'students')||student_metrics,
  'engagement_groups',groups,'connection_growth',growth,'employers',companies,'engagement_version',1);
end;$$;
revoke all on function public.university_engagement_report() from public,anon;
grant execute on function public.university_engagement_report() to authenticated;
create or replace function public.university_student_directory(
  p_search text default '',p_major text default '',p_year text default '',p_state text default '',p_page integer default 0
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
revoke all on function public.university_student_directory(text,text,text,text,integer) from public,anon;
grant execute on function public.university_student_directory(text,text,text,text,integer) to authenticated;

notify pgrst,'reload schema';
commit;
