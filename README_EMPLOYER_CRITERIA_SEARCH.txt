TAPID EMPLOYER EXPERIENCE SEARCH — NEXT UPDATE

WHAT THIS ADDS
Employer dashboard > Connections > Find the experience you need.
Type a request, choose Match all / Match any / Use my wording, and search.
Examples: field work; office and coordination work; estimating and Bluebeam.
AI translates the request into supported work criteria. Visible criterion chips
show the interpretation. Clear experience search returns the usual list.
Existing major/year/event/stage/priority filters further narrow the results.
Click a result to open the existing student relationship panel.

Results quote the student's public work entries or skills, cite their section
and title, and show how many work entries match. Skill-only evidence remains
visible but contributes zero work entries. Sorting uses criterion coverage and
matching work-entry count. It is NOT total years of experience, a prediction of
personality or office preference, or a hiring recommendation. Multiple matches
inside one work entry count once. No matches means no documented match, not
proof that the student lacks that experience.

SUPPORTED CRITERIA IN THIS FIRST VERSION
Field work, office/coordination work, estimating, cost control, scheduling,
RFIs, submittals, change orders, quantity tracking, safety inspections,
environmental work, design, project coordination, data analysis, research,
Bluebeam, AutoCAD, Excel, Revit/BIM. Up to eight criteria per search.
Unsupported requirements show a clear message rather than silently dropping
part of the employer's request. Broader criteria can be added later.

DEPLOYMENT ORDER
1. In Supabase SQL Editor, run tapid_employer_criteria_search.sql.
   It adds two functions and a private usage table; no accounts are removed.

2. Deploy an Edge Function named EXACTLY search-student-experience.
   Browser editor option: create a new function, replace its index.ts contents
   with ALL of search-student-experience.ts, and deploy.
   Set gateway JWT verification OFF for this function if the editor asks.
   The function itself verifies the bearer token with auth.getUser; SQL also
   checks the caller is a verified employer and scopes connections by company.
   This switch does not make the function anonymously accessible.

   CLI option from this project directory:
   supabase functions deploy search-student-experience --project-ref ngdamuvnvuadwbfsaohi --no-verify-jwt
   The modular files under supabase/functions/search-student-experience are
   equivalent to the single-file browser-editor version.

3. Under Supabase Edge Function secrets, confirm OPENAI_API_KEY exists.
   Its value must be an OpenAI API key with working billing and model access.
   Never add its value to GitHub, config.js, HTML, or a chat message.
   Optional secret OPENAI_SEARCH_MODEL changes the default gpt-4.1-mini model.
   SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by hosted Supabase.
   No new arbitrary second shared secret is required by this integration.
   Existing RESEND_API_KEY / TAPID_APPROVAL_FROM belong to approval emails;
   they are not used for this search.
   If your AI key has a different secret NAME, create OPENAI_API_KEY with that
   key, or change the env lookup in the server function. Never expose the value.

4. Upload and commit these four website files together:
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   fair-dashboard.js
   Suggested commit: Add employer experience search with profile evidence

FAIR UPDATE DEPENDENCY
This employer dashboard includes the prepared fair-notification update.
If you have not installed it yet, first run tapid_fair_notifications.sql,
then upload dashboard.html and fair-dashboard.js alongside the employer files.
The ZIP includes these files so the earlier missing-fair issue stays fixed.
If the migration warns Cron is unavailable, enable Cron then run
 tapid_fair_reminder_schedule.sql. This is independent of AI search.
If the live dashboard has changes made after this source snapshot, merge this
search panel and scripts with those changes before replacing that dashboard.
Live GitHub/Supabase were not reachable from this workspace.

PRIVACY / COST / AUTHORIZATION
Only verified recruiters may search their own company's connected students.
Only active public profiles with activated cards are included. Hidden experiences,
projects, skills, and sections are excluded. Private notes, messages, contact
information, photos, demographic fields and recommendations are not searched.
The AI request contains the employer's wording and a fixed criteria vocabulary;
it does NOT contain student profile data. store:false is sent to OpenAI.
No search text is stored in the usage table. No new messages or emails are sent.
Limits: six AI calls per recruiter per minute, 40 per UTC day, 600 query
characters, 500 output tokens. Reapplying already-interpreted criteria doesn't
call AI again. Provider errors fail clearly; no automatic paid-call retries.
The prototype supports up to 1,000 active public connected profiles per company.
Search does not change student stages, priorities, or relationship history.
Matching uses documented task phrases and synonyms; it can miss unusual wording.
Read the quoted evidence and the full profile before making a hiring decision.

TEST AFTER DEPLOYMENT
- Sign in as a verified employer with connected, active public profiles.
- Search field work; check that the quoted entry actually supports the result.
- Search office work; inspect the documented office/coordination tasks.
- Search estimating AND Bluebeam; then switch to Any and search again.
- Apply an event or major filter to narrow the matching connections.
- Open a matching student, save a normal relationship update, and close it.
- Clear experience search; normal connections and filters should still work.
- Hide a student's work entry/section, refresh the student dashboard if needed,
  then rerun employer search: the hidden evidence must no longer appear.
- A pending employer and a logged-out request must be denied by the function.
- Verify one company cannot return another company's unconnected students.
- Test an empty result, an unsupported criterion and a missing/invalid API key.
- Publish a fair and verify the earlier event visibility and notification fixes.

LOCAL VALIDATION
Seven suites pass: HTML/wiring, analytics, population, fair setup, onboarding,
fair notifications, and this search. New tests exercise auth, scope wiring,
public section checks, denied-experience examples, all/any matching, exact
quotes, output escaping, no student data sent to AI, quotas and provider failures.
The model call is mocked in tests. No paid API call, deployed SQL execution,
real Edge Function deployment or authenticated live browser test was performed.

References:
https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses
https://developers.openai.com/api/docs/models/gpt-4.1-mini
https://supabase.com/docs/guides/functions/auth
