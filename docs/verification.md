# Verification — 2026-10-21

## Implemented and checked
- Independent GitHub repository ALmcEX/catcanvas-admin and Vercel project catcanvas-admin, using the existing CatCanvas database.
- Four protected sections: real-data overview, read-only profiles, media publication CRUD and read-only vote ledger.
- Google-only OAuth identity, verified JWT OAuth authentication method and current database superadmin flag checked on each private read and mutation. No service-role environment variable is required.
- Owner-approved Google account bootstrapped through Supabase SQL Editor after checking email, UUID and provider. Ordinary users cannot change their admin flag.

## Evidence
- 14 unit tests passed, including missing/incorrect privilege, non-Google/password sessions, other linked OAuth identities, malformed identifiers and deletion of legacy long content without unrelated edit validation.
- Disposable PostgreSQL/PGlite admin suite passed; all six original compatibility suites passed (images, captions, gallery, public captions, memes and rants).
- Online admin rollback suite passed after both migrations: normal profile edits, self-promotion rejection, authorized cross-owner publication create/update/delete, canonical caption enforcement, original generation preservation, revoked and anonymous denial. Test records and dependent rows rolled back.
- Actual anonymous Supabase REST RPC calls to admin_overview/admin_profiles/admin_media/admin_votes returned insufficient_privilege (42501).
- Lint and production build passed. Production dependency audit reports zero known vulnerabilities. The development-only ESLint dependency chain still has five audit findings; the suggested forced fix would downgrade the Next.js lint configuration across major versions and was not applied.
- Real Google sign-in: ordinary Google account reached access denied; approved administrator reached the overview. Both localhost and the deployed stable admin domain were checked.
- Browser inspected real counts: 4 profiles, 9 non-example AI generations, 6 non-example publications, 6 current votes. No invented statistics or extra real content was added for demonstration.
- Profiles and vote tables rendered with read-only controls. Media displayed genuine generations and original candidate-caption controls. UI writes were not tested by changing existing user works; transaction rollback SQL exercises the same mutation RPC.
- Desktop layout checked. Mobile login at 390x844 had innerWidth=390 and scrollWidth=390 after fixing an absolutely positioned decorative element. Chrome's viewport override did not change its reported dimensions, so no narrow-screen authenticated-page claim is based on that override.
- Vercel authentication protection disabled with explicit owner approval. A request without Vercel cookies redirects to the application's own login page. Protected sourcemaps remain enabled.

## Release evidence
Exact source SHAs, commit-specific deployment URLs, live acceptance checks and screenshots are recorded outside the source repository in /Users/alex/Documents/Design for AI/assignment-5-evidence to avoid triggering an extra deployment solely to record its own URL.

The existing creation app remains on its original branch and repository. No billing setting or AI provider budget was changed. No course Submissions form was sent.

## Profiles email update — 2026-10-22
- Added a read-only EMAIL column sourced from auth.users via the existing Google-superadmin-guarded admin_profiles RPC. Search and pagination totals include email alongside name and UUID. Profiles without an email remain listed with a Not available label. No email is copied into public profile data.
- The new profile_emails.sql rollback suite passed locally and in live Supabase, covering account email, case-insensitive search, matching totals, missing-email rows and ordinary/anonymous denial. Existing media/admin and six compatibility suites passed.
- Updated Next.js and eslint-config-next from 16.4.0 to 16.4.2 after a dependency advisory surfaced during build. The production dependency audit reports zero known vulnerabilities after the patch; existing development audit findings remain. All 25 unit tests, lint and production build passed on the patched dependencies.
