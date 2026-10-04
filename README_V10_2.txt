TapID V10.2 — Consolidated Employer Workflow Fix

1. In the correct Supabase project, open SQL Editor.
2. Paste and run tapid_v10_2_consolidated_fix.sql.
3. Upload the V10.2 web files to the repository root and commit them.
4. Let Netlify publish the main branch.

What changed
- Company Profile fields now have a compatible database schema.
- Employer Home separates follow-ups due now from upcoming follow-ups.
- Due and overdue follow-ups appear in Notifications.
- Event Results expands into useful relationship, outcome, cohort, and student detail.
- Candidate records use clearer relationship language, expand on desktop, and close after save.
- CSV import and employer matching are clearly labeled as optional advanced integration tools.

Quick verification
- Save Company Profile, including Careers website.
- Set one follow-up for today and another in the future.
- Confirm Home shows one due now and one upcoming.
- Confirm the due reminder appears under Notifications.
- Open Event Results, expand an event, and open a student.
