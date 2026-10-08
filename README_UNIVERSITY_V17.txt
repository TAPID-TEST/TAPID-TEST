TapID university directory update v17

Upload all eight website files together to the existing website repository. This includes the university v16 refinements. No new SQL or Edge Function changes needed.

Employers now follows Students: totals, open filter-first directory, full-width charts. Approvals remains separate.
Student and company directories display no rows without a search or filter. Clearing all filters clears rows and pagination. Student queries are skipped entirely until a filter is applied. Existing student pagination remains 50 per page; employer pagination is 25 per page over the already-authorized university report.
Employer filters: company name, access status and connection activity. Zero-connection links from Overview select approved companies. Engagement bars filter the company directory by zero, 1–5, 6–20 or 21+ connections. Bins do not overlap. Company counts are not student or connection totals.
Connections by employer removed. Employer engagement distribution summarizes approved companies by connection count; Connections by major and monthly employer activity are retained as full-width charts. Monthly chart height is capped.

Validation: all 13 local test scripts pass. Additional checks cover no-filter/no-student-query, clearing rows, zero-connection deep links, bucket boundaries, and a 61-company directory split across three pages. Tests use mocks; live browser rendering and signed-in workflows were not verified.

Commit: Match university employer layout and show directories only after filtering
