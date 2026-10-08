TapID combined update v15 — includes v14 full-height grouped student/employer navigation and previous public-profile matching/career-interest updates.

Upload the website files from this ZIP together into the existing website repository. This is an incremental update, not a fresh installation.

New in v15:
- Larger university Overview / Students / Employers / Career Fairs tabs.
- Clickable, uncluttered account and connection totals.
- Overview uses the canonical engagement connection count; duplicate recruiter records for the same student/company/event are counted once.
- Student directory immediately below totals.
- Fourth student total is Connection participation (accounts with a connection / student accounts); no-account denominator displays a dash.
- Full-width college bars drill into that college's major bars, with Back to colleges.
- Monthly connection chart retained at a compact height.
- Company account directory includes all account statuses; employer engagement charts remain scoped to approved companies.
- Directory errors are preserved and reported rather than cleared by the surrounding page load.

SQL: No new database change is required for the visual update if the previous full-public-search SQL is already installed. If the directory reports that university_student_directory_filtered is missing, run tapid_student_directory_repair.sql, then refresh. It preserves university authorization and filters before paging. It requires the previous engagement analytics setup.
Edge Function: No redeployment needed for v15. Included function files are retained from earlier combined updates.

Validation: All 13 local test scripts pass, including college drilldown/back, directory ordering, clickable totals, canonical overview count and scoped company data. Tests use mocks. Live signed-in workflows, actual PostgreSQL execution and rendered browser appearance were not verified here.

Commit: Refine university analytics and restore grouped full-height navigation
