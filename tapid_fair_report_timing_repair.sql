-- Optional timing wrapper repair. Requires the existing university_fair_report function.
begin;
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


notify pgrst, 'reload schema';
commit;
