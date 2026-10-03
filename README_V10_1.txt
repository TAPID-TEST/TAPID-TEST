TapID V10.1 — Pilot Relationship Layer
======================================

Purpose
-------
TapID begins when a student and employer connect. It helps both parties continue
that relationship and gives universities privacy-safe evidence of follow-through.
It does not replace career-fair registration, payments, booths, job applications,
or interview scheduling in the university's existing platform.

Deployment order
----------------
1. If V10 has not been installed, run tapid_v10_relationship_layer.sql.
2. Run tapid_v10_1_pilot_workflow.sql in the same Supabase project.
3. Upload all website files to the GitHub repository root.
4. Wait for Netlify to publish the new commit.

Employer experience
-------------------
- Guided visual relationship progression instead of a status dropdown.
- Recommended next actions based on the current stage.
- Action-needed filtering, priority, owner, follow-up date and promised next step.
- Private team notes remain separate from student-visible messages.
- One current employer-reported outcome per relationship; changes do not duplicate it.

University experience
---------------------
- Filter by event, employer, major, class year and connection date.
- Export the current filtered view as CSV.
- See connection, stage, outcome and follow-through metrics with source labels.
- Import event/employer reference data from CSV and manually match unresolved names.
- Never exposes student names, usernames, contact details, messages or recruiter notes.

CSV columns
-----------
Required: external_event_id,event_name,company_name
Optional: start_date,location,external_employer_id

Validation
----------
Run npm test. The smoke suite checks page presence, local links, inline JavaScript
syntax, role-sensitive features, migrations and required release artifacts.
