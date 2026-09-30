-- TapID V7: student opportunity preferences, notifications, career-fair
-- planning, and public university verification.

begin;

create table if not exists public.student_opportunity_preferences (
  student_user_id uuid primary key references public.profiles(id) on delete cascade,
  opportunity_types text[] not null default '{}',
  desired_roles text[] not null default '{}',
  industries text[] not null default '{}',
  preferred_locations text[] not null default '{}',
  available_start_date date,
  willing_to_relocate boolean not null default false,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  student_user_id uuid primary key references public.profiles(id) on delete cascade,
  connection_updates boolean not null default true,
  verified_outcomes boolean not null default true,
  career_fair_updates boolean not null default true,
  card_updates boolean not null default true,
  email_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.student_notifications (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null check (notification_type in ('connection','outcome','career_fair','card','profile')),
  title text not null,
  body text not null,
  href text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists student_notifications_user_created_idx
on public.student_notifications (student_user_id, created_at desc);

create table if not exists public.career_fair_student_plans (
  id bigint generated always as identity primary key,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  career_fair_id bigint not null references public.career_fairs(id) on delete cascade,
  company_id bigint not null references public.companies(id) on delete cascade,
  plan_status text not null default 'saved' check (plan_status in ('saved','visited')),
  private_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_user_id, career_fair_id, company_id)
);

alter table public.student_opportunity_preferences enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.student_notifications enable row level security;
alter table public.career_fair_student_plans enable row level security;

drop policy if exists "Students manage own opportunity preferences" on public.student_opportunity_preferences;
create policy "Students manage own opportunity preferences"
on public.student_opportunity_preferences for all to authenticated
using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

drop policy if exists "Public can view public opportunity preferences" on public.student_opportunity_preferences;
create policy "Public can view public opportunity preferences"
on public.student_opportunity_preferences for select to anon, authenticated
using (
  is_public = true and exists (
    select 1 from public.profiles p
    where p.id = student_user_id and p.profile_active and p.card_activated
  )
);

drop policy if exists "Students manage own notification preferences" on public.notification_preferences;
create policy "Students manage own notification preferences"
on public.notification_preferences for all to authenticated
using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

drop policy if exists "Students view own notifications" on public.student_notifications;
create policy "Students view own notifications"
on public.student_notifications for select to authenticated
using (student_user_id = auth.uid());

drop policy if exists "Students mark own notifications read" on public.student_notifications;
create policy "Students mark own notifications read"
on public.student_notifications for update to authenticated
using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

drop policy if exists "Students delete own notifications" on public.student_notifications;
create policy "Students delete own notifications"
on public.student_notifications for delete to authenticated
using (student_user_id = auth.uid());

drop policy if exists "Students manage own career fair plan" on public.career_fair_student_plans;
create policy "Students manage own career fair plan"
on public.career_fair_student_plans for all to authenticated
using (student_user_id = auth.uid()) with check (student_user_id = auth.uid());

grant select, insert, update, delete on public.student_opportunity_preferences to authenticated;
grant select on public.student_opportunity_preferences to anon;
grant select, insert, update, delete on public.notification_preferences to authenticated;
revoke update on public.student_notifications from authenticated;
grant select, delete on public.student_notifications to authenticated;
grant update (read_at) on public.student_notifications to authenticated;
grant select, insert, update, delete on public.career_fair_student_plans to authenticated;
grant usage, select on sequence public.career_fair_student_plans_id_seq to authenticated;

create or replace function public.public_profile_verification(p_username text)
returns table (school_name text, verification_label text)
language sql stable security definer set search_path=public as $$
  select ci.school_name,
         case when p.school_year = 'Alumni' then 'Verified Alumni' else 'Verified Student' end
  from public.profiles p
  join public.card_issuance ci on ci.student_user_id = p.id
  where lower(p.username) = lower(trim(p_username))
    and p.profile_active and p.card_activated
    and ci.status = 'activated'
  order by ci.activated_at desc nulls last, ci.issued_at desc
  limit 1;
$$;

revoke all on function public.public_profile_verification(text) from public;
grant execute on function public.public_profile_verification(text) to anon, authenticated;

create or replace function public.notify_connection_request_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_company text;
begin
  if new.status not in ('accepted','declined') or new.status is not distinct from old.status then return new; end if;
  if coalesce((select connection_updates from public.notification_preferences where student_user_id=new.student_user_id),true)=false then return new; end if;
  select name into v_company from public.companies where id=new.company_id;
  insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata)
  values(new.student_user_id,'connection',
    case when new.status='accepted' then 'Connection accepted' else 'Connection request declined' end,
    coalesce(v_company,'An employer') || case when new.status='accepted' then ' accepted your connection request.' else ' declined your connection request.' end,
    'dashboard.html#connections',jsonb_build_object('request_id',new.id,'status',new.status));
  return new;
end; $$;

drop trigger if exists notify_connection_request_change_trigger on public.employer_connection_requests;
create trigger notify_connection_request_change_trigger after update of status on public.employer_connection_requests
for each row execute function public.notify_connection_request_change();

create or replace function public.notify_verified_outcome()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.verification_status <> 'verified' then return new; end if;
  if coalesce((select verified_outcomes from public.notification_preferences where student_user_id=new.student_user_id),true)=false then return new; end if;
  insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata)
  values(new.student_user_id,'outcome','New verified career outcome',
    new.company_name || ' recorded a verified ' || replace(new.outcome_type,'_',' ') || ' outcome.',
    'journey.html#outcomes',jsonb_build_object('outcome_id',new.id,'outcome_type',new.outcome_type));
  return new;
end; $$;

drop trigger if exists notify_verified_outcome_trigger on public.career_outcomes;
create trigger notify_verified_outcome_trigger after insert on public.career_outcomes
for each row execute function public.notify_verified_outcome();

create or replace function public.notify_published_career_fair()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if not new.is_published or (tg_op='UPDATE' and old.is_published) then return new; end if;
  insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata)
  select p.id,'career_fair','New career fair published',new.name || ' is now available in TapID.',
         'dashboard.html#career-fairs',jsonb_build_object('career_fair_id',new.id)
  from public.profiles p
  left join public.notification_preferences np on np.student_user_id=p.id
  where lower(trim(coalesce(p.school,'')))=lower(trim(new.school_name))
    and coalesce(np.career_fair_updates,true);
  return new;
end; $$;

drop trigger if exists notify_published_career_fair_trigger on public.career_fairs;
create trigger notify_published_career_fair_trigger after insert or update of is_published on public.career_fairs
for each row execute function public.notify_published_career_fair();

create or replace function public.notify_card_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
  if coalesce((select card_updates from public.notification_preferences where student_user_id=new.student_user_id),true)=false then return new; end if;
  insert into public.student_notifications(student_user_id,notification_type,title,body,href,metadata)
  values(new.student_user_id,'card','TapID card update',
    'Your TapID card status is now ' || replace(new.status,'_',' ') || '.',
    'card.html',jsonb_build_object('card_issuance_id',new.id,'status',new.status));
  return new;
end; $$;

drop trigger if exists notify_card_change_trigger on public.card_issuance;
create trigger notify_card_change_trigger after insert or update of status on public.card_issuance
for each row execute function public.notify_card_change();

commit;
