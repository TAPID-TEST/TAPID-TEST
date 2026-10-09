-- Run after the existing TapID university SQL. Catalog based on Cal Poly 2026–28 programs.
begin;
create table if not exists public.tapid_major_catalog(school_key text not null, name text not null, primary key(school_key,name));
alter table public.tapid_major_catalog enable row level security;
revoke all on public.tapid_major_catalog from public,anon,authenticated;
insert into public.tapid_major_catalog values
('cal poly','Aerospace Engineering'),
('cal poly','Agricultural Business'),
('cal poly','Agricultural Communication'),
('cal poly','Agricultural Science'),
('cal poly','Agricultural Systems Management'),
('cal poly','Animal Science'),
('cal poly','Anthropology and Geography'),
('cal poly','Architectural Engineering'),
('cal poly','Architecture'),
('cal poly','Art and Design'),
('cal poly','BioResource and Agricultural Engineering'),
('cal poly','Biochemistry'),
('cal poly','Biological Sciences'),
('cal poly','Biomedical Engineering'),
('cal poly','Business Administration'),
('cal poly','Chemistry'),
('cal poly','Child Development'),
('cal poly','City and Regional Planning'),
('cal poly','Civil Engineering'),
('cal poly','Communication Studies'),
('cal poly','Comparative Ethnic Studies'),
('cal poly','Computer Engineering'),
('cal poly','Computer Science'),
('cal poly','Construction Management'),
('cal poly','Dairy Science'),
('cal poly','Data Science'),
('cal poly','Economics'),
('cal poly','Electrical Engineering'),
('cal poly','English'),
('cal poly','Environmental Earth and Soil Sciences'),
('cal poly','Environmental Engineering'),
('cal poly','Environmental Management and Protection'),
('cal poly','Experience and Event Management'),
('cal poly','Facilities Engineering Technology'),
('cal poly','Food Science'),
('cal poly','Forest and Fire Sciences'),
('cal poly','General Engineering'),
('cal poly','Graphic Communication'),
('cal poly','History'),
('cal poly','Industrial Engineering'),
('cal poly','Industrial Technology and Packaging'),
('cal poly','Interdisciplinary Studies'),
('cal poly','International Strategy and Security'),
('cal poly','Journalism'),
('cal poly','Kinesiology'),
('cal poly','Landscape Architecture'),
('cal poly','Liberal Arts and Engineering Studies'),
('cal poly','Liberal Studies'),
('cal poly','Manufacturing Engineering'),
('cal poly','Marine Engineering Technology'),
('cal poly','Marine Sciences'),
('cal poly','Marine Transportation'),
('cal poly','Materials Engineering'),
('cal poly','Mathematics'),
('cal poly','Mechanical Engineering'),
('cal poly','Microbiology'),
('cal poly','Music'),
('cal poly','Nutrition'),
('cal poly','Oceanography'),
('cal poly','Philosophy'),
('cal poly','Physics'),
('cal poly','Plant Sciences'),
('cal poly','Political Science'),
('cal poly','Psychology'),
('cal poly','Public Health'),
('cal poly','Sociology'),
('cal poly','Software Engineering'),
('cal poly','Spanish'),
('cal poly','Statistics'),
('cal poly','Theatre Arts'),
('cal poly','Wine and Viticulture') on conflict do nothing;
insert into public.tapid_major_catalog values
('cal poly','Agricultural Education'),
('cal poly','Agriculture, Specialization in Animal Science'),
('cal poly','Agriculture, Specialization in BioResource and Agricultural Systems'),
('cal poly','Agriculture, Specialization in Crop Science'),
('cal poly','Agriculture, Specialization in Dairy Products Technology'),
('cal poly','Agriculture, Specialization in Environmental Horticultural Science'),
('cal poly','Agriculture, Specialization in Irrigation'),
('cal poly','Agriculture, Specialization in Plant Protection Science'),
('cal poly','Agriculture, Specialization in Water Engineering'),
('cal poly','Business Analytics'),
('cal poly','Civil and Environmental Engineering'),
('cal poly','City and Regional Planning and Civil Engineering'),
('cal poly','Curriculum and Instruction'),
('cal poly','Educational Leadership and Administration'),
('cal poly','Engineering Management'),
('cal poly','Environmental Sciences and Management'),
('cal poly','Fire Protection Engineering'),
('cal poly','Higher Education Counseling and Student Affairs'),
('cal poly','Polymers and Coatings Science'),
('cal poly','Public Policy'),
('cal poly','Quantitative Economics'),
('cal poly','Special Education'),
('cal poly','Transportation and Engineering Management') on conflict do nothing;
create or replace function public.tapid_major_options(p_school text)
returns table(name text) language sql stable security definer set search_path='' as $$
select c.name from public.tapid_major_catalog c where c.school_key=public.tapid_school_key(p_school) order by c.name;
$$;
revoke all on function public.tapid_major_options(text) from public,anon;
grant execute on function public.tapid_major_options(text) to authenticated;
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
on conflict(school_key,major_key) do update set college_name=excluded.college_name;


-- Normalize only exact case/whitespace matches; do not guess abbreviations.
update public.profiles p set major=c.name from public.tapid_major_catalog c
where c.school_key=public.tapid_school_key(p.school) and lower(trim(p.major))=lower(c.name) and p.major is distinct from c.name;
create or replace function public.tapid_validate_major()
returns trigger language plpgsql security definer set search_path='' as $$
declare canonical text;
begin
 if tg_op='UPDATE' and new.major is not distinct from old.major and new.school is not distinct from old.school then return new; end if;
 if nullif(trim(new.major),'') is null then return new; end if;
 select c.name into canonical from public.tapid_major_catalog c where c.school_key=public.tapid_school_key(new.school) and lower(trim(new.major))=lower(c.name);
 if canonical is null then raise exception 'Select a major from your university program list.' using errcode='23514'; end if;
 new.major:=canonical;return new;
end;$$;
revoke all on function public.tapid_validate_major() from public,anon,authenticated;
drop trigger if exists tapid_validate_major on public.profiles;
create trigger tapid_validate_major before insert or update of major,school on public.profiles for each row execute function public.tapid_validate_major();
create or replace function public.university_fair_report_v2()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_report jsonb; v_events jsonb; v_school text; v_rows jsonb;
begin
 v_school:=public.current_university_school();
 if v_school is null then raise exception 'Verified university access required' using errcode='42501'; end if;
 v_report:=public.university_fair_report();
 select coalesce(jsonb_agg(e.value||jsonb_build_object('ends_at',case when e.value->>'key' like 'fair:%' then
  (select cf.ends_at from public.career_fairs cf where 'fair:'||cf.id::text=e.value->>'key'
   and public.tapid_school_key(cf.school_name)=public.tapid_school_key(v_school)) else null end)),'[]'::jsonb)
 into v_events from jsonb_array_elements(coalesce(v_report->'events','[]'::jsonb)) e;
 select coalesce(jsonb_agg(r.value||jsonb_build_object('student_name',
  coalesce(nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''),'Student'))),'[]'::jsonb)
 into v_rows from jsonb_array_elements(v_report->'rows') r
 left join public.profiles p on public.tapid_school_key(p.school)=public.tapid_school_key(v_school)
 and md5(p.id::text||':'||public.tapid_school_key(v_school)||':tapid-report')=r.value->>'student_key';
 return v_report||jsonb_build_object('events',v_events,'rows',v_rows);
end;$$;
revoke all on function public.university_fair_report_v2() from public,anon;
grant execute on function public.university_fair_report_v2() to authenticated;




insert into public.tapid_program_colleges(school_key,major_key,college_name) values
('cal poly','aerospace engineering','College of Engineering'),
('cal poly','agricultural business','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agricultural communication','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agricultural education','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agricultural science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agricultural systems management','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in animal science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in bioresource and agricultural systems','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in crop science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in dairy products technology','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in environmental horticultural science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in irrigation','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in plant protection science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','agriculture, specialization in water engineering','College of Agriculture, Food and Environmental Sciences'),
('cal poly','animal science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','anthropology and geography','College of Liberal Arts'),
('cal poly','architectural engineering','College of Architecture and Environmental Design'),
('cal poly','architecture','College of Architecture and Environmental Design'),
('cal poly','art and design','College of Liberal Arts'),
('cal poly','bioresource and agricultural engineering','College of Agriculture, Food and Environmental Sciences'),
('cal poly','biochemistry','Bailey College of Science and Mathematics'),
('cal poly','biological sciences','Bailey College of Science and Mathematics'),
('cal poly','biomedical engineering','College of Engineering'),
('cal poly','business administration','Orfalea College of Business'),
('cal poly','business analytics','Orfalea College of Business'),
('cal poly','chemistry','Bailey College of Science and Mathematics'),
('cal poly','child development','College of Liberal Arts'),
('cal poly','city and regional planning','College of Architecture and Environmental Design'),
('cal poly','city and regional planning and civil engineering','Interdisciplinary Degree Programs'),
('cal poly','civil engineering','College of Engineering'),
('cal poly','civil and environmental engineering','College of Engineering'),
('cal poly','communication studies','College of Liberal Arts'),
('cal poly','comparative ethnic studies','College of Liberal Arts'),
('cal poly','computer engineering','College of Engineering'),
('cal poly','computer science','College of Engineering'),
('cal poly','construction management','College of Architecture and Environmental Design'),
('cal poly','curriculum and instruction','Bailey College of Science and Mathematics'),
('cal poly','dairy science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','data science','Bailey College of Science and Mathematics'),
('cal poly','economics','Orfalea College of Business'),
('cal poly','educational leadership and administration','Bailey College of Science and Mathematics'),
('cal poly','electrical engineering','College of Engineering'),
('cal poly','engineering management','College of Engineering'),
('cal poly','english','College of Liberal Arts'),
('cal poly','environmental earth and soil sciences','College of Agriculture, Food and Environmental Sciences'),
('cal poly','environmental engineering','College of Engineering'),
('cal poly','environmental management and protection','College of Agriculture, Food and Environmental Sciences'),
('cal poly','environmental sciences and management','College of Agriculture, Food and Environmental Sciences'),
('cal poly','experience and event management','College of Agriculture, Food and Environmental Sciences'),
('cal poly','facilities engineering technology','College of Engineering'),
('cal poly','fire protection engineering','College of Engineering'),
('cal poly','food science','College of Agriculture, Food and Environmental Sciences'),
('cal poly','forest and fire sciences','College of Agriculture, Food and Environmental Sciences'),
('cal poly','general engineering','College of Engineering'),
('cal poly','graphic communication','College of Liberal Arts'),
('cal poly','higher education counseling and student affairs','Bailey College of Science and Mathematics'),
('cal poly','history','College of Liberal Arts'),
('cal poly','industrial engineering','College of Engineering'),
('cal poly','industrial technology and packaging','Orfalea College of Business'),
('cal poly','interdisciplinary studies','College of Liberal Arts'),
('cal poly','international strategy and security','College of Liberal Arts'),
('cal poly','journalism','College of Liberal Arts'),
('cal poly','kinesiology','Bailey College of Science and Mathematics'),
('cal poly','landscape architecture','College of Architecture and Environmental Design'),
('cal poly','liberal arts and engineering studies','Interdisciplinary Degree Programs'),
('cal poly','liberal studies','Bailey College of Science and Mathematics'),
('cal poly','manufacturing engineering','College of Engineering'),
('cal poly','marine engineering technology','College of Engineering'),
('cal poly','marine sciences','Bailey College of Science and Mathematics'),
('cal poly','marine transportation','College of Agriculture, Food and Environmental Sciences'),
('cal poly','materials engineering','College of Engineering'),
('cal poly','mathematics','Bailey College of Science and Mathematics'),
('cal poly','mechanical engineering','College of Engineering'),
('cal poly','microbiology','Bailey College of Science and Mathematics'),
('cal poly','music','College of Liberal Arts'),
('cal poly','nutrition','College of Agriculture, Food and Environmental Sciences'),
('cal poly','oceanography','Bailey College of Science and Mathematics'),
('cal poly','philosophy','College of Liberal Arts'),
('cal poly','physics','Bailey College of Science and Mathematics'),
('cal poly','plant sciences','College of Agriculture, Food and Environmental Sciences'),
('cal poly','political science','College of Liberal Arts'),
('cal poly','polymers and coatings science','Bailey College of Science and Mathematics'),
('cal poly','psychology','College of Liberal Arts'),
('cal poly','public health','Bailey College of Science and Mathematics'),
('cal poly','public policy','College of Liberal Arts'),
('cal poly','quantitative economics','Orfalea College of Business'),
('cal poly','sociology','College of Liberal Arts'),
('cal poly','software engineering','College of Engineering'),
('cal poly','spanish','College of Liberal Arts'),
('cal poly','special education','Bailey College of Science and Mathematics'),
('cal poly','statistics','Bailey College of Science and Mathematics'),
('cal poly','theatre arts','College of Liberal Arts'),
('cal poly','transportation and engineering management','Orfalea College of Business'),
('cal poly','wine and viticulture','College of Agriculture, Food and Environmental Sciences')
on conflict(school_key,major_key) do update set college_name=excluded.college_name;

create or replace function public.tapid_program_options(p_school text)
returns table(name text,college_name text) language sql stable security definer set search_path='' as $$
 select c.name,public.tapid_program_college(p_school,c.name) from public.tapid_major_catalog c
 where c.school_key=public.tapid_school_key(p_school) order by c.name;
$$;
revoke all on function public.tapid_program_options(text) from public;
grant execute on function public.tapid_program_options(text) to anon,authenticated;

-- Review remaining unmatched legacy entries; no abbreviation is silently reassigned.
select p.major,count(*) as accounts_needing_major_confirmation from public.profiles p
where exists(select 1 from public.tapid_major_catalog c where c.school_key=public.tapid_school_key(p.school))
and nullif(trim(p.major),'') is not null
and not exists(select 1 from public.tapid_major_catalog c where c.school_key=public.tapid_school_key(p.school) and c.name=p.major)
group by p.major order by count(*) desc;
notify pgrst, 'reload schema';
commit;
