TapID V2 — Production Candidate

TapID is a professional identity, career-fair connection, and aggregate
outcomes platform for students, employers, and universities.

This release includes:
- Student identity, public profile, QR/NFC URL, privacy center, optional photo,
  résumé, evidence-backed work, recommendations, and career outcomes
- Account recovery, email/password changes, and account deletion
- Employer verification, official career-fair registration, connection
  requests, candidate workspace, private notes, and recruiter signals
- University-managed career fairs, employer approvals, card issuance, and
  aggregate engagement/outcome reporting
- Private Supabase Storage access through signed URLs
- Netlify security headers and dependency-free smoke tests

Before deployment:
1. Read DEPLOYMENT.md.
2. Apply tapid_v2_production_migration.sql after the existing Sprint migrations.
3. Run `npm test`.
4. Deploy the complete directory to Netlify.

The Supabase value in config.js is a browser publishable key. Never place a
service-role or secret key in this repository.
