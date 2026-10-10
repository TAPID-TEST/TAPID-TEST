TAPID V23 — UNIVERSITY POPULATION RANKINGS AND CAREER FAIR WORKSPACE

This package INCLUDES the previous V22 employer statistics/approval fix. Use this package instead of uploading V22 separately.
Upload ALL 14 website files in this ZIP into the website root, replacing existing files and adding new ones. Commit, wait for deployment, then reload.
No new SQL or Edge Function changes for this update. Previously supplied university engagement/report/approval SQL must already be installed. V21 SQL provides named student rankings and the standardized major catalog if it has not been installed yet.

Changes:
- Student leaderboard is on Students, above the student directory.
- Employer leaderboard is on Employers, above the employer directory.
- Both rank the top ten across fairs/sources by default and allow choosing a single fair. Tied counts share a rank; repeat recruiter connections to the same company at the same fair are deduplicated. Rankings are separate from directory filters and remain visible without a directory search.
- Career Fairs now focuses on finding and reviewing events. Search by name, filter by event status or date range, and select View results.
- Add a career fair remains linked to the existing setup workflow.
- Removed duplicated KPI cards, both leaderboards and the extra student/employer analytics tabs from Career Fairs.
- The selected event has a compact results table for connections, participating students and employers, interviews and offers. These are event-specific results, not university account totals.
- Compare with another fair to see side-by-side counts and differences. Optional first 7/30/90-day results windows apply to recorded milestones. Completed-window comparison is available to avoid comparing mature results with incomplete windows.
- A summary table across fairs provides quick results review. CSV exports that table; Print report / Save PDF includes the selected event, comparison and summary.
- Previous fix included: employer KPI statistics, Approvals navigation independent of analytics loads, separate approval error messages, removal of the three nonworking quick-filter buttons, and resilient loading when fair outcome details fail.
- Unfiltered student/employer directories still wait for search or filter selection. Employer detail analytics remain expandable.

Validation: all 13 local suites, previous approval navigation/bundle checks, and new runtime tests for fair search/status/date filters, selection, comparison and leaderboard filtering passed. No signed-in live website or rendered browser verification was performed.
Suggested commit: Reorganize university rankings and career fair results; fix employer approvals

Developer note: versioned employer/fair entry scripts bundle shared dependencies. Regenerate the bundles after editing their shared source modules.
