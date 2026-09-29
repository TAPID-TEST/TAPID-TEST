TapID V1 Sprint 5

Focus: Orientation onboarding, card activation, permanent NFC URL, QR backup, profile readiness, and pause/reactivate behavior.

1. Run sprint5_backend_patch.sql in Supabase once.
2. Redeploy the entire folder to the existing Netlify TapID V1 site.
3. Existing fully configured test accounts are marked onboarding_complete automatically, but card_activated remains false until you activate through Card & QR.
4. Open card.html from the dashboard to activate and get the permanent URL/QR.

Important prototype note: the Storage buckets are still public. Pausing a profile blocks the profile and API metadata, but a previously copied direct public storage URL can still resolve. A later security hardening pass can move storage to private buckets with signed URLs.
