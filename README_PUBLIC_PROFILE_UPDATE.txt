TapID combined workspace audit update · 8 October 2026

This replaces the previous combined update and includes the example-prompt fix,
public-profile Candidate Match, narrative Career interests and earlier dashboard fixes.
It is an incremental update for the existing TapID repository and Supabase schema,
not an installation for a new database. Keep existing config.js, secrets and accounts.

INSTALL
1. Run tapid_full_public_search.sql in Supabase SQL Editor, then DEPLOYMENT_CHECK.sql.
   The check is read-only. All installation and permissions columns should be true.
   This SQL requires the previously installed university engagement/fair workspace.
2. If you have not installed the previous combined public-profile search update,
   replace the existing search-student-experience Edge Function with the included
   search-student-experience.ts and deploy. Its code is unchanged from that update.
   Retain the existing secrets and Verify JWT setting (off); the code checks the
   caller token and recruiter approval internally. No API keys belong in GitHub.
3. Upload ALL website files listed below to the repository root together, retaining
   their filenames. Include the two new workspace-* files. Cache tags are updated.
   Tests and the modular supabase source can also be committed for future maintenance.
4. Wait for GitHub Pages to finish deployment and refresh the browser.

WEBSITE FILES
  dashboard.html
  student-home.js
  dashboard-navigation.css
  dashboard-theme.css
  employer-dashboard.html
  employer-criteria-search.js
  employer-criteria-search.css
  profile.html
  career-interests.js
  career-interests.css
  workspace-polish.css
  workspace-review.js
  university-dashboard.html
  university-students.html
  university-employers.html
  university-fairs.html
  university-fair-setup.html
  university-fair-setup.js
  university-fair-setup.css
  university-admin.html
  account.html
  university-population-workspace.js
  university-workspace-ui.js
  university-report-workspace.js
  university-employer-approvals.js
  fair-report-model.js

STUDENT
- Seven primary destinations: Home, My TapID, Career interests, Career Fairs,
  Connections, Messages, Notifications. All ten profile-editing sections are
  accessible inside My TapID, with Preview & share and existing deep links retained.
- Compact desktop rail without internal scrolling. Very short screens/mobile use
  a horizontal navigation row; the content itself remains scrollable.
- Shared typography, buttons and spacing. Stable notification rows/badges retained.
- Home keeps total connections and the latest five. Setup now shows three next
  steps rather than a percentage, using the written Career interests field.
- Recruiting updates remain available from Connections.
- Free writing prompts, legacy preference retention and public visibility preserved.

EMPLOYER
- Shared reading scale, card rhythm and compact sidebar retained.
- Student detail shows public career interests and two experience/project highlights,
  public bio/skills and existing full-profile/résumé/message actions.
- Private notes stay prominent; priority and reminder settings are secondary.
- A dated reminder requires a task. The first outbound message advances a New
  connection to Contacted and does not move later stages backwards.
- Notifications now separate unread alerts from outstanding requests/reminders.
  Mark event alerts read clears event alerts. Messages clear through their thread.
- Candidate stage cards retain the responsive grid without horizontal scrolling.
- Hard filters stay above Describe your ideal candidate, results directly below,
  and search history last. Clear search resets context while keeping hard filters;
  Reset filters clears everything. Follow-ups stay within prior displayed results.
- The updated example requests three juniors for a project engineer internship,
  comparing field work, estimating, Bluebeam and project leadership using public
  TapID examples. It is initialized in JavaScript and restored by Clear search.
- Match cards show a public source quote, distinguish a specific example from a
  stated claim, and list criteria not shown on the public profile.
- Authorized public-profile data includes experience, projects, skills, leadership,
  organizations, recommendations, certificates, interests, public outcomes,
  public media captions and link metadata. Private contacts/notes/messages stay out.
- The existing authorization fix distinguishes missing session, unverified recruiter
  and database permissions. Company approval is not treated as recruiter approval.

UNIVERSITY
- Click major/class chart labels to filter the student directory. College drilldowns
  include participation rates and a direct directory link. A college filter is now
  supported on the server before paging; Clear filters resets the directory.
- Zero-connection groups with student accounts retain meaningful 0% participation
  instead of disappearing. No division-by-zero percentage is shown.
- Click an employer in the chart to scope major reach and open employer details.
- Approval actions explicitly say Approve recruiter or Decline recruiter.
- Fair report selector groups completed, past, in-progress, upcoming and undated
  events. Initial report defaults to the latest completed/past event where possible.
- Comparison choices exclude future fairs. Choosing a comparison starts with equal
  30-day windows and completed observation windows; other windows remain selectable.
- Printing offers a summary or summary plus detailed appendix. Active comparisons
  are included; chart labels remain visible in print.
- Fair setup is now Details → Companies → Review. CSV preview/duplicates, manual
  entries, account matching, drafts and failure recovery remain available.
- Publishing requires a start time and location; end time must follow the start.
  The review screen shows dates, location, company count and linked account count.
  Unlinked companies are flagged because their recruiters cannot be notified until
  linked. Recruiter approval remains separate, in Employers.

CHECKED LOCALLY
13 test scripts pass, covering 40 HTML pages, links/IDs/inline script syntax, public
privacy and evidence, approved-user guards, contextual search, fair import/wizard,
notification clearing, analytics aggregation/zero states and existing workflows.
The standalone Edge Function also passes the JavaScript/module syntax check.
Tests use mocked Supabase and AI/PDF responses. There is no browser installed and
no authenticated live GitHub/Supabase connection here. PostgreSQL migration execution,
real API billing/connectivity, rendered appearance and signed-in workflow tests
have NOT been verified. This package is prepared, not deployed.

LIVE CHECKS AFTER DEPLOYMENT
- Student: all primary links, each My TapID editor, direct #experience link, preview,
  notification read/mark-all-read, five latest connections and saved Career interests.
- Employer: accepted connection, public/private profile toggles, message moving a
  New connection to Contacted, interview not rolled back by messaging, reminders,
  favorites, same hard filters in Connections/Match, new example after Clear search,
  first search then refinement then independent search after Clear search.
- University: click major/class/college filters and confirm directory counts/page
  scope, create a draft then publish with linked employer, verify student/employer
  event notification, compare two past fairs and preview both report print modes.
- Check 1366×768 desktop, smaller laptop heights and phone layouts after deployment.
- Automatic email delivery and scheduled background reminders still depend on the
  existing deployed email function and scheduler; this update does not deploy them.

SEARCH LIMITS
Up to 30 public candidate profiles per evidence comparison. PDF extraction is
limited to 3 MB/six pages per document and 60 attachments per comparison. Scanned
images are not OCR'd, photos are not interpreted, and linked external websites are
not crawled. Public captions/link metadata remain searchable. Unreadable documents
are reported. Career wishes are not proof of completed experience.

SUGGESTed commit
Unify TapID workspaces and improve candidate review and fair reporting
