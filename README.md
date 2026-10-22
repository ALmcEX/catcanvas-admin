# CatCanvas Control Room

Independent Next.js admin app for the existing CatCanvas database. Responsive English interface and genuine statistics.

## Features
- Community counts, 14-day activity, publishing conversion, vote sentiment, media mix, attention ranking and divided opinions (minimum two votes).
- Searchable, paginated read-only profiles with account emails and a vote ledger. Profile searches support name, email and ID.
- Full source media CRUD: import existing AI images/captions as private drafts or publications; read and search all sources; edit source metadata, text and image files; permanently delete drafts or published sources with explicit confirmation.
- Publication deletion cascades votes/comments; unused files are removed through Storage with a persistent retry queue. Shared assets are retained. Previous metadata is recorded in a private audit table. Concurrent publication changes invalidate stale forms.
- Imports are explicitly labeled and require source attestation. This admin does not call an AI provider or generate fake provider responses.

## Security
Protected pages, server actions and database RPCs independently require a verified Google OAuth session and a Google-only identity and profiles.is_superadmin=true. Missing session/profile/migration or revoked access fails closed. No service-role credential is needed. Public routes contain only login, callback, access-denied or generic not-found UI.

A profile trigger rejects ordinary insert/update/upsert privilege escalation while preserving name/avatar edits. Privileged functions use fixed search paths, explicit grants, internal authorization checks and bounded pagination. Media updates preserve canonical references and original caption candidates.

## Setup
1. Copy .env.example to .env.local with the existing public Supabase URL and anon key.
2. Apply supabase/migrations/20261021000000_admin.sql followed by supabase/migrations/20261021000001_admin_library_scope.sql and supabase/migrations/20261021000002_media_record_crud.sql and supabase/migrations/20261022000000_profile_emails.sql to the existing CatCanvas database. The tests/fixtures/base-migrations directory is a historical test baseline, not a production migration directory.
3. Enable Google OAuth and add the exact deployment /auth/callback URL to Supabase's redirect allowlist.
4. Bootstrap the first admin in the database owner's SQL Editor after verifying the email, UUID and Google identity:

```sql
update public.profiles set is_superadmin = true
where id = '<verified-owner-google-user-uuid>';
```

Never auto-promote the first user. Revoke access using the same owner-only procedure with false.

5. Run npm ci and npm run dev. Deploy as a separate Vercel project with the two public environment variables. Disable Vercel deployment protection for assignment viewing while retaining the application's Google/admin wall.

## Verification
```sh
npm test
npm run test:db
npm run lint
npm run build
```
The disposable PGlite suite replays the historical schema and checks non-admin denial, self-promotion rejection, profile-edit compatibility, cross-owner admin media CRUD, canonical captions, private audit preservation, source create/update/delete, storage cleanup receipts, stale-edit rejection, revocation and anonymous denial. All test writes roll back. This does not replace live OAuth/deployment checks.
