TapID Candidate Match flow update

1. Upload/replace these five website files in the GitHub repository root:
   employer-dashboard.html
   employer-criteria-search.js
   employer-criteria-search.css
   dashboard.html
   dashboard-navigation.css (new)

2. In Supabase Edge Functions, open the existing search-student-experience function.
   Replace its entire code with search-student-experience.ts from this package and deploy.
   Keep Verify JWT off as previously configured; the function validates the signed-in
   user token internally and checks university-approved employer access.
   Retain your existing secrets. No SQL migration or new function is needed.

Behavior:
- Dropdown filters are above the AI request.
- Candidate count and cards appear immediately below the AI request.
- Search history is collapsed below the cards.
- Without Clear search, requests refine the last displayed candidates.
- Clear search removes history, previous candidates and AI criteria, keeping dropdowns.
- Reset filters clears both the dropdown filters and the search context.
- Employer and student sidebars remain fixed on desktop, with an internally scrollable
  rail on short screens. Mobile uses a sticky horizontal navigation strip.
- The Check AI connection button has been removed.

Validation: All ten local test scripts pass, including forced follow-up scope,
zero-result refinement, reset behavior, layout order and existing authorization checks.
The generated single-file Edge Function passes the JavaScript syntax check.
API responses are mocked in tests. This package has not been deployed or browser-tested
on your live site.

Suggested commit: Improve Candidate Match search flow and persistent dashboard navigation
