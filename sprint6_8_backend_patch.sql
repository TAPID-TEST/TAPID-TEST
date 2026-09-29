-- TapID Sprint 6.8: Featured Experience + Featured Project

alter table public.experiences add column if not exists is_featured boolean not null default false;
alter table public.projects add column if not exists is_featured boolean not null default false;

create unique index if not exists one_featured_experience_per_user
  on public.experiences(user_id) where is_featured = true;

create unique index if not exists one_featured_project_per_user
  on public.projects(user_id) where is_featured = true;
