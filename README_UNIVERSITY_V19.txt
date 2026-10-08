TapID university refinement v19
Upload all ten website files together into the existing website repository. Previous university updates are included. No Edge Function changes.

Employer filters: labeled company name, approval status, connection activity, major reached and career-fair connection filters; sort by connections, students reached, most recent connection or company name. Quick filters: approved companies, zero connections, recently connected. Major and event filters are combined and scoped to the authorized university report. Career-fair connections means recorded connections at that fair, not just attendance.
Company rows show students reached, connections, majors reached and View analytics. Single matching company automatically expands; multiple results remain compact. Directory stays empty without search/filters.
Approval search field widened to avoid truncating its placeholder.

Career-fair page first requests university_fair_report_v2 and falls back to university_fair_report only for a missing-function schema-cache error. It does not fall back on permission errors. Existing report data can render without the v2 end-time wrapper; end-time classifications are less complete in fallback mode. The page displays that limitation.
Optional SQL: run tapid_fair_report_timing_repair.sql in Supabase SQL Editor to install the timing wrapper, then refresh the website. Requires the existing base university_fair_report and career_fairs schema from previous updates. SQL was not executed against the live database here.

Validation: all local test suites passed. Added tests cover combined company major/event filters, sort order, detail discovery/auto-expansion, missing-v2 fallback and no fallback on authorization failures. Browser rendering and live workflows remain unverified.
Commit: Improve employer filters and restore compatible career-fair reports
