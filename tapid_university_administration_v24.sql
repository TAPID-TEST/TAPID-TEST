-- Requires the existing university engagement analytics and card issuance schema.
-- Read-only functions: scoped by the verified university session, never caller-supplied school.
begin;
create or replace function public.university_admin_card_lookup(p_search text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_query text;v_result jsonb;
begin
 v_school:=public.current_university_school();
 if v_school is null then raise exception 'Verified university access required' using errcode='42501'; end if;
 v_query:=lower(trim(coalesce(p_search,'')));
 if v_query='' then return jsonb_build_object('rows','[]'::jsonb,'total',0); end if;
 with matched as (
  select s.* from public.tapid_university_student_rows(v_school) s
  where position(v_query in lower(s.student_name||' '||coalesce(s.username,'')))>0
 ), page_rows as (select * from matched order by student_name,user_id limit 20)
 select jsonb_build_object('total',(select count(*) from matched),'rows',coalesce(jsonb_agg(jsonb_build_object(
  'name',s.student_name,'username',s.username,'public_active',s.public_active,
  'cards',coalesce((select jsonb_agg(jsonb_build_object('card_serial',c.card_serial,'status',c.status,'issued_at',c.issued_at,'activated_at',c.activated_at) order by c.issued_at desc)
   from public.card_issuance c where c.student_user_id=s.user_id and public.tapid_school_key(c.school_name)=public.tapid_school_key(v_school)),'[]'::jsonb)
 ) order by s.student_name,s.user_id),'[]'::jsonb)) into v_result from page_rows s;
 return v_result;
end;$$;
revoke all on function public.university_admin_card_lookup(text) from public,anon;
grant execute on function public.university_admin_card_lookup(text) to authenticated;
create or replace function public.university_admin_card_activity()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_school text;v_result jsonb;
begin
 v_school:=public.current_university_school();
 if v_school is null then raise exception 'Verified university access required' using errcode='42501'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('student_name',r.student_name,'card_serial',r.card_serial,'status',r.status,'issued_at',r.issued_at,'activated_at',r.activated_at) order by r.issued_at desc,r.id desc),'[]'::jsonb)
 into v_result from (select c.id,c.card_serial,c.status,c.issued_at,c.activated_at,coalesce(s.student_name,'Student account') student_name
  from public.card_issuance c left join public.tapid_university_student_rows(v_school) s on s.user_id=c.student_user_id
  where public.tapid_school_key(c.school_name)=public.tapid_school_key(v_school) order by c.issued_at desc,c.id desc limit 50) r;
 return v_result;
end;$$;
revoke all on function public.university_admin_card_activity() from public,anon;
grant execute on function public.university_admin_card_activity() to authenticated;
-- Match recognized school aliases consistently with the lookup and auto-issued cards.
create or replace function public.issue_tapid_card(p_username text,p_card_serial text,p_notes text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_school text;v_student uuid;v_id bigint;
begin
 v_school:=public.current_university_school();
 if v_school is null then raise exception 'University administrator access required' using errcode='42501'; end if;
 if trim(coalesce(p_username,''))='' or trim(coalesce(p_card_serial,''))='' then raise exception 'Student username and unique card serial are required'; end if;
 select p.id into v_student from public.profiles p
 where lower(p.username)=lower(trim(p_username)) and public.tapid_school_key(p.school)=public.tapid_school_key(v_school);
 if v_student is null then raise exception 'No student at your university has that TapID username'; end if;
 insert into public.card_issuance(student_user_id,school_name,issued_by,card_serial,notes)
 values(v_student,v_school,auth.uid(),trim(p_card_serial),nullif(trim(coalesce(p_notes,'')),'')) returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.issue_tapid_card(text,text,text) from public,anon;
grant execute on function public.issue_tapid_card(text,text,text) to authenticated;
commit;
