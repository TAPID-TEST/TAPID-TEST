# TapID V3 live acceptance results

Test date: September 29, 2026  
Environment: `https://golden-truffle-0b0c47.netlify.app`  
Supabase project: `ngdamuvnvuadwbfsaohi`

## Test identities

- Cal Poly verified university administrator
- Taylor Mustang activated student
- Kiewit Test verified employer
- Granite Test verified employer
- Disposable student accounts for email-change and deletion testing

No passwords or secret/service-role credentials are stored in this repository.

## Passed live workflows

- University provisioning, verified login, event publishing, employer approval,
  card issuance, aggregate insights, request conversion, and career outcomes
- Employer signup/confirmation/login, fair registration, verification, current
  event selection, request inbox, accept/decline, candidate search/filters,
  private notes, candidate statuses, and duplicate-connection prevention
- Student signup/confirmation/onboarding, university-issued serial activation,
  permanent username, QR profile, profile pause/reactivation, employer request,
  accepted recruiter details, declined-request state, and private connections
- Public profile, contact visibility, Save Contact, professional links, résumé,
  experience, project, evidence-linked skill, organization, certification,
  recommendation, recommendation PDF, outcome, and section privacy
- University aggregate separation of direct, accepted, pending, and declined
  activity without exposing individual student relationship data
- Wrong-role blocking for employer-to-university and student-to-employer access
- Password recovery, in-account password change, email change, and permanent
  deletion using disposable accounts
- Real-phone QR scan to the permanent public profile URL
- Physical NFC-card programming and signed-out phone tap to Taylor Mustang's
  permanent public profile URL
- Public/hidden profile-photo states and experience/project image upload,
  display, removal, and privacy behavior
- Private PDF delivery for résumé, certificate, and recommendation letter, plus
  recommendation/file deletion
- Alumni-since display without changing the permanent profile URL

## Defects found and corrected during live testing

1. Completed university employer registrations continued to display active
   Approve/Reject buttons. Approved/rejected rows now show a status badge.
2. A disabled public project section could still appear in the public snapshot
   count for an authenticated profile owner. Disabled sections are now removed
   from public datasets before counts and evidence are rendered.
3. Employer confirmation and password recovery returned to student login.
   Employer role context is now preserved through both flows.

## Deferred external checks

- Cross-platform NFC tap testing on both iPhone and Android hardware
- Custom production domain
- Production SMTP provider configuration and delivery monitoring

These deferred checks do not block the tested web application flows, but should
be completed before a physical-card pilot or public production launch.
