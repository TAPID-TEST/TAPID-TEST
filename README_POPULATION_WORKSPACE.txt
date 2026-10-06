TAPID: UNIVERSITY POPULATIONS AND PUBLIC PROFILE THEME
2026-10-06

INSTALL
1. You already installed tapid_university_upgrade.sql. Run the entire new
   tapid_university_population.sql in Supabase SQL Editor. This is an additive
   migration. No accounts or cards are reset, issued or removed by this SQL.
2. Upload all HTML/CSS/JS files from this ZIP into the GitHub repository root,
   replacing existing files and adding the new files. Keep index.html, assets,
   config.js, CNAME, styles.css and other unchanged website files.
3. Commit: Organize university analytics and match public profile theme
4. Wait for GitHub Pages deployment, then hard refresh your browser.

FILES TO COMMIT
profile.html
public-profile-theme.css
university-dashboard.html
university-students.html
university-employers.html
university-fairs.html
university-admin.html
university-population-model.js
university-workspace-ui.js
university-population-workspace.js
university-workspace.css
university-report-workspace.js
university-employer-approvals.js
university-card-access.js
fair-report-model.js
university-reports.css
dashboard-theme.css

The SQL and this README are not needed on the published website.

PORTAL STRUCTURE
Overview: students, approved companies, connections and recorded interviews;
student/employer participation; activation/approval tasks; career-fair table.
Students: account totals, confirmed emails, issued serials, connected students;
monthly account growth, setup donut, major/year bars and participation table;
searchable/filterable directory with 50 rows per page; Add students signup link.
Employers: companies and recruiter counts, access status, connections by company,
student/event participation, recorded interviews/offers/hires; Approvals view
preserves approve/decline/revoke and refreshes analytics after decisions.
Career Fairs: existing fair-specific charts, stage history, comparisons, CSV
and print reports. Fair dates appear in comparison options. Comparison-window
control appears only when comparing fairs using a 7/30/90-day results window.
Administration: event imports/matching and manual card exceptions remain here.
Public profile: same identity, photo, biography, connection controls, documents
and portfolio layout; dashboard green/sage/white palette and readable labels.
The landing animation and student/employer dashboards are unchanged.

PRINTING
Each main tab has Print / Save PDF. Overview, Students and Employers print
their analytics, independent of the currently open employer approvals view.
Career Fairs retains the complete selected fair report and comparison.
Student analytics excludes the named directory. Print this page in the student
directory prints only its current filtered page, with filter and page labels.
It is explicitly not an export of the entire student roster.

DATA DEFINITIONS
Accounts: associated student authentication accounts, including accounts that
have not confirmed email or finished a profile. University/employer identities
are excluded. Cal Poly association uses the authenticated email domain or a
matching profile school; it is not an enrollment roster.
Email confirmed: Supabase authentication confirmation, not proof of enrollment.
Basics: username, major and class year entered. This is not the student's full
portfolio completion percentage.
Active: email confirmed and public profile/card activated.
Serial assigned: an existing issued or activated card record.
Connected students: unique students with recorded employer connections.
Company totals count each registered company once; approval requests count
individual recruiter accounts. One approved recruiter makes the company access
status Approved, even when a colleague still has a pending request.
Connections remain unique student-company-source relationships. Stage counts
are recorded employer milestones, not inferred stages or official placements.
Student-directory links are available only for active public profiles.
Charts count real records. No sample data or invented results are inserted.

ACCESS
New RPCs require a verified university administrator and scope data to that
administrator's school. The internal population helper is not executable by
anonymous or ordinary application users. The directory returns names, major,
class year and account/card/activity status, not emails, private biographies,
private documents, message content or recruiter notes. The analytics print
views exclude student names. Existing login/session isolation is retained.
Add students shares signup.html; it does not create accounts or send email.
Students confirm their own address, and previously installed automatic serial
assignment still handles eligible Cal Poly student accounts.

CHECK AFTER INSTALLATION
1. Open university portal: Overview, Students, Employers, Career Fairs.
2. Check student account totals against your actual student accounts, excluding
   the university and employer logins. Confirm incomplete accounts are counted.
3. Search/filter/page the directory. Only active profiles should be linked.
4. Add students -> Copy signup link. Confirm the link opens student signup.
5. Employers -> Approvals. Approve/decline a test request; analytics should
   refresh, with pending recruiter totals kept separate from company totals.
6. Overview -> click a career fair. It should open that fair's report.
7. Print preview each analytics tab and a filtered directory page. Save PDF.
8. Open your public profile and check bio, photo, opportunity text/tags, résumé,
   expandable experience/projects and connect/contact controls at desktop/mobile.
9. Opening these RPCs/pages from a student or signed-out session must not expose
   university reporting or the directory.

VALIDATION
Local checks pass across 38 HTML pages plus focused fair-report and population
tests: denominator units, setup state totals, major aggregation, empty data,
rendering of each new population view, directory escaping, pagination and
signup sharing. Live Supabase SQL execution, real account flows and browser
PDF layout were not performed from this workspace and need the checks above.
