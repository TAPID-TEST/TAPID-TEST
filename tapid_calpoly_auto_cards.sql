-- Run once in Supabase SQL Editor. Safe to rerun; existing cards are preserved.
-- Keep Authentication > Email > Confirm email enabled.
begin;

alter table public.card_issuance alter column issued_by drop not null;
alter table public.card_issuance add column if not exists issuance_source text not null default 'university';
create sequence if not exists public.tapid_calpoly_serial_seq;
revoke all on sequence public.tapid_calpoly_serial_seq from public, anon, authenticated;

create or replace function public.ensure_calpoly_card_for_user(p_user uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_profile public.profiles%rowtype;
  v_serial text;
  v_number text;
begin
  -- Never trust the profile's contact email or client-controlled user metadata.
  if not exists (
    select 1 from auth.users u where u.id=p_user
      and u.email_confirmed_at is not null
      and lower(split_part(u.email,'@',2))='calpoly.edu'
      and array_length(string_to_array(u.email,'@'),1)=2
  ) then return null; end if;
  if exists(select 1 from public.university_admins where user_id=p_user)
     or exists(select 1 from public.employer_recruiters where user_id=p_user)
  then return null; end if;

  -- Serialize simultaneous requests from two student tabs.
  select * into v_profile from public.profiles where id=p_user for update;
  if not found or nullif(trim(v_profile.username),'') is null
     or coalesce(lower(trim(v_profile.school)),'') not in
       ('cal poly','cal poly san luis obispo','cal poly, san luis obispo',
        'california polytechnic state university','california polytechnic state university, san luis obispo')
  then return null; end if;

  select card_serial into v_serial from public.card_issuance
    where student_user_id=p_user and status in ('issued','activated')
    order by issued_at desc,id desc limit 1;
  if found then return v_serial; end if;
  -- Do not automatically replace a revoked, lost, or replaced card.
  if exists(select 1 from public.card_issuance where student_user_id=p_user)
  then return null; end if;

  loop
    v_number := nextval('public.tapid_calpoly_serial_seq'::regclass)::text;
    v_serial := 'CP-' || lpad(v_number,greatest(8,length(v_number)),'0');
    insert into public.card_issuance(student_user_id,school_name,issued_by,card_serial,issuance_source,notes)
    values(p_user,v_profile.school,null,v_serial,'calpoly_email',
      'Automatically assigned after confirmation of a calpoly.edu email.')
    on conflict(card_serial) do nothing;
    exit when found;
  end loop;
  return v_serial;
end;
$$;
revoke all on function public.ensure_calpoly_card_for_user(uuid) from public,anon,authenticated;

create or replace function public.ensure_my_calpoly_card()
returns text language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in to continue'; end if;
  return public.ensure_calpoly_card_for_user(auth.uid());
end;
$$;
revoke all on function public.ensure_my_calpoly_card() from public,anon;
grant execute on function public.ensure_my_calpoly_card() to authenticated;

-- Email confirmation verifies affiliation; it does not prove current enrollment.
create or replace function public.public_profile_verification(p_username text)
returns table(school_name text,verification_label text)
language sql stable security definer set search_path = '' as $$
  select ci.school_name,
    case when ci.issuance_source='calpoly_email' then 'Cal Poly email verified'
      when p.school_year='Alumni' then 'Verified Alumni' else 'Verified Student' end
  from public.profiles p join public.card_issuance ci on ci.student_user_id=p.id
  join auth.users u on u.id=p.id
  where lower(p.username)=lower(trim(p_username))
    and p.profile_active and p.card_activated and ci.status='activated'
    and (ci.issuance_source<>'calpoly_email' or
      (u.email_confirmed_at is not null and lower(split_part(u.email,'@',2))='calpoly.edu'))
  order by ci.activated_at desc nulls last,ci.issued_at desc limit 1;
$$;
revoke all on function public.public_profile_verification(text) from public;
grant execute on function public.public_profile_verification(text) to anon,authenticated;

-- Also assign cards to existing eligible student accounts, including your demo.
do $$
declare v_user uuid;
begin
  for v_user in select p.id from public.profiles p join auth.users u on u.id=p.id
    where u.email_confirmed_at is not null and lower(split_part(u.email,'@',2))='calpoly.edu'
  loop perform public.ensure_calpoly_card_for_user(v_user); end loop;
end;
$$;
commit;
