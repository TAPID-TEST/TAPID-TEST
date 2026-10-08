-- Read-only installation check. Run in Supabase SQL Editor AFTER the update.
-- Every installed column should read true. This does not test signed-in access.
select 'Full public profile search' as component,
 to_regprocedure('public.employer_search_documents()') is not null as installed
union all select 'College directory filter',
 to_regprocedure('public.university_student_directory_filtered(text,text,text,text,integer,text)') is not null
union all select 'Career fair report with end times',
 to_regprocedure('public.university_fair_report_v2()') is not null
union all select 'Automatic contacted stage',
 exists(select 1 from pg_trigger t where t.tgrelid='public.connection_messages'::regclass
 and t.tgname='tapid_message_marks_contacted' and not t.tgisinternal)
union all select 'Narrative career interests',
 exists(select 1 from information_schema.columns where table_schema='public'
 and table_name='student_opportunity_preferences' and column_name='career_goal_statement');

-- Verify the intended API permissions without changing approvals.
select has_function_privilege('authenticated',
 'public.university_student_directory_filtered(text,text,text,text,integer,text)','execute') as university_directory_allowed,
 has_function_privilege('authenticated','public.university_fair_report_v2()','execute') as fair_report_allowed,
 has_function_privilege('authenticated','public.employer_search_documents()','execute') as employer_search_allowed,
 not has_function_privilege('anon','public.employer_search_documents()','execute') as anonymous_search_blocked;
