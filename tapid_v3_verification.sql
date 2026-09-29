-- TapID V3 read-only deployment verification
-- Run after tapid_v3_hardening_migration.sql.

select
  to_regclass('public.profiles') is not null as profiles,
  to_regclass('public.employer_recruiters') is not null as employer_recruiters,
  to_regclass('public.employer_connections') is not null as employer_connections,
  to_regclass('public.employer_connection_requests') is not null as connection_requests,
  to_regclass('public.university_admins') is not null as university_admins,
  to_regclass('public.career_fairs') is not null as career_fairs,
  to_regclass('public.career_fair_employers') is not null as career_fair_employers,
  to_regclass('public.card_issuance') is not null as card_issuance;

select
  to_regprocedure('public.register_employer(text,text,text)') is not null as register_employer,
  to_regprocedure('public.connect_employer_to_student(uuid)') is not null as direct_connect,
  to_regprocedure('public.request_employer_connection(bigint,text,text)') is not null as request_connection,
  to_regprocedure('public.respond_employer_connection_request(bigint,boolean)') is not null as respond_to_request,
  to_regprocedure('public.university_request_engagement()') is not null as request_analytics,
  to_regprocedure('public.university_overview()') is not null as university_overview;

select
  grantee,
  table_name,
  privilege_type,
  string_agg(column_name, ', ' order by column_name) as allowed_columns
from information_schema.column_privileges
where table_schema = 'public'
  and grantee = 'authenticated'
  and table_name in ('employer_recruiters', 'employer_connections')
  and privilege_type = 'UPDATE'
group by grantee, table_name, privilege_type
order by table_name;

select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'employer_recruiters',
    'employer_connections',
    'employer_connection_requests',
    'university_admins',
    'career_fairs',
    'career_fair_employers'
  )
order by tablename, policyname;
