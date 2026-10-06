Cal Poly automatic email verification and serial assignment

1. In Supabase Authentication, keep Confirm email enabled for the Email provider.
   With confirmation disabled, Supabase auto-confirms addresses and this flow
   cannot establish mailbox ownership. Existing administratively confirmed
   accounts are trusted as confirmed by Supabase.
2. Run tapid_calpoly_auto_cards.sql in Supabase SQL Editor before uploading files.
3. Upload app.js and card.html to the GitHub repository root. Preserve the
   university-card-access.js file from the previous session-isolation patch.
4. Commit: Automate Cal Poly student card serial assignment
5. After deployment, hard refresh and sign in to a student account using a
   confirmed @calpoly.edu email. Complete the school and username fields.
   For the school, use Cal Poly or Cal Poly San Luis Obispo.
6. Open Card. The serial (for example CP-00000001) is already populated.
   Click Activate My TapID when ready to share the public profile.

The SQL backfills existing eligible students and does not delete accounts or
change their profile content. Later students receive a serial when their own
profile loads after email confirmation and school setup. Existing serials are
preserved. Issuance is not physical card manufacture or delivery.

University and employer accounts are excluded. Institutional email ownership
does not grant university administrator access or prove current enrollment.
The public badge reads Cal Poly email verified after activation. Students at
other schools keep the existing university-issued card flow.

Verification completed: website scripts parse; mock session tests confirm
automatic assignment only for the signed-in student's own profile; university
views and other people's profiles do not request assignment; errors surface.
The SQL has not been executed against your live database. Test one confirmed
Cal Poly student, reload to confirm the same serial, and confirm a non-Cal-Poly
account receives no automatic serial. No live accounts have been modified here.
