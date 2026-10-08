TapID combined Career interests + public-profile search + student dashboard update

This package includes the previous Candidate Match flow update.

DEPLOY IN THIS ORDER
1. Run tapid_full_public_search.sql in Supabase SQL Editor.
   It replaces the employer search RPC and adds one private helper.
   It does not delete accounts, change approvals, or alter existing student profiles.
2. Open the existing search-student-experience Edge Function in Supabase.
   Replace all of its code with search-student-experience.ts and deploy.
   Retain your existing secrets and existing Verify JWT setting (off).
   The function validates the user token and approved-company access internally.
3. Upload these TEN website files to the GitHub repository root:
   dashboard.html
   student-home.js (new)
   dashboard-navigation.css
   dashboard-theme.css
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   profile.html
   career-interests.js (new)
   career-interests.css (new)

CHANGES
- Employer dashboard uses the same base font, heading/button/card sizing and
  desktop navigation row dimensions as student and university styling.
- Page-wide employer enlargement overrides are removed; recruiting components
  retain their layouts while using the shared text scale.
- Native controls inherit the dashboard font for a consistent rendering style.
- Opportunities is now Career interests with three free writing prompts (1,200
  characters each), optional practical details, and one public visibility control.
- Public TapID presents answers in paragraphs under What I’m looking for.
- Existing choices remain saved; legacy profiles get a prose fallback. Clearing
  the narrative answers does not cause old checkbox tags to reappear.
- AI can match explicitly stated goals but cannot use goals alone as proof of
  demonstrated work experience.
- Student sidebar stays visible and fits without an internal vertical scrollbar.
  Smaller desktop heights use compact rows; short landscape screens and mobile
  use visible horizontal navigation.
- Notification badge has a reserved column and no longer wraps navigation rows.
  Local notification links open the intended section without reloading the page.
  Link/visited/active styles and reserved scrollbar width keep appearance stable.
- Student home network panel shows the total and five newest connections.
  Each row opens that person's existing connection details and private notes.
- Candidate Match reads public bio, complete experience/project text including
  lessons learned and team size, skills, organizations/leadership/accomplishments,
  certifications, submitted recommendations, career interests, public verified
  outcomes, professional link metadata, and public media captions.
- Public recommendation and project/certificate PDFs contribute extracted text.
- All row-level public flags and parent section visibility flags are respected.
  Access remains restricted to the approved employer's connected students.
  Writer private contacts, messages, and private team/student notes are excluded.
- Ambiguous comparisons such as biggest entrepreneurship project prompt a short
  question. Questions appear under the AI input, not only inside collapsed history.
- Answering an initial clarification searches the selected connection pool;
  follow-ups after successful searches stay within the prior displayed candidates.
- Clear search resets AI/history/results while keeping hard filters.
  Reset filters clears both hard filters and search context.
- Hard filters remain first, AI second, candidate count/cards below, history last.

LIMITS / VERIFICATION
PDF extraction is limited to 3 MB and six pages per document, 60 attachments per
comparison, and up to 30 candidate profiles for evidence comparison. Unreadable
PDFs are reported. Image-only/scanned documents are not OCR'd, images themselves
are not interpreted, and external linked websites are not crawled. Public captions
and link metadata remain searchable. Recommendations are attributed statements.
Twelve local test scripts pass, including the new student/public evidence paths.
The generated Edge Function passes the syntax check. API/PDF responses in tests
are mocked. No live Supabase migration, deployment, PostgreSQL execution or browser
render test has been performed from this workspace.

Suggested commit:
Unify dashboard styling and redesign career interests

For only this latest styling fix, replace these five website files:
dashboard-theme.css, dashboard-navigation.css, employer-criteria-search.css,
employer-dashboard.html, dashboard.html. No additional SQL or Edge Function change
is needed if the previous Career interests update is already installed.
