-- TapID Sprint 3B: prevent public enumeration of hidden skill evidence links.

drop policy if exists "Public can view experience skill links" on public.experience_skills;

create policy "Public can view visible experience skill links"
on public.experience_skills
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.experiences e
    join public.skills s on s.id = skill_id and s.user_id = e.user_id
    join public.profiles p on p.id = e.user_id
    where e.id = experience_id
      and (
        e.user_id = auth.uid()
        or (e.is_public = true and s.is_public = true and p.profile_active = true)
      )
  )
);

drop policy if exists "Public can view project skill links" on public.project_skills;

create policy "Public can view visible project skill links"
on public.project_skills
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.projects pr
    join public.skills s on s.id = skill_id and s.user_id = pr.user_id
    join public.profiles p on p.id = pr.user_id
    where pr.id = project_id
      and (
        pr.user_id = auth.uid()
        or (pr.is_public = true and s.is_public = true and p.profile_active = true)
      )
  )
);
