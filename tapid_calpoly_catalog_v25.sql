-- Requires V21 major catalog and the university engagement program-college mapping.
-- Run this entire file in Supabase SQL Editor. Safe to rerun.
begin;
-- A single statement carries the verified catalog through all three writes.
-- No temporary table or previous SQL Editor session is required.
with verified(name,college_name) as (values
('Aerospace Engineering','College of Engineering'),
('Agricultural Business','College of Agriculture, Food and Environmental Sciences'),
('Agricultural Communication','College of Agriculture, Food and Environmental Sciences'),
('Agricultural Education','College of Agriculture, Food and Environmental Sciences'),
('Agricultural Science','College of Agriculture, Food and Environmental Sciences'),
('Agricultural Systems Management','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Animal Science','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in BioResource and Agricultural Systems','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Crop Science','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Dairy Products Technology','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Environmental Horticultural Science','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Irrigation','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Plant Protection Science','College of Agriculture, Food and Environmental Sciences'),
('Agriculture, Specialization in Water Engineering','College of Agriculture, Food and Environmental Sciences'),
('Animal Science','College of Agriculture, Food and Environmental Sciences'),
('Anthropology and Geography','College of Liberal Arts'),
('Architectural Engineering','College of Architecture and Environmental Design'),
('Architecture','College of Architecture and Environmental Design'),
('Art and Design','College of Liberal Arts'),
('Biochemistry','Bailey College of Science and Mathematics'),
('Biological Sciences','Bailey College of Science and Mathematics'),
('Biomedical Engineering','College of Engineering'),
('BioResource and Agricultural Engineering','College of Agriculture, Food and Environmental Sciences'),
('Business Administration','Orfalea College of Business'),
('Business Analytics','Orfalea College of Business'),
('Chemistry','Bailey College of Science and Mathematics'),
('Child Development','College of Liberal Arts'),
('City and Regional Planning','College of Architecture and Environmental Design'),
('City and Regional Planning and Civil Engineering','Interdisciplinary Degree Programs'),
('Civil and Environmental Engineering','College of Engineering'),
('Civil Engineering','College of Engineering'),
('Communication Studies','College of Liberal Arts'),
('Comparative Ethnic Studies','College of Liberal Arts'),
('Computer Engineering','College of Engineering'),
('Computer Science','College of Engineering'),
('Construction Management','College of Architecture and Environmental Design'),
('Curriculum and Instruction','Bailey College of Science and Mathematics'),
('Dairy Science','College of Agriculture, Food and Environmental Sciences'),
('Data Science','Bailey College of Science and Mathematics'),
('Economics','Orfalea College of Business'),
('Educational Leadership and Administration','Bailey College of Science and Mathematics'),
('Electrical Engineering','College of Engineering'),
('Engineering Management','College of Engineering'),
('English','College of Liberal Arts'),
('Environmental Earth and Soil Sciences','College of Agriculture, Food and Environmental Sciences'),
('Environmental Engineering','College of Engineering'),
('Environmental Management and Protection','College of Agriculture, Food and Environmental Sciences'),
('Environmental Sciences and Management','College of Agriculture, Food and Environmental Sciences'),
('Experience and Event Management','College of Agriculture, Food and Environmental Sciences'),
('Facilities Engineering Technology','College of Engineering'),
('Fire Protection Engineering','College of Engineering'),
('Food Science','College of Agriculture, Food and Environmental Sciences'),
('Forest and Fire Sciences','College of Agriculture, Food and Environmental Sciences'),
('General Engineering','College of Engineering'),
('Graphic Communication','College of Liberal Arts'),
('Higher Education Counseling and Student Affairs','Bailey College of Science and Mathematics'),
('History','College of Liberal Arts'),
('Industrial Engineering','College of Engineering'),
('Industrial Technology and Packaging','Orfalea College of Business'),
('Interdisciplinary Studies','College of Liberal Arts'),
('International Strategy and Security','College of Liberal Arts'),
('Journalism','College of Liberal Arts'),
('Kinesiology','Bailey College of Science and Mathematics'),
('Landscape Architecture','College of Architecture and Environmental Design'),
('Liberal Arts and Engineering Studies','Interdisciplinary Degree Programs'),
('Liberal Studies','Bailey College of Science and Mathematics'),
('Manufacturing Engineering','College of Engineering'),
('Marine Engineering Technology','College of Engineering'),
('Marine Sciences','Bailey College of Science and Mathematics'),
('Marine Transportation','College of Agriculture, Food and Environmental Sciences'),
('Materials Engineering','College of Engineering'),
('Mathematics','Bailey College of Science and Mathematics'),
('Mechanical Engineering','College of Engineering'),
('Microbiology','Bailey College of Science and Mathematics'),
('Music','College of Liberal Arts'),
('Nutrition','College of Agriculture, Food and Environmental Sciences'),
('Oceanography','Bailey College of Science and Mathematics'),
('Philosophy','College of Liberal Arts'),
('Physics','Bailey College of Science and Mathematics'),
('Plant Sciences','College of Agriculture, Food and Environmental Sciences'),
('Political Science','College of Liberal Arts'),
('Polymers and Coatings Science','Bailey College of Science and Mathematics'),
('Psychology','College of Liberal Arts'),
('Public Health','Bailey College of Science and Mathematics'),
('Public Policy','College of Liberal Arts'),
('Quantitative Economics','Orfalea College of Business'),
('Sociology','College of Liberal Arts'),
('Software Engineering','College of Engineering'),
('Spanish','College of Liberal Arts'),
('Special Education','Bailey College of Science and Mathematics'),
('Statistics','Bailey College of Science and Mathematics'),
('Theatre Arts','College of Liberal Arts'),
('Transportation and Engineering Management','College of Engineering'),
('Wine and Viticulture','College of Agriculture, Food and Environmental Sciences')
), catalog_insert as (
 insert into public.tapid_major_catalog(school_key,name)
 select public.tapid_school_key('Cal Poly'),name from verified
 on conflict(school_key,name) do nothing
 returning name
), college_upsert as (
 insert into public.tapid_program_colleges(school_key,major_key,college_name)
 select public.tapid_school_key('Cal Poly'),lower(regexp_replace(trim(name),'\s+',' ','g')),college_name from verified
 on conflict(school_key,major_key) do update set college_name=excluded.college_name
 returning major_key
)
delete from public.tapid_major_catalog
where school_key=public.tapid_school_key('Cal Poly')
and name not in(select name from verified);
-- Only current bachelor's/master's major labels appear as selectable majors.
-- Old profiles are preserved; no guessing or rewriting their self-reported majors.
create or replace function public.tapid_program_options(p_school text)
returns table(name text,college_name text) language sql stable security definer set search_path='' as $$
 select c.name,public.tapid_program_college(p_school,c.name)
 from public.tapid_major_catalog c where c.school_key=public.tapid_school_key(p_school) order by c.name;
$$;
revoke all on function public.tapid_program_options(text) from public;
grant execute on function public.tapid_program_options(text) to anon,authenticated;
commit;
