TapID V3 — Production Candidate

TapID is a professional identity, career-fair connection, and aggregate
outcomes platform for students, employers, and universities.

This release includes:
- Student identity, public profile, QR/NFC URL, privacy center, optional photo,
  résumé, evidence-backed work, recommendations, and career outcomes
- Account recovery, email/password changes, and account deletion
- Employer verification, official career-fair registration, connection
  requests, candidate workspace, private notes, and recruiter signals
- University-managed career fairs, employer approvals, card issuance, and
  aggregate engagement, request-conversion, and outcome reporting
- Verified-only employer candidate access and university administration
- Alumni continuity on the permanent student profile
- Private Supabase Storage access through signed URLs
- Netlify security headers and dependency-free smoke tests
- A complete three-role acceptance-test matrix in TESTING.md

Before deployment:
1. Read DEPLOYMENT.md.
2. Apply tapid_v2_production_migration.sql after the existing Sprint migrations.
3. Apply tapid_v3_hardening_migration.sql.
4. Run `npm test`.
5. Run tapid_v3_verification.sql and confirm the required functions/policies.
6. Deploy the complete directory to Netlify.
7. Follow TESTING.md with dedicated student, employer, and Cal Poly accounts.

The Supabase value in config.js is a browser publishable key. Never place a
service-role or secret key in this repository.
