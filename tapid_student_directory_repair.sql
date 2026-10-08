-- Run only if the six-parameter directory RPC is missing. Requires the previous engagement update.
begin;
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
notify pgrst, 'reload schema';
commit;
