TapID employer workflow update — October 7, 2026

DEPLOY IN THIS ORDER
1. Supabase SQL Editor: paste the entire tapid_employer_flow.sql file and Run.
2. Supabase Edge Functions: open the EXISTING search-student-experience function.
   Replace its editor code with the entire search-student-experience.ts file and Deploy updates.
   Keep Verify JWT OFF. The code verifies the bearer token itself and the database checks approved employer access.
   Keep the existing OPENAI_API_KEY secret. Do not put secrets in GitHub.
3. GitHub: upload and replace these three website files in the repository root:
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   Commit message: Simplify employer workflow and expand AI candidate matching
4. After Pages finishes deploying, refresh the employer dashboard.

WHAT CHANGED
Larger typography, cleaner cards, less repeated copy.
Home: Requests, Unread messages, Reminders due, Connections.
Reminders: one dated list with Today/Overdue/future dates and a Done button.
Student: public photo (or initials), larger identity and bio, TapID/resume/message links,
         one candidate stage selector, private notes, optional reminders and assignment.
Candidate stages: New, Contacted, Under review, Interview, Offer, Hired, Closed.
New connection is automatic. The first employer message moves New to Contacted.
Review/interview/offers/hiring remain deliberate choices; they are never inferred from a profile view.
Sending messages never moves a later-stage candidate backward.
Notes-only saves do not overwrite a stage updated by another recruiter.
Existing follow-up-planned entries display in New; internship/accepted-offer entries group in Offer.
Their original recorded outcome stays intact unless the employer deliberately changes the stage.

CANDIDATE MATCH
Same filters as Connections: search, major, class year, event, stage, priority,
Favorites and Action needed. Filters are checked server-side against the company's connections.
Event+stage+priority must match the same connection, preventing accidental cross-event matches.
Written requests can also specify event/year/major/stage. Explicit dropdown values take precedence.
Free-form objective work requirements now include internship counts, industries, projects and tools.
AI reads public work evidence for the filtered group and returns cited reasons for the shortlist.
Two internships requires separate internship entries, not two quotes from one entry.
No private recruiting notes/messages go to the AI. Their contents are not search evidence.
Only unread-message presence contributes to the Action needed filter.

TRY
Find 3 students with at least two internships. Explain why each matches.
Find juniors from the Fall Career Fair with field coordination and Bluebeam experience.
Find candidates under review with bridge construction experience.

LIMITS / VALIDATION
All nine local test suites passed; function source passed JavaScript syntax checks.
Tests cover free-form requests, distinct internship evidence, same-event filter scopes,
private/public access guards, automatic contact progression and existing dashboard flows.
AI/provider calls and PDF parsing in tests use mocks. SQL guards were inspected statically.
No authenticated live deployment test or browser screenshot validation was possible here.
The current comparison supports up to 30 profiles after filtering; narrow the group if larger.
It never silently drops the rest of the group. Resume reading is selectable-text PDF only,
up to 6 pages and 3 MB; unreadable PDFs are reported. No OCR.
Top N defaults to 3, maximum 10; exact evidence may yield fewer matches.
Rate limits remain 6 requests per minute and 40 per UTC day.
Unsubstantiated or personal-trait requirements are not guessed.

SOURCE AND TEST FILES
The ZIP also includes modular function source and modified tests for reproducible development.
The three website files are the only files required to publish the UI update.
The SQL and Edge Function updates are both necessary for the new behavior.
