TAPID UNIVERSITY WORKSPACE UPGRADE
2026-10-06

INSTALL IN THIS ORDER

1. Once your Supabase dashboard is accessible, open SQL Editor and run the
   entire tapid_university_upgrade.sql file. This single transaction includes
   automatic Cal Poly student cards and the university report/approval update.
   It assumes your existing V10/V10.2 prototype schema is already installed.
   Do not rerun older migrations after it: they may overwrite these functions.
   If any SQL error appears, stop and share the exact error before publishing.

2. In Supabase Authentication, keep email confirmation enabled. Set the site
   URL to https://tapidcard.com and allow these confirmation redirect URLs:
   https://tapidcard.com/login.html?confirmed=1
   https://tapidcard.com/employer-login.html?confirmed=1
   Preserve any other redirect URLs you still intentionally use.
   If email confirmation is disabled or an administrator manually confirms a
   user, automatic affiliation relies on that setting/administrator decision.

3. Extract this ZIP. Upload/replace the HTML, CSS and JavaScript files below
   at the repository root. Preserve your existing index.html, config.js,
   CNAME, styles.css, assets, profile pages and other unchanged site files.

   app.js
   card.html
   onboarding.html
   signup.html
   login.html
   employer-signup.html
   employer-login.html
   employer-dashboard.html
   employer-approval-status.js
   university-dashboard.html
   university-employers.html
   university-employer-approvals.js
   university-report-workspace.js
   fair-report-model.js
   university-reports.css
   university-admin.html
   university-login.html
   university-card-access.js
   dashboard-theme.css

   The SQL, this README, package.json and tests are not required in the
   published website. Keep them for installation and development.

4. Commit: Upgrade university reports and employer approval workflow
   Wait for GitHub Pages to deploy successfully, then hard refresh the site.

WHAT CHANGED

Career-fair reports
  Opens the latest past dated fair, with a recent recorded source fallback.
  Choose a fair, results window and optional comparison. Filter by employer,
  major, class year and connection dates. Click an employer to focus the report.
  Overview includes participation, milestone bars, employer activity donut,
  connection timeline and a separate current-stage chart. Employer/major/year
  tables are in separate tabs rather than repeated across the overview.
  Print report / Save PDF includes charts, tables, selected filters and an
  as-of timestamp. It prints hidden detail tabs, not just the open screen.
  Selecting a comparison adds it to the printed report. CSV exports aggregate
  metrics, employer/major/year results, current stages, daily activity and the
  selected comparison. No student names, emails, messages or private notes
  are exported by this report.

Employer approvals
  Separate university tab: Pending, Approved, Declined; search; website and
  confirmed email; approval history; approve, decline or revoke.
  Declining/revoking requires a short reason. Employer account creation does
  not grant recruiting access. Their home shows an In review state until
  approved, then Check status refreshes access. No approval emails are sent
  by this patch. Decisions are visible on the employer dashboard.
  Verification is protected in the database, not just hidden in the UI.
  Scope is one university per recruiter account in this prototype. Existing
  recruiters default to Cal Poly. A future multi-university employer model
  should use separate institution permission records.

Student onboarding
  A username is generated at signup. Existing usernames are not changed.
  A confirmed calpoly.edu student email fills a blank school field and assigns
  a serial automatically. Existing card serials and account content remain.
  Students still complete their profile and explicitly activate public sharing.
  Cal Poly email verification proves email affiliation, not current enrollment.
  It never grants employer verification or university administrator access.
  Existing revoked/lost/replaced cards are not automatically reissued.
  Missing optional card SQL no longer blocks student login. The card page
  displays an installation error if provisioning has not been installed.

REPORT DEFINITIONS

Connections: one student-company-event-source relationship, not number of taps.
Students: unique students within the selection; they can meet multiple employers.
Milestones: recorded stages reached, counted once per relationship per stage.
  An offer remains counted when a relationship later advances to hired.
  Stages are not assumed to be sequential. A hire does not fabricate an
  unrecorded interview or offer. Missing old history cannot be reconstructed.
Current stage: latest employer-reported status, separate from reached milestones.
Employer activity: recorded employer messages or employer-reported activity.
  No recorded activity does not mean no communication outside TapID.
Results window: first 7, 30 or 90 days after EACH connection, not after fair day.
  Newer connections can have incomplete windows; these are marked provisional.
Comparisons: completed observation windows only by default for windowed reports.
  Counts and rates are both shown; volume alone is not a quality ranking.
Median response: median time to first timestamped employer activity; unavailable
  timestamps are not invented or replaced with zero.
Dates: connected-date filters and daily activity use America/Los_Angeles.
Event attribution: stable identifiers take precedence. Ambiguous repeated names
  remain unresolved rather than assigned to the wrong career fair.
These are TapID-recorded relationships and employer reports, not a measure of
all fair attendance, proof that a fair caused a hire, or official graduate
placement statistics. They do not establish which skills causally drive hiring.

DEMO CHECKLIST AFTER INSTALLATION

1. Sign up a student with a Cal Poly email, confirm the email, finish onboarding,
   then open Card. Verify an automatic serial appears and activation works.
2. Verify an existing student can still log in and keeps their username/serial.
3. Create an employer account, confirm its email and log in. It should show
   In review and no recruiting data. University > Employer approvals should
   show the request at its selected institution.
4. Approve the employer, return to its dashboard and click Check status.
   Verify its ordinary connection, message, profile and pipeline flows.
5. Decline or revoke approval with a reason. Refresh the employer session and
   verify access is restricted. Verify a student cannot approve employers.
6. Record an interview, offer and hire on a test relationship. University
   reports should retain recorded milestones while current stage shows Hired.
7. Select a fair, window and comparison; test filters, empty data, summary CSV,
   and Print report / Save PDF. Check the print preview and page breaks.
8. In a private browser window, opening university-dashboard.html must require
   a verified administrator login. A calpoly.edu student is NOT an administrator.

VALIDATION

Local automated checks pass across 36 HTML pages, plus focused tests for stage
deduplication, skipped stages, windows, maturity, Pacific dates, empty data,
employer labels, script syntax, file links, DOM wiring and login isolation.
The Supabase SQL has not been executed against your live database here.
Live permissions, account flows and browser print layout require the checklist
above after installation. No accounts were deleted by this update.

RESEARCH THAT INFORMED THE DESIGN

Cvent: event-by-event performance, portfolio comparisons, shareable reporting.
https://www.cvent.com/en/event-management-software/event-reporting
HubSpot: timestamped stage entry, rather than only the latest pipeline status.
https://knowledge.hubspot.com/reports/create-new-custom-funnel-reports
Amplitude: time-based cohorts and observation windows for fair comparisons.
https://amplitude.com/docs/analytics/charts/retention-analysis/retention-analysis-interpret
Handshake: institution approvals, review queues and required decline reasons.
https://support.joinhandshake.com/hc/en-us/articles/360024477333-Processing-Employer-Approval-Requests-using-Job-Based-Approvals

Applied the patterns, not the vendors' product scope. TapID remains focused on
profiles, introductions, follow-up and fair-associated recruiting milestones.
