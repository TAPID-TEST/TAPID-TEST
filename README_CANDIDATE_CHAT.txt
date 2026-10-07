TapID conversational Candidate Match — October 7, 2026

NO NEW SQL REQUIRED
This update uses the employer_search_documents and claim_employer_search functions already installed.

DEPLOY
1. Supabase > Edge Functions > existing search-student-experience > editor.
   Replace all editor code with search-student-experience.ts, then Deploy updates.
   Keep Verify JWT OFF; the function verifies the bearer token itself.
   Keep OPENAI_API_KEY in Supabase secrets, never GitHub.
2. GitHub repository root: replace these three files from this ZIP:
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   Commit: Add conversational AI candidate search and connection check
3. Wait for GitHub Pages deployment and refresh the employer dashboard.
4. Candidate Match > Check AI connection.
   A verified status requires a real completed response from OpenAI using your configured key and model.
   Invalid key, API billing/quota, model permission and provider errors get distinct messages.
   The check consumes one of the existing search allowance requests and makes a small paid API call.

TEST IN THIS ORDER
Check AI connection.
Ask: Find all civil engineers.
Then: Of these, who has the most estimating experience?
Start New conversation.
Ask: Find three juniors from the Fall Career Fair with at least two internships.
Use event/stage/year/major dropdowns or type the constraints in your message.

BEHAVIOR
Filter-only requests return all matches without requiring an experience criterion or work ranking.
Lists are alphabetized and display 25 cards at a time; Show more displays the next 25 without another API call.
Experience requests compare public profile entries and available public selectable-text resumes.
Reasons cite actual source entries, including validated excerpts for distinct resume internships.
Follow-ups carry the last eight successful turns during this page session.
"Of these" intersects last result IDs with freshly authorized connected public profiles.
New conversation clears history, results and filters. Reloading also clears conversational history.
Changed dropdowns override remembered constraints, including an explicit All choice.
Only company-connected students with active public profiles are searched.
Private recruiter notes and message bodies are not AI evidence.
No signup, account, university, landing-page or database changes are included.

VALIDATION AND LIMITS
All ten local test suites passed; flattened function syntax passed.
Tests include the actual UI submit path with follow-ups/reset, filter-only major search,
previous-result authorization, health success/error paths, exact internship excerpts and legacy flows.
Provider and PDF calls in tests are mocked. No signed-in live API test or real-browser visual check was possible.
Do not treat this package as proof that your live API key works: use Check AI connection after deployment.
Work-evidence comparisons remain limited to 30 filtered profiles; narrower filters are requested above that.
Up to 1,000 connected public profiles can be listed without work assessment.
Top N max 10; all/list requests can return the full filtered list.
PDF support is selectable-text, max 6 pages and 3 MB. No OCR.
Unreadable resumes do not remove a profile unless resume reading was explicitly required.
Searches remain 6/minute and 40/UTC day, including health checks.
