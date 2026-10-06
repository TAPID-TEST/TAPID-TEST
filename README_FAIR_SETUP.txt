TapID — Career fair setup

INSTALL
1. Run tapid_fair_setup.sql in Supabase SQL Editor first.
2. Upload these website files to the repository root, replacing matching files:
   university-fair-setup.html
   university-fair-setup.css
   university-fair-import.js
   university-fair-setup.js
   university-fairs.html
   university-admin.html
3. Commit: Simplify career fair setup and company imports

USE
University > Career Fairs > Set up a career fair.
1. Enter the fair name, dates/times (Pacific), location and optional description.
2. Add company names manually or import the company CSV template.
3. Review and add valid import rows to the list, then save a draft or show to students.
Reopen a saved fair from the list to update details, add companies or match accounts.

IMPORT
Required header: company_name
Optional header: external_employer_id
No event ID or repeated fair details required on company rows.
Duplicate company names are skipped case-insensitively. Invalid rows are listed.
CSV quoting, embedded commas, escaped quotes and Excel BOM are supported.
Up to 2,000 companies and 5 MB per import.
Names uniquely matching existing TapID companies are linked automatically.
Other names stay unlinked until manually matched or the company registers.
Importing a company does not create an account, approve a recruiter, or register
it for a fair in an outside system. Employer approvals remain in Employers.

DATA
Fair details and the company list save in one database transaction.
Saving existing fairs preserves connections and existing company rows.
Remove drops newly added, unsaved entries. Saved entries remain on the roster.
Existing event imports are reused when the name and timestamp match one fair
uniquely. Ambiguous older imports stay in the existing legacy import/matching tool.
The Administration page keeps the legacy import tool and card issuance.
Drafts appear in setup; published fairs appear in reports and student fair listings.
This update does not modify login, public profiles, or landing animations.

VALIDATION
Local checks pass across 39 HTML pages plus the existing analytics tests.
New checks cover CSV parsing, duplicates, malformed rows, matching, dates,
failed-save retention, saved state and report links using a mocked API.
The SQL has not been executed against your Supabase project here.
After deployment, create a draft, import two companies, save, reopen, then publish
and check the student fair list and report link. Test with your signed-in admin.
