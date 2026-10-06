-- Run after tapid_university_upgrade.sql (already installed).
-- Adds university population reporting; does not create/delete accounts.
begin;

create index if not exists tapid_connection_student_idx on public.employer_connections(student_user_id);
create index if not exists tapid_connection_company_idx on public.employer_connections(company_id);

-- Internal helper: never callable by an application user.
create or replace function public.tapid_university_student_rows(p_school text)
returns table(
  user_id uuid, student_name text, username text, joined_at timestamptz,
  major text, class_year text, email_confirmed boolean, has_profile boolean,
  basics_complete boolean, card_assigned boolean, public_active boolean,
  connections bigint, last_connection_at timestamptz
)
language sql stable security definer set search_path='' as $$
  select u.id,
    coalesce(nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''),
      nullif(trim(concat_ws(' ',u.raw_user_meta_data->>'first_name',u.raw_user_meta_data->>'last_name)),''),'Name not set'),
    p.username,u.created_at,coalesce(nullif(trim(p.major),''),'Not set'),
    coalesce(nullif(trim(p.school_year),''),'Not set'),u.email_confirmed_at is not null,
    p.id is not null,
    (nullif(trim(p.username),'') is not null and nullif(trim(p.major),'') is not null and nullif(trim(p.school_year),'') is not null),
    exists(select 1 from public.card_issuance ci where ci.student_user_id=u.id and ci.status in ('issued','activated')),
    coalesce(p.profile_active and p.card_activated and u.email_confirmed_at is not null,false),
    (select count(distinct(ec.company_id,coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection'))))))
      from public.employer_connections ec where ec.student_user_id=u.id),
    (select max(ec.connected_at) from public.employer_connections ec where ec.student_user_id=u.id)
  from auth.users u left join public.profiles p on p.id=u.id
  where (public.tapid_school_key(p.school)=public.tapid_school_key(p_school)
    or (public.tapid_school_key(p_school)='cal poly' and lower(split_part(u.email,'@',2))='calpoly.edu'))
    and coalesce(u.raw_user_meta_data->>'user_type','student') not in ('employer','university')
    and not exists(select 1 from public.university_admins ua where ua.user_id=u.id)
    and not exists(select 1 from public.employer_recruiters er where er.user_id=u.id);
$$;
revoke all on function public.tapid_university_student_rows(text) from public,anon,authenticated;

create or replace function public.university_population_report()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_students jsonb;v_majors jsonb;v_years jsonb;v_growth jsonb;v_employers jsonb;
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  select jsonb_build_object(
    'accounts',count(*),'email_confirmed',count(*) filter(where s.email_confirmed),
    'profiles_started',count(*) filter(where s.has_profile),'basics_complete',count(*) filter(where s.basics_complete),
    'cards_assigned',count(*) filter(where s.card_assigned),'public_active',count(*) filter(where s.public_active),
    'students_connected',count(*) filter(where s.connections>0),
    'new_30_days',count(*) filter(where s.joined_at>=now()-interval '30 days'),
    'unconfirmed',count(*) filter(where not s.email_confirmed),
    'setup_needed',count(*) filter(where s.email_confirmed and not s.public_active and not s.basics_complete),
    'ready_to_activate',count(*) filter(where s.email_confirmed and s.basics_complete and not s.public_active),
    'active_without_connections',count(*) filter(where s.public_active and s.connections=0)
  ) into v_students from public.tapid_university_student_rows(v_school) s;
  select coalesce(jsonb_agg(jsonb_build_object('label',major,'accounts',accounts,'active',active,'connected',connected) order by accounts desc,major),'[]'::jsonb)
    into v_majors from (select s.major,count(*) accounts,count(*) filter(where s.public_active) active,
      count(*) filter(where s.connections>0) connected from public.tapid_university_student_rows(v_school) s group by s.major) grouped;
  select coalesce(jsonb_agg(jsonb_build_object('label',class_year,'accounts',accounts,'active',active,'connected',connected) order by accounts desc,class_year),'[]'::jsonb)
    into v_years from (select s.class_year,count(*) accounts,count(*) filter(where s.public_active) active,
      count(*) filter(where s.connections>0) connected from public.tapid_university_student_rows(v_school) s group by s.class_year) grouped;
  select coalesce(jsonb_agg(jsonb_build_object('month',month,'accounts',accounts) order by month),'[]'::jsonb)
    into v_growth from (
      select to_char(months.month_start,'YYYY-MM') month,count(s.user_id) accounts
      from generate_series(date_trunc('month',now() at time zone 'America/Los_Angeles')-interval '11 months',
        date_trunc('month',now() at time zone 'America/Los_Angeles'),interval '1 month') as months(month_start)
      left join public.tapid_university_student_rows(v_school) s
        on date_trunc('month',s.joined_at at time zone 'America/Los_Angeles')=months.month_start group by months.month_start
    ) grouped;
  with companies as (
    select er.company_id,count(*) recruiters,
      count(*) filter(where er.verification_status='verified') approved,
      count(*) filter(where er.verification_status='pending') pending,
      count(*) filter(where er.verification_status='rejected') declined,
      min(er.created_at) joined_at
    from public.employer_recruiters er
    where public.tapid_school_key(er.requested_school)=public.tapid_school_key(v_school)
    group by er.company_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'company_id',c.id,'name',c.name,'recruiters',registered.recruiters,'approved_recruiters',registered.approved,
    'pending_recruiters',registered.pending,'declined_recruiters',registered.declined,'joined_at',registered.joined_at,
    'status',case when registered.approved>0 then 'approved' when registered.pending>0 then 'pending' else 'declined' end,
    'students',activity.students,'connections',activity.connections,'events',activity.events,'last_connection_at',activity.last_at
  ) order by activity.connections desc,c.name),'[]'::jsonb) into v_employers
  from companies registered join public.companies c on c.id=registered.company_id
  left join lateral (
    select count(distinct ec.student_user_id) students,
      count(distinct(ec.student_user_id,coalesce('fair:'||ec.career_fair_id::text,lower(trim(coalesce(ec.event_name,'Direct connection')))))) connections,
      count(distinct coalesce('fair:'||ec.career_fair_id::text,lower(trim(ec.event_name)))) events,max(ec.connected_at) last_at
    from public.employer_connections ec join public.profiles p on p.id=ec.student_user_id
    where ec.company_id=c.id and public.tapid_school_key(p.school)=public.tapid_school_key(v_school)
  ) activity on true;
  return jsonb_build_object('school',v_school,'students',v_students,'majors',v_majors,'years',v_years,
    'account_growth',v_growth,'employers',v_employers,'generated_at',now());
end;$$;
revoke all on function public.university_population_report() from public,anon;
grant execute on function public.university_population_report() to authenticated;

create or replace function public.university_student_directory(
  p_search text default '',p_major text default '',p_year text default '',p_state text default '',p_page integer default 0
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_rows jsonb;v_total bigint;v_page integer:=greatest(0,coalesce(p_page,0));
begin
  v_school:=public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  if coalesce(p_state,'') not in ('','unconfirmed','setup','ready','active','connected','no-connections') then raise exception 'Invalid student filter'; end if;
  with matched as (
    select s.* from public.tapid_university_student_rows(v_school) s
    where (coalesce(p_search,'')='' or position(lower(trim(p_search)) in lower(s.student_name||' '||coalesce(s.username,'')))>0)
      and (coalesce(p_major,'')='' or s.major=p_major) and (coalesce(p_year,'')='' or s.class_year=p_year)
      and (coalesce(p_state,'')='' or
        (p_state='unconfirmed' and not s.email_confirmed) or
        (p_state='setup' and s.email_confirmed and not s.public_active and not s.basics_complete) or
        (p_state='ready' and s.email_confirmed and s.basics_complete and not s.public_active) or
        (p_state='active' and s.public_active) or (p_state='connected' and s.connections>0) or
        (p_state='no-connections' and s.public_active and s.connections=0))
  ),page_rows as (select * from matched order by joined_at desc,user_id limit 50 offset v_page*50)
  select (select count(*) from matched),coalesce(jsonb_agg(jsonb_build_object(
    'name',s.student_name,'username',case when s.public_active then s.username else null end,
    'joined_at',s.joined_at,'major',s.major,'class_year',s.class_year,
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
