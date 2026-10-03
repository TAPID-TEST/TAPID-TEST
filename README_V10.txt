TapID V10 — Relationship Layer

Purpose
- Preserve the existing student experience.
- Stop duplicating career-fair registration, payment, booth, job and application workflows.
- Focus employers on the student relationship after an introduction.
- Focus universities on privacy-safe, transparent post-connection evidence.

Deploy order
1. Run tapid_v9_1_flow_and_outcome_fix.sql if it has not already been run.
2. Run tapid_v10_relationship_layer.sql in the correct Supabase project.
3. Upload the website files and publish through Netlify.

Employer changes
- Relationship-first home screen and pipeline.
- Relationship owner, next action and due follow-up.
- Contacted and Screening stages.
- Read-only event results; no fair registration or approval duplication.

University changes
- Aggregate relationship funnel and employer follow-through.
- Explicit data definitions and privacy boundaries.
- Integration/governance page replaces event creation and employer approval.
- Existing card issuance remains available.

Compatibility
- Existing connections, messages, outcomes, profiles and event names are preserved.
- Existing career_fairs tables are not deleted, so older records and student views remain compatible.
