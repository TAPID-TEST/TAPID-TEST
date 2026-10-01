begin;

-- University signup requests are created automatically from verified-email auth signup metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_type text;
begin
  v_type := coalesce(new.raw_user_meta_data->>'user_type', 'student');

  if v_type = 'employer' then
    return new;
  end if;

  if v_type = 'university' then
    insert into public.university_admins (
      user_id, school_name, admin_name, verification_status, created_at
    ) values (
      new.id,
      coalesce(nullif(trim(new.raw_user_meta_data->>'university_name'),''), 'Unspecified university'),
      nullif(trim(new.raw_user_meta_data->>'admin_name'),''),
      'pending',
      now()
    ) on conflict (user_id) do nothing;
    return new;
  end if;

  insert into public.profiles (id, username, first_name, last_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'username',''), 'user-' || left(new.id::text, 8)),
    nullif(new.raw_user_meta_data->>'first_name',''),
    nullif(new.raw_user_meta_data->>'last_name','')
  ) on conflict (id) do nothing;
  return new;
end;
$$;

-- Outcomes are employer-generated and institution-facing. Students can see their
-- private milestones, but cannot publish, edit, create, or delete them.
update public.career_outcomes set is_public = false where is_public = true;
drop policy if exists "Students control verified outcome visibility" on public.career_outcomes;
drop policy if exists "Public can view public outcomes" on public.career_outcomes;
revoke update (is_public, updated_at) on public.career_outcomes from authenticated;

-- Notification choices are no longer exposed in the student interface. Keep all
-- in-app categories enabled so employer and card activity is reported consistently.
update public.notification_preferences
set connection_updates = true,
    verified_outcomes = true,
    career_fair_updates = true,
    card_updates = true,
    email_enabled = false,
    updated_at = now();

commit;
