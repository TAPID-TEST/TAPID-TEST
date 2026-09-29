TapID V1 — Sprint 6.7: Final Mobile + Consistency Pass

No SQL changes are required.

What changed:
- Full small-screen consistency pass across homepage, student/employer auth, dashboard, public profile, and employer portal.
- Onboarding and Card & QR now use the same current TapID visual language.
- Stronger phone/tablet spacing and typography.
- Safer wrapping for long URLs, names, companies, notes, and user-generated text.
- Mobile dialogs fit within the viewport and scroll internally.
- Form fields use 16px input text to avoid iOS auto-zoom.
- Touch targets and action layouts are easier to use on phones.
- Dashboard navigation collapses cleanly; very small phones use a single-column menu.
- Card/QR layout and actions stack cleanly on phones.
- No Supabase logic, IDs, database schema, or application behavior was intentionally changed.

Recommended smoke test widths:
- Desktop: ~1536px
- Tablet: ~768px
- Phone: ~390px

Test pages:
index.html
signup.html
login.html
onboarding.html
dashboard.html
card.html
profile.html?u=<activated_username>
employer-login.html
employer-signup.html
employer-dashboard.html
