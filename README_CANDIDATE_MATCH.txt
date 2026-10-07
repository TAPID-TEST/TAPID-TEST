TAPID — CANDIDATE MATCH AND CLEAN CONNECTIONS

FIX FOR THE SCREENSHOT
The published employer page called my_fair_workspace, which was missing from
Supabase. Its failure interrupted dashboard rendering, leaving the default
company name, Pending badge and empty connections. The combined SQL installs
that missing fair update. The dashboard now handles a fair-only failure locally,
so it cannot discard the already-loaded recruiter identity and connections.
Hidden approval notices also stay hidden; the blank green strip is removed.

DEPLOY IN THIS ORDER
1. Supabase SQL Editor: run ALL of tapid_candidate_match.sql.
   It includes the missing fair migration, matching functions, and favorites.
   It is designed to be rerun after the previous matching SQL and preserves
   accounts, profiles and connections. It attempts to schedule fair reminders;
   if Cron is unavailable, enable it then run tapid_fair_reminder_schedule.sql.

2. Supabase Edge Functions: deploy or REPLACE search-student-experience.
   Browser editor: paste ALL of search-student-experience.ts into index.ts.
   Gateway JWT verification should be OFF. The function verifies auth.getUser
   itself and the SQL function independently verifies the recruiter.
   Existing secret OPENAI_API_KEY is required. Optional OPENAI_SEARCH_MODEL
   overrides default gpt-4.1-mini. Never put secret values into GitHub or chat.
   The hosted SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are used on the server.
   CLI alternative:
   supabase functions deploy search-student-experience --project-ref ngdamuvnvuadwbfsaohi --no-verify-jwt

3. GitHub: upload and commit together:
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   fair-dashboard.js
   Also include dashboard.html if you have not published the student fair fix.
   Suggested commit: Separate Candidate Match and add connection favorites
   SQL and TypeScript are backend files, not website assets needed for Pages.

HOW IT WORKS
Connections remains a simple browsing page: search, major, year, event, favorite
filter, and action-needed toggle. Stage/priority are under More filters. A star
saves a favorite for the signed-in recruiter; it survives refresh and does not
change the student's stage or priority. Other recruiters have their own favorites.

Candidate Match is a separate sidebar tab. Write the role/work criteria and
optionally the fair, year, major and top N. Scope dropdowns override the matching
part of the natural-language request. Example:
 Show my top 3 juniors from the Fall Career Fair with field work, quantity
 tracking, and Bluebeam. Include their resumes.

The first AI call interprets the supported work criteria, event, year, major,
all/any logic, whether to read resumes and the requested number (1–10, default 3).
Event aliases must resolve to one actual connected fair; ambiguous names cause
an explicit choice request. An unavailable event/year never expands to everyone.
No work criterion means the employer is asked what experience matters for the
role. We do not invent a definition of "best" from a fair or class year alone.

The backend applies exact scope filters to the company's connected, active,
public profiles. Public visible experiences/projects/skills are retrieved and
matched using task phrases/synonyms. When resumes are specifically requested,
public PDF files are downloaded from the student's own storage folder and text
is extracted on the server. Scanned PDFs, PDFs over 3 MB or 6 pages, encrypted/
unreadable files are excluded with a visible count. No OCR is included.

A second AI call compares the already-matched public evidence to the explicit
work criteria: concrete work performed, a stated skill, or unsupported evidence.
It receives anonymous candidate references and public excerpts; no profile
names, contacts, photos, private notes or messages are deliberately included.
Every returned candidate, criterion and evidence citation is validated against
the supplied sources. Invalid/unfinished AI comparisons fail visibly and do not
produce an invented shortlist. Existing quoted excerpts are displayed rather
than AI-written biographical claims.

Results are ordered by criteria coverage, evidence strength, supporting work
entries, and finally name for ties. This is a review aid, not a hiring decision,
a total-years calculation, or a prediction of personality or office preference.
Each card states why it matches, with expandable excerpts and buttons to view
the student, open their public resume if available, and favorite them.
If fewer than N meet the criteria, fewer than N are shown. Hidden data stays out.
The comparison covers at most 30 evidence-matching profiles, up to 40 public
resumes and 1,000 public connected profiles. Larger groups request narrower
filters; they are not silently cut down before choosing the shortlist.

SUPPORTED WORK CRITERIA
Field work, office/coordination, estimating, cost control, scheduling, RFIs,
submittals, change orders, quantity tracking, safety inspections, environmental
work, design, project coordination, data analysis, research, Bluebeam, AutoCAD,
Excel, Revit/BIM. Up to eight requested criteria. Unsupported requirements prompt
refinement rather than being silently ignored. Health, protected traits and
personality predictions are not used as matching criteria.

COST AND PRIVACY
Maximum six search requests per recruiter per minute and 40 per UTC day. A
completed match request can use TWO paid API calls. No automatic paid retries.
Both calls send store:false. Search text/quotes are not stored in the usage table.
The interpretation call uses the request plus available fair/year/major labels;
the comparison call uses only matching public work excerpts with anonymous refs.
The PDF text is parsed on the server, and only relevant excerpts enter comparison.
Profiles may contain identifying details in their work descriptions; therefore
public excerpts should still be treated as student information. Do not claim
perfect anonymization or zero provider retention. No new emails are sent.

TEST AFTER DEPLOYMENT
- Verified employer identity loads correctly, even if fair listings fail.
- Connections has no AI composer. Candidate Match has its own sidebar tab.
- Favorite a student, refresh and use Favorites filter; unstar and verify removal.
- The same candidate can be opened and favorited from Candidate Match.
- Search the actual Fall fair and Junior year with concrete job criteria.
- Compare the applied filter chips to the request; inspect each explanation/quote.
- For a resume request, ensure a readable public PDF is included; unreadable
  and private resumes must not be silently treated as read.
- Hide a public work section, rerun, and confirm its evidence disappears.
- Another company's unconnected student must never appear.
- A pending employer and logged-out request must be rejected by the server.
- Check an ambiguous fair name, fewer than three matches, unsupported criteria,
  missing function, invalid API key, and no role criteria.
- Normal messages, candidate save/close, pipeline, requests and fair alerts work.

VALIDATION STATUS
Seven local suites pass: page wiring, reports, population, fair setup, onboarding,
fair alerts, and Candidate Match. The new suite covers the missing fair function,
company/role authorization wiring, public data scope, PDF download ownership,
query scopes, ambiguous fairs, top-N output, evidence references and escaping.
API calls and PDF parsing are mocked in these tests. Actual SQL execution,
Supabase Edge deployment, paid model calls, PDF library runtime and signed-in
browser workflows still require live validation. Browser binaries and npm
registry access were unavailable locally. No live accounts were modified here.

References:
https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses
https://supabase.com/docs/guides/functions/auth
https://github.com/unjs/unpdf
