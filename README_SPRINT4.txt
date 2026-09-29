TapID V1 - Sprint 4

Adds:
- Public "Connect With <First Name>" voluntary connection form
- Name, company/organization, email, phone, LinkedIn, where-met, message fields
- Explicit consent checkbox
- Private My Connections dashboard
- Connection date/context
- Private notes editable only by profile owner
- Delete connection

Before redeploying, run sprint4_backend_patch.sql once in Supabase SQL Editor.
Then redeploy this entire folder to the existing TapID V1 Netlify site.


Sprint 4.1 fixes:
- Removed LinkedIn from the public Connect form.
- Successful Connect submissions automatically close and return to the public profile.
- Private dashboard now loads connections on initialization.
