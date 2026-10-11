TAPID V25 — VERIFIED CAL POLY MAJORS AND LEGACY TOOL REMOVAL

Includes previous V23 and V24 university fixes. Upload every HTML/JS/CSS file in this ZIP. Run tapid_calpoly_catalog_v25.sql in Supabase after the previously supplied V21 major-catalog update. If V24 administration SQL has not been installed, run the included tapid_university_administration_v24.sql too. No Edge Function changes.

- Legacy event import/matching panel, CSV handlers, matching loaders and import actions are removed entirely from Administration. Historical database records are preserved.
- Catalog verified online against https://catalog.calpoly.edu/programs/ and its official PDF https://catalog.calpoly.edu/programs/programs.pdf (2026–2028 edition).
- All 94 distinct bachelor's/master's major labels were already present. One wrong mapping corrected: Transportation and Engineering Management is in College of Engineering, not Orfalea College of Business.
- College mapping checked against the official program URL/breadcrumb organization. Six colleges plus an Interdisciplinary Degree Programs category for joint programs. Joint programs are assigned that category, avoiding double counting across colleges.
- Degree and campus variants with the same major share one label. Minors and certificates are not primary-major options. This is the current catalog, not every historical program name.
- Signup, onboarding, profile editing and Administration now share the same catalog loader. An older or mismatched Cal Poly database response falls back to the identical verified packaged list. New SQL aligns server catalog/college mappings for analytics and validation.
- Existing profile majors are preserved. Student selection standardizes the label; email confirmation verifies email ownership/affiliation, not academic enrollment or correctness of the student's declared major.

Student onboarding in the current code:
1. University shares signup link. Student enters name, email, password and chooses an official major. College is automatic.
2. Supabase sends confirmation email (Confirm email must be enabled). Link returns to login.
3. Student signs in and completes basic profile: username, university, major, class year, graduation year. Major from signup is carried into onboarding.
4. Confirmed calpoly.edu student account receives a unique CP- serial automatically when profile/card setup runs. Existing cards are reused, not duplicated. Employer/university accounts are excluded.
5. Card page shows the serial. Activate My TapID enables the public profile and locks the permanent username URL.
6. Student adds résumé, photo, projects, experience and career interests. Those are optional for initial activation.
7. Physical manufacture, engraving and writing the NFC/QR URL are separate from automatic digital serial assignment.
8. Student uses the profile at fairs; university views account/setup/activation/connection data through its existing filters.

Validation: all 13 local suites plus catalog consistency and administration runtime checks passed. SQL not run live; no signed-in/browser-render verification.
Commit: Remove legacy imports and unify verified Cal Poly major selections

SQL repair: V25 catalog now uses one self-contained statement instead of a temporary table. Run the entire corrected tapid_calpoly_catalog_v25.sql in a fresh SQL Editor query. No Edge Function changes.
