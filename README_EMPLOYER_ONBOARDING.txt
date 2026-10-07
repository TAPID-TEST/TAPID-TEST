TAPID EMPLOYER ONBOARDING UPDATE

WHAT CHANGES
Create an employer account -> confirm work email -> sign in -> university review.
The pending page lets employers save their name, title and phone and check status.
Approved employers go to the recruiting dashboard on their next sign-in or status check.
Declined accounts see the university's reason. Recruiting access remains closed.
University approval attempts an email. A failed email never undoes account approval.
The email links to ordinary employer login; it does not bypass the password or approval.
Existing approved accounts keep their access.
The previous login fit fixes and visible employer signup link are included.

1. DATABASE
Open Supabase > SQL Editor. Run the ENTIRE tapid_employer_onboarding.sql file.
It expects the university workspace SQL that you already installed.
This adds an email outbox and restricted server functions. It does not delete accounts.

2. WEBSITE FILES TO UPLOAD AND COMMIT
login.html
employer-login.html
university-login.html
employer-signup.html
login-fit.css
employer-dashboard.html
employer-approval.html
employer-access.js
employer-approval-page.js
employer-onboarding.css
university-employers.html
university-employer-approvals.js

Keep these files together so the new pages can load their scripts and styles.
Suggested commit message: Improve employer signup and university approval flow

3. ENABLE APPROVAL EMAILS (ONE-TIME SETUP)
This is separate from Supabase's existing signup confirmation email.
Create a Resend account and verify a sender domain there using its provided DNS records.
For example, use a sending subdomain of tapidcard.com. Keep the website's DNS records.
Create a sending API key in Resend. Do not put this key in GitHub or config.js.

In Supabase > Edge Functions > Secrets, add:
RESEND_API_KEY = your Resend sending key
TAPID_APPROVAL_FROM = TapID <accounts@YOUR_VERIFIED_SENDING_DOMAIN>
Use a sender on the domain that Resend actually verified.
Supabase provides SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY inside Edge Functions.

Create an Edge Function named exactly:
send-employer-approval-email

Paste ALL of approval-email-function.ts into the function's index.ts and deploy.
In this function's configuration, disable "Verify JWT with legacy secret".
The function itself verifies every caller's user token with Supabase auth.getUser,
then the database requires a verified university admin and an approved employer
from the same university. Disabling the legacy gateway check does not disable
these application authorization checks.

CLI ALTERNATIVE
If you already use Supabase CLI, deploy the included supabase function folder:
supabase functions deploy send-employer-approval-email --project-ref YOUR_PROJECT_REF --no-verify-jwt
Set the two secrets in the Supabase dashboard as above.

Until this function and its sender are configured, university approval still works.
The university will see an email warning and can use Send/Retry approval email later.
"Approval email accepted" means the email service accepted it, not proof of delivery.

4. AUTHENTICATION SETTINGS
Keep email confirmation enabled in Supabase Authentication.
Keep https://tapidcard.com as the site URL and allow:
https://tapidcard.com/employer-login.html?confirmed=1
Do not remove working student or university redirect URLs.

5. CHECK AFTER DEPLOYMENT
Create a new employer account and confirm its work email.
Sign in: it should show the review page. Save recruiter details.
In the university Employers > Approvals tab, approve that account.
Check that the email is accepted once the sender/function setup is complete.
On the employer page, Check approval status should open the dashboard.
Signing in again should also open the dashboard, regardless of email delivery.
Decline/revoke an account: the employer should return to the restricted review page.

TECHNICAL NOTES
Email jobs are recorded for new approval decisions. Existing approval decisions
can be sent using the approved list's Send approval email button.
Retries use a stable provider idempotency key and a five-minute sending lease.
An uncertain attempted send older than 23 hours is blocked for manual review,
because provider duplicate protection expires. Inspect Resend before resetting
that job. Changing the sender between uncertain retries may also require review.
No background email scheduler is installed: the university approval action sends,
and the university can retry from its approved list.

VALIDATION
All local test suites passed, including employer routes, restricted profile updates,
server caller verification, unauthorized rejection, recipient targeting and retries.
Supabase SQL deployment, actual email sending and browser layout need the live
checks above; this workspace has no authenticated access to your Supabase project.

OFFICIAL SETUP REFERENCES
https://supabase.com/docs/guides/functions/quickstart-dashboard
https://supabase.com/docs/guides/functions/secrets
https://resend.com/docs/dashboard/domains/introduction
