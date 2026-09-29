# TapID V3 role-to-role acceptance test

Use three dedicated test identities. Email aliases are fine if the mailbox
supports them, but each identity must have its own Supabase Auth user.

| Role | Example name | Purpose |
|---|---|---|
| Student | Taylor Mustang | Builds and shares a Cal Poly student profile |
| Employer | Jordan Builder at Kiewit Test | Registers for a fair and reviews students |
| University | Morgan Admin at Cal Poly | Publishes the fair, approves the employer, and issues the card |

Never place any test password, service-role key, or secret in GitHub. Use unique
passwords stored in a password manager.

## Account setup

1. Create Taylor through `signup.html`, confirm the email, and finish onboarding
   with the school name `Cal Poly`.
2. Create Jordan through `employer-signup.html` and confirm the email. The first
   employer login creates the recruiter record from trusted Auth metadata.
3. Create Morgan in Supabase Authentication > Users. In SQL Editor, replace the
   email in the following one-time statement and run it as the project owner:

```sql
begin;

update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('user_type', 'university')
where lower(email) = lower('REPLACE_WITH_CAL_POLY_ADMIN_EMAIL');

delete from public.profiles
where id = (
  select id from auth.users
  where lower(email) = lower('REPLACE_WITH_CAL_POLY_ADMIN_EMAIL')
);

insert into public.university_admins (
  user_id,
  school_name,
  admin_name,
  verification_status
)
select
  id,
  'Cal Poly',
  'Morgan Admin',
  'verified'
from auth.users
where lower(email) = lower('REPLACE_WITH_CAL_POLY_ADMIN_EMAIL')
on conflict (user_id) do update set
  school_name = excluded.school_name,
  admin_name = excluded.admin_name,
  verification_status = 'verified';

commit;
```

If the insert reports zero rows, the Auth user email does not match the replaced
value. Do not weaken the university verification rule to work around that.

## End-to-end test order

| # | Actor | Action | Expected result |
|---:|---|---|---|
| 1 | University | Sign in and create/publish `Cal Poly Test Career Fair` | Fair appears in university administration |
| 2 | Employer | Sign in and register Kiewit Test for the fair | Registration is pending; candidate data remains unavailable |
| 3 | University | Approve the Kiewit Test registration and assign booth `T-01` | Employer becomes verified |
| 4 | Employer | Select the approved fair as the current event | Event saves successfully |
| 5 | University | Issue Taylor a unique test card serial | Card status is issued |
| 6 | Student | Enter that serial on the card page | Profile and card become active |
| 7 | Student | Add résumé, skills, experience, project, evidence, recommendation, outcome, privacy choices, and photo | Data persists after reload; hidden records stay hidden publicly |
| 8 | Anonymous | Open Taylor's permanent profile and QR URL | Only public sections appear; no private notes or connection count appears |
| 9 | Employer | Open Taylor from the event and connect directly | One employer candidate and one student connection are created |
| 10 | Employer | Change candidate status and private notes | Only status/notes change; student cannot see private notes |
| 11 | Student | Send Kiewit Test a connection request for the same official fair | Pending request appears once; recruiter contact remains hidden |
| 12 | Employer | Accept the request | Request becomes accepted; mutual connection exists without a duplicate direct connection |
| 13 | Student | Send a request to a second test employer, then employer declines it | Declined request never becomes a connection |
| 14 | University | Review dashboards | Counts are aggregate-only and separate direct, accepted, pending, and declined activity |
| 15 | All roles | Test wrong-role login pages and sign-out | Each role is blocked from the other protected workspaces |
| 16 | Student | Test password reset, email change, password change, profile pause, and deletion using a disposable student | All lifecycle actions complete and deleted data is no longer accessible |

## Required negative checks

- A pending employer cannot read candidate rows or request inbox data.
- An employer cannot self-set `verification_status`, change its company ID, or
  reassign a candidate connection through the browser API.
- A recruiter cannot connect without a selected, published, approved fair.
- A non-university account cannot call university aggregate or administration
  functions.
- University dashboards never return individual student relationship rows.
- Pending requests do not count as connections and do not reveal recruiter
  contact information.
- Private files use signed URLs and are not permanently public.

## External physical check

Write Taylor's exact permanent profile URL to a rewritable NFC card. Test NFC and
the QR code on current iPhone and Android devices before locking the tag.
