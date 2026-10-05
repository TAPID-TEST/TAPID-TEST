TapID Custom Domain Finalization

Production URL
https://tapidcard.com

Files in this patch
- config.js
- app.js
- index.html
- forgot-password.html
- employer-signup.html
- university-signup.html

What changed
- Shared profile, NFC and QR URLs now always use tapidcard.com.
- Employer and university email confirmations return to tapidcard.com.
- Password recovery returns to tapidcard.com.
- The landing page has canonical sharing metadata for tapidcard.com.

Required Supabase setting
In Authentication > URL Configuration, set:
- Site URL: https://tapidcard.com
- Redirect URL: https://tapidcard.com/**

Keep the previous Netlify URL temporarily in Redirect URLs until all existing
confirmation and recovery links have expired. It can be removed later.

Suggested commit message
Finalize TapID custom domain and demo links
