# TapID V3 deployment

## Required order

1. Back up the Supabase database.
2. Apply the existing Sprint migrations through `sprint6_13_connection_requests_patch.sql` if they are not already installed.
3. Apply `tapid_v2_production_migration.sql` in the Supabase SQL editor.
4. Apply `tapid_v3_hardening_migration.sql` in the Supabase SQL editor.
5. In Supabase Authentication URL Configuration, set the production Site URL and add the Netlify preview/production reset-password URLs.
6. Configure production SMTP in Supabase so confirmation, recovery, and email-change messages are deliverable.
7. Deploy this directory to Netlify. `netlify.toml` publishes the directory and applies security headers.
8. Add the custom TapID domain in Netlify, enable HTTPS, then update the Supabase Site URL and redirect allowlist to the custom domain.

## Verification checklist

- Student signup, confirmation, onboarding, card issuance, and serial activation
- Student password recovery, email/password changes, and account deletion
- Public profile visibility, photo, résumé, media, recommendations, and outcomes
- Private storage URLs expire and hidden records are not readable anonymously
- University creates and publishes a career fair
- Employer registers; university approves; student directory shows the company
- Student request remains pending until accepted
- Accepted request creates both student and employer records
- University dashboard shows only aggregate data
- NFC tag and QR code both open the permanent production profile URL

## Physical NFC validation

Write the exact URL shown on `card.html` to a rewritable NFC card, lock it only after testing, and test both NFC and QR on current iOS and Android devices. Physical RF behavior cannot be verified by automated browser tests.
