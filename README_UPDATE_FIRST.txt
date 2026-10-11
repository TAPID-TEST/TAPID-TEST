TAPID V24 — COMPACT UNIVERSITY ADMINISTRATION

Includes the previous V23 university employer/student/career-fair update. Upload ALL 18 website files from this ZIP, then run tapid_university_administration_v24.sql in the Supabase SQL Editor. No Edge Function change. The SQL also aligns existing card issuance with recognized university-name aliases.
The SQL adds two read-only university-scoped functions for student/card lookup and the latest 50 card records. Existing university engagement analytics/card issuance SQL is required. Prior V21 SQL remains needed for named rankings and the canonical program catalog.

Administration:
- One Administration title and university label. Removed repeated administration banners and large empty card layout.
- Four section buttons: Account access, Majors & colleges, Cards & activation, Card activity. Only the selected workspace is shown.
- Account access displays the verified current university account and scope. This release does not introduce staff invitation/role management, editable university settings or a general audit log.
- Program catalog is searchable/filterable by college. Reads the canonical program-options function; Cal Poly's packaged catalog provides fallback if that function is unavailable. The catalog is read-only in Administration; updating it uses the existing controlled program update.
- Student lookup returns at most 20 same-university matches and shows profile activation plus existing card serials/status/dates. Issuance form opens only after selecting a student; username is read-only. Existing serial uniqueness and verified-university checks are retained.
- Card activity shows the latest 50 issuance records and their current status/activation date. It is a card-record view, not a log of every historical action.
- Existing legacy CSV import and employer matching remain collapsed; matching data loads when opened. Import failure cannot prevent the main account/catalog workspace from loading.
- Career-fair creation lives on Career Fairs. Back to overview and employer-approval links route to their existing pages.

Previous V23 fixes included: employer KPI statistics, independent Approvals navigation, removed quick-filter shortcuts, Student/Employer leaderboards on their own tabs, directory filters, event search/status/date filters, fair result review/comparison, CSV and printing.

Validation: 13 existing local test suites, V23 runtime checks and administration-specific tests passed. Card selection, escaping, issuance payload guards and bounded university-scoped SQL interfaces were checked locally. SQL was not executed live; no signed-in or rendered browser verification performed.
Commit: Simplify university administration and add scoped card lookup
