TapID V1 — Sprint 6: Employer Connection Portal

WHAT THIS SPRINT ADDS
- Separate employer/recruiter signup and login.
- Company-normalized employer accounts.
- Employer portal with a simple total connection count.
- Current career fair/event setting; new connections inherit it automatically.
- When a logged-in recruiter opens a live student TapID profile, "Connect & Save Candidate" appears.
- That single action creates a mutual connection:
  1) the student is saved to the employer portal, and
  2) the recruiter/company appears in the student's existing My Connections list.
- Employer portal shows connected students, major/year/event, full TapID profile access, resume access, private company notes, and a lightweight status: Connected / Follow Up / Interview / Offer / Passed.
- Recruiters at the same normalized company can see the same company candidate list.
- Employer connection records are NOT publicly readable. The schema is ready for a future university aggregate analytics layer without exposing individual interaction records to the public.

BACKEND FIRST
1. Supabase -> SQL Editor -> New query.
2. Run sprint6_backend_patch.sql.
3. Confirm Success.
4. Redeploy this whole folder to the same Netlify site.

TEST FLOW
1. Keep your existing student TapID active.
2. Open Employer Portal from the homepage.
3. Create a test recruiter account (example company: Kiewit).
4. In the employer dashboard, set Current Event to "Fall Engineering Career Fair".
5. While still signed in as that recruiter, open the student's TapID public URL on the same browser/device.
6. Confirm the public profile shows "Connect & Save Candidate" instead of the ordinary visitor connection button.
7. Click it and confirm it changes to "Connected ✓".
8. Return to Employer Portal. Confirm the student appears and the total connection count is 1.
9. Open the student. Confirm View Full TapID Profile works and View Resume appears when the resume is public.
10. Add a private recruiter note and change status to Follow Up. Save, close, reopen, and confirm both persist.
11. Log out of the recruiter account and log in as the student.
12. Confirm My Connections now contains the recruiter/company and the event name.
13. Optional company-sharing test: create a second recruiter account using the exact same company spelling/casing variant, connect/save or log in, and confirm company-level candidates are visible to recruiters belonging to that normalized company.

PRODUCT SCOPE DECISION
Student side stays intentionally simple: connect, keep the people you meet, and see a total connection count. Employer side is candidate management. Deeper analytics are reserved for the future university aggregate layer.
