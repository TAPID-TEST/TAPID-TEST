TAPID — CONNECTION ACCEPTANCE AND UNIVERSITY ENGAGEMENT

FIRST: FIX THE REQUEST ERROR
Run the complete tapid_engagement_analytics.sql in Supabase SQL Editor.
It replaces respond_employer_connection_request so acceptance uses
 tapid_fair_roster(), the same university-import + approved legacy roster used
by fair listings and request creation. A university-approved recruiter still
needs its company listed for that published fair. Approval alone does not
permit accepting arbitrary requests from another fair or university.
Pending requests remain company scoped and locked while responding.
Student profile/card activation and recruiter verification checks remain.
Past published fairs can be accepted; an ended fair does not invalidate follow-up.
An unlisted fair request can be declined instead of remaining stuck.
Existing accounts, approvals, profiles and pending requests are preserved.

After SQL succeeds, refresh the employer page and accept Ethan's existing
request. Check Connections, then Candidate Match. No new AI Edge Function
or secret change is required for this update.

THEN: PUBLISH THE ANALYTICS
Upload and replace these seven website files together in GitHub:
 university-dashboard.html
 university-students.html
 university-employers.html
 university-population-model.js
 university-population-workspace.js
 university-workspace-ui.js
 university-workspace.css
Commit: Fix fair request acceptance and focus university analytics on engagement
Wait for Pages deployment, then hard-refresh each university tab.
Do not replace the AI function or employer Candidate Match files for this patch.

STUDENT VIEW
Top metrics: accounts; students with at least one connection plus participation
rate; total unique introductions; students recording introductions in 30 days.
Email-confirmation and serial-assignment KPIs, setup donut and duplicate major
participation table are removed. Setup filters remain available in the directory.
Connections by college expands into its majors. A dropdown switches to all majors.
Connections by class year appears separately. New connections over twelve months
replaces the signup-growth chart. Student directory includes college and retains
search, major/year/status filters, profile links, pagination and page printing.

EMPLOYER VIEW
Analytics show approved recruiting partners, companies with connections plus
participation rate, distinct student reach across those companies, and partners
recording introductions in thirty days. No repeated approval-status donut.
Connections by employer, connections by major with optional employer selection,
and monthly connected-company counts answer different questions.
Employer directory is expandable. Approvals and their existing review/email
controls remain in Approvals. Registered/pending/declined accounts are not mixed
into the approved-partner engagement denominator.

OVERVIEW
Student and employer participation use a simple connected/not-connected split.
Setup-status bars are removed from the overview. Next actions link to students
without connections, employer analytics, and pending recruiter approvals.
Fair reports and employer-reported milestone definitions remain as before.

METRICS
Connection = one student x company x career fair/source. Multiple recruiters or
repeated taps at the same source do not create extra analytics connections.
Monthly and last-30-day counts use the first introduction timestamp for that
unique connection, not a later repeated tap. They measure new introductions,
not logins, messages, hours of usage, or every return visit to a relationship.
Students with connections = distinct associated student accounts with at least
one employer connection. This is participation, not the number of connections.
Employer students reached deduplicates students across approved companies.
Monthly employer counts deduplicate companies within each month.
Zero denominators show a dash, not an invented zero percentage.
No example data is inserted, and empty charts state that no activity is recorded.

COLLEGES
SQL seeds exact Cal Poly program names using its public catalog college structure.
Matching trims whitespace and ignores case. It does not guess from partial text.
Civil and Mechanical Engineering map to College of Engineering; Architectural
Engineering maps to Architecture and Environmental Design.
Unknown free-text majors such as "Bus" remain Unclassified major until the student
uses a recognized major or an administrator adds an explicit mapping in SQL.
Mappings are in tapid_program_colleges; browser users cannot edit that table.
Other schools are not assigned Cal Poly's structure. Add their mappings explicitly.
Original student major text is preserved, never overwritten.
Sources:
https://catalog.calpoly.edu/colleges-departments/
https://catalog.calpoly.edu/programs/
https://catalog.calpoly.edu/engineering/
https://catalog.calpoly.edu/architecture-environmental-design/
https://catalog.calpoly.edu/business/

PRINTING
The existing Print analytics / Save PDF actions remain. Printing expands college
majors and the employer directory and restores their previous state afterward.
Student-directory printing remains limited to the current filtered page.
Report prints show scope and generated time. No emails or private notes enter
these analytics functions or charts.

VALIDATION
Eight local suites pass. They cover page wiring, real renderer execution with
mock responses, metric group totals, empty states, directory escaping/paging,
existing fair/report/onboarding/AI flows, and SQL acceptance/security wiring.
SQL checks are static: no live PostgreSQL engine or authenticated Supabase
connection was available. Signed-in acceptance, live aggregate counts and
browser print layout still need validation in your project. No live accounts
or approvals were modified here.

LIVE CHECKS
1. Accept the imported fair request as the approved recruiter; verify one
   connection and that the original request disappears from Pending.
2. Confirm student account participation changes to one of two students, not
   one connection of two student accounts. Verify its major/year/college totals.
3. Check Candidate Match with field-work criteria, then a resume request.
4. Revoke fair roster membership and confirm accepting a new request fails;
   declining it still works. Another company's request must not be accessible.
5. Add a second recruiter connection to the same student/company/fair and
   verify university totals stay unchanged. A different fair is a new introduction.
6. Check college expansion, All majors, employer selection, directory filters,
   and printable report scope. Confirm unrecognized majors are visibly unclassified.
