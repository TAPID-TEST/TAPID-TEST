begin;

alter table public.integration_events
  add column if not exists career_fair_id bigint references public.career_fairs(id) on delete set null;
create unique index if not exists tapid_managed_fair_reference
  on public.integration_events(career_fair_id) where career_fair_id is not null;

-- Connect older imports only when both the event and fair match uniquely.
with candidates as (
  select ie.id as event_id,cf.id as fair_id,
    count(*) over(partition by ie.id) as fairs_for_event,
    count(*) over(partition by cf.id) as events_for_fair
  from public.integration_events ie join public.career_fairs cf
    on public.tapid_school_key(ie.school_name)=public.tapid_school_key(cf.school_name)
    and lower(trim(ie.event_name))=lower(trim(cf.name))
    and ie.starts_at is not distinct from cf.starts_at
  where ie.career_fair_id is null
    and not exists(select 1 from public.integration_events linked where linked.career_fair_id=cf.id)
)
update public.integration_events ie set career_fair_id=c.fair_id
from candidates c where ie.id=c.event_id and c.fairs_for_event=1 and c.events_for_fair=1;

create or replace function public.university_fair_setup_list()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text; v_fairs jsonb; v_companies jsonb;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',cf.id,'name',cf.name,'location',cf.location,'description',cf.description,
    'start_local',to_char(cf.starts_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
    'end_local',to_char(cf.ends_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
    'published',cf.is_published,
    'companies',coalesce((select jsonb_agg(jsonb_build_object('name',iee.company_name,'external_id',iee.external_employer_id,'company_id',iee.company_id) order by iee.company_name)
      from public.integration_events ie join public.integration_event_employers iee on iee.integration_event_id=ie.id
      where ie.career_fair_id=cf.id),'[]'::jsonb)
  ) order by cf.starts_at desc nulls last,cf.name),'[]'::jsonb) into v_fairs
  from public.career_fairs cf where public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school);
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name) order by c.name),'[]'::jsonb)
    into v_companies from public.companies c;
  return jsonb_build_object('fairs',v_fairs,'companies',v_companies);
end;$$;
revoke all on function public.university_fair_setup_list() from public,anon;
grant execute on function public.university_fair_setup_list() to authenticated;

create or replace function public.university_save_fair_setup(
  p_fair_id bigint,p_name text,p_start_local text,p_end_local text,p_location text,
  p_description text,p_published boolean,p_companies jsonb
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_school text; v_fair_id bigint; v_event_id bigint; v_start timestamptz; v_end timestamptz;
  v_row jsonb; v_name text; v_company_id bigint; v_matches bigint; v_old_name text;
  v_saved integer := 0; v_matched integer := 0;
begin
  v_school := public.current_university_school();
  if v_school is null then raise exception 'Verified university access required'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'Enter a career fair name'; end if;
  if length(trim(p_name))>160 then raise exception 'Fair name must be 160 characters or fewer'; end if;
  if jsonb_typeof(p_companies) is distinct from 'array' then raise exception 'Company list must be an array'; end if;
  if jsonb_array_length(p_companies)>2000 then raise exception 'Import up to 2,000 companies at a time'; end if;
  v_start := nullif(p_start_local,'')::timestamp at time zone 'America/Los_Angeles';
  v_end := nullif(p_end_local,'')::timestamp at time zone 'America/Los_Angeles';
  if v_end is not null and (v_start is null or v_end<v_start) then raise exception 'End time must follow the start time'; end if;
  -- Serialize saves for this school's fair name, including simultaneous new submissions.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_school||lower(trim(p_name)),0));
  if p_fair_id is not null then
    select cf.name into v_old_name from public.career_fairs cf
      where cf.id=p_fair_id and public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school) for update;
    if not found then raise exception 'Career fair is unavailable for this university'; end if;
    if v_old_name<>trim(p_name) and exists(select 1 from public.employer_connections ec
      join public.profiles p on p.id=ec.student_user_id
      where public.tapid_school_key(p.school)=public.tapid_school_key(v_school)
        and ec.career_fair_id is null and lower(trim(ec.event_name))=lower(trim(v_old_name))) then
      raise exception 'This fair has older connections linked by name. Keep its existing name.';
    end if;
    v_fair_id := p_fair_id;
  else
    if exists(select 1 from public.career_fairs cf
      where public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school)
        and lower(trim(cf.name))=lower(trim(p_name)) and cf.starts_at is not distinct from v_start) then
      raise exception 'This fair already exists. Open it from the fair list to update it.';
    end if;
    insert into public.career_fairs(school_name,name,starts_at,ends_at,location,description,is_published,created_by)
      values(v_school,trim(p_name),v_start,v_end,nullif(trim(p_location),''),nullif(trim(p_description),''),false,auth.uid())
      returning id into v_fair_id;
  end if;
  update public.career_fairs set name=trim(p_name),starts_at=v_start,ends_at=v_end,
    location=nullif(trim(p_location),''),description=nullif(trim(p_description),''),
    is_published=coalesce(p_published,false),updated_at=now() where id=v_fair_id;
  -- A stable reference ties all imported rows to the same fair.
  select ie.id into v_event_id from public.integration_events ie where ie.career_fair_id=v_fair_id;
  if v_event_id is not null then
    update public.integration_events set event_name=trim(p_name),starts_at=v_start,
      location=nullif(trim(p_location),''),imported_at=now() where id=v_event_id;
  else
  insert into public.integration_events(school_name,source_system,external_event_id,event_name,starts_at,location,imported_by,career_fair_id)
    values(v_school,'manual','tapid-fair-'||v_fair_id::text,trim(p_name),v_start,nullif(trim(p_location),''),auth.uid(),v_fair_id)
    on conflict(school_name,source_system,external_event_id) do update
      set event_name=excluded.event_name,starts_at=excluded.starts_at,location=excluded.location,imported_at=now(),career_fair_id=excluded.career_fair_id
    returning id into v_event_id;
  end if;
  for v_row in select value from jsonb_array_elements(p_companies) loop
    v_name := trim(v_row->>'name');
    if nullif(v_name,'') is null or length(v_name)>200 then raise exception 'Each company needs a name of 1–200 characters'; end if;
    v_company_id := null;
    if nullif(v_row->>'company_id','') is not null then
      select c.id into v_company_id from public.companies c where c.id=(v_row->>'company_id')::bigint;
      if v_company_id is null then raise exception 'Selected TapID company no longer exists'; end if;
    else
      select count(*),min(c.id) into v_matches,v_company_id from public.companies c where lower(trim(c.name))=lower(v_name);
      if v_matches<>1 then v_company_id:=null; end if;
    end if;
    -- Case-insensitive deduplication; retain an existing manual match on retry.
    update public.integration_event_employers set
      company_id=coalesce(v_company_id,company_id),
      external_employer_id=coalesce(nullif(trim(v_row->>'external_id'),''),external_employer_id),imported_at=now()
      where integration_event_id=v_event_id and lower(trim(company_name))=lower(v_name);
    if not found then
      insert into public.integration_event_employers(integration_event_id,company_name,company_id,external_employer_id)
        values(v_event_id,v_name,v_company_id,nullif(trim(v_row->>'external_id'),''));
    end if;
    v_saved:=v_saved+1;
    if v_company_id is not null then v_matched:=v_matched+1; end if;
  end loop;
  return jsonb_build_object('fair_id',v_fair_id,'companies_saved',v_saved,'companies_matched',v_matched,'published',coalesce(p_published,false));
end;$$;
revoke all on function public.university_save_fair_setup(bigint,text,text,text,text,text,boolean,jsonb) from public,anon;
grant execute on function public.university_save_fair_setup(bigint,text,text,text,text,text,boolean,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
