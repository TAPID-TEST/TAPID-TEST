# TapID requirements audit

Audit scope: the 43-part product requirement set reviewed against the V3
frontend and Supabase migrations.

## Coverage summary

| Requirements | Status | Implementation |
|---|---|---|
| 1–2 Core product and roles | Complete | Separate student, employer, and university experiences |
| 3–4 Student account/profile | Complete | Signup, login, onboarding, locked activated username, profile editor |
| 5–7 Résumé, contacts, links | Complete | Private storage, visibility controls, vCard download, professional links |
| 8–12 Work and evidence | Complete | Detailed experiences/projects, featured records, skill evidence, organizations, certifications and media |
| 13 Public profile | Complete | Recruiter-scannable profile with no public connection count |
| 14 Visitor connections | Complete | Consent-based public form and private student connection workspace |
| 15–17 Employer accounts/workspace | Complete | Normalized companies, verified recruiter flow, mutual connections, filters, notes and statuses |
| 18–23 Career-fair requests | Complete | Official event directory, one request per company/event, pending privacy, accept/decline and mutual conversion |
| 24 University login | Complete | Provisioned-only access with verified-only V3 enforcement |
| 25–28 University analytics | Complete | Aggregate-only engagement, request conversion, and recruiter-signal reporting |
| 29 Outcomes | Prototype complete | Student-reported outcomes and separate verified counts; an external verification workflow is still future work |
| 30 Professional journey | Complete | Recommendations/outcomes page and alumni continuity on the permanent profile |
| 31 Recommendations/letters | Prototype complete | Recommendations attach to experiences/projects and optional PDF letters use private storage |
| 32 Physical card | Software complete | Permanent URL and QR generation; physical NFC/QR device testing remains manual |
| 33–36 Privacy | Complete | Section/record visibility, profile pause, private notes, delayed recruiter contact, aggregate university access |
| 37–39 Role UX | Complete | Simple student UX, operational employer UX, analytics-focused university UX |
| 40 Visual direction | Complete | Forest green, gold, cream, minimal career-oriented interface |
| 41 Product boundaries | Complete | No social feed, job board, messaging suite, ATS, LMS, or popularity scoring |
| 42 University deployment | Architecture complete | School-scoped data and Cal Poly demo support; institutional rollout is operational work |
| 43 Platform ownership | Architecture complete | TapID-owned frontend/backend deployment model |

## V3 hardening

- New university administrator rows default to pending and all university RPCs
  require a verified administrator.
- Recruiter registration email must match the authenticated email.
- Recruiters can update only ordinary identity/event preferences and candidate
  status/notes; protected verification, ownership, and relationship fields are
  no longer directly writable from browser sessions.
- Candidate and request data is available only to verified recruiters.
- Direct recruiter connections require an approved registration at the selected
  official career fair.
- Request acceptance and decline both re-check verified recruiter status and
  current official-event approval inside the database transaction.
- University reporting now distinguishes direct connections, pending requests,
  accepted requests, and declined requests.
- Alumni can record an alumni-since year without changing their permanent URL.

## External go-live work

These items cannot be completed by repository code alone:

1. Configure production SMTP in Supabase.
2. Add a custom TapID domain and update the Supabase URL allowlist.
3. Test real NFC cards and QR codes on current iOS and Android devices.
4. Complete the live role-to-role matrix in `TESTING.md` with dedicated accounts.
