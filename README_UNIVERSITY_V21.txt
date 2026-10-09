TAPID V21 — SEARCHABLE MAJORS AND VISIBLE CAREER-FAIR LEADERBOARDS

1. Extract this ZIP. Upload ALL 13 website files to your website root, replacing the old HTML pages and including the new named JavaScript/CSS files. Commit and allow Netlify deployment to finish.
2. Run tapid_major_fair_update_v21.sql in Supabase SQL Editor. This includes v20 major validation/report upgrades; no need to run v20 separately. Existing university/engagement/fair setup tables and functions must already be installed.
3. Reload the deployed website. Career Fairs should say “Career-fair results”, have an “Add a career fair” button and show both leaderboards above the report tabs. If it still says “Set up a career fair”, the older HTML is being served; verify the deployed commit contains university-fairs.html from this ZIP.
4. Signup, onboarding and profile editing should show Search Cal Poly majors, a selection dropdown and a read-only assigned college. A plain Major text box indicates the old HTML.

No Edge Function changes.

Major behavior:
- The same searchable controlled catalog is included on signup, onboarding and editing. Typing in the search field only filters choices; only selecting a catalog entry saves a major.
- Cal Poly choices load immediately from the included catalog; an available program-options RPC may extend the school's catalog. Other universities need their own school-specific catalog.
- Signup retains the selected major in auth metadata; onboarding confirms it and saves it to the profile using the existing profile flow.
- College is derived from the selected major, shown immediately and mapped in the university reporting table; no independent user-editable college field or duplicated college column.
- Every selectable program has an explicit mapping. Joint programs use Interdisciplinary Degree Programs; report mappings stay consistent with the displayed classification. Degree/campus distinctions are not introduced by this update.
- Exact case/whitespace matches are normalized; unknown legacy abbreviations are preserved for review, not guessed. SQL blocks new unlisted majors.

Leaderboard behavior:
- Employer and student rankings sit above report tabs and remain visible when tabs change.
- Choose a fair to scope ranks. Top 10, shared ranks for ties; repeated recruiters connecting the same student/company/fair count once.
- Authorized university SQL adds student names; fallback reports may show anonymized student labels until SQL is installed.
- Existing filters, comparison, CSV and detailed outcome charts remain available.

Checks: all 13 existing local suites passed, plus specific search/selection/college mapping, late-response preservation and leaderboard placement/ranking tests. Live SQL and signed-in browser behavior have not been verified.
Suggested commit: Fix searchable majors, automatic college mapping and visible fair leaderboards
