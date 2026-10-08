TapID university company details v18
Upload all eight website files together into the existing website repository. Includes previous university directory/overview changes. No new SQL or Edge Function change required.

The Employers analytics page now consists of totals and an open filter-first employer directory. The standalone engagement, major and monthly charts are removed.
Search or apply a filter, then click a company row to expand its details in place. Details show students reached, connections, number of recorded majors reached, connections by major, recruiter account/approval counts, recent connections and students reached, last connection date, career-fair sources/activity and recorded interviews/offers/accepted offers/internships/hires.
Data is scoped to the authorized university report and selected company. Major bars count connections, not unique students. The count of majors excludes unspecified entries. Fair activity lists only fairs with recorded company connections; it is not a full attendance roster. Outcomes are recorded milestones rather than inferred results.
The directory remains empty without filters and remains paginated at 25 companies per page. Native expandable rows support keyboard and touch. Clearing filters hides rows again.

Validation: all 13 local test scripts pass, with added company-detail checks for escaping, major counts, outcome counts and empty states. Browser rendering and live signed-in workflows remain unverified.
Commit: Move university employer analytics into expandable company directory entries
