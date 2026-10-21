# CatCanvas Control Room

Independent Next.js admin app for the existing CatCanvas database. Responsive English interface and genuine statistics.

## Features
- Community counts, 14-day activity, publishing conversion, vote sentiment, media mix, attention ranking and divided opinions (minimum two votes).
- Searchable, paginated read-only profiles and vote ledger.
- Media provenance; create publications from genuine AI drafts; update titles, location and image captions or select original AI caption candidates; remove publications with explicit impact confirmation. Source generations and original assets are retained.

## Security
Protected pages, server actions and database RPCs independently require a verified Google OAuth session and a Google-only identity and profiles.is_superadmin=true. Missing session/profile/migration or revoked access fails closed. No service-role credential is needed. Public routes contain only login, callback, access-denied or generic not-found UI.

A profile trigger rejects ordinary insert/update/upsert privilege escalation while preserving name/avatar edits. Privileged functions use fixed search paths, explicit grants, internal authorization checks and bounded pagination. Media updates preserve canonical references and original caption candidates.

## Setup
1. Copy .env.example to .env.local with the existing public Supabase URL and anon key.
2. Apply supabase/migrations/20261021000000_admin.sql followed by supabase/migrations/20261021000001_admin_library_scope.sql to the existing CatCanvas database. The tests/fixtures/base-migrations directory is a historical test baseline, not a production migration directory.
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
The disposable PGlite suite replays the historical schema and checks non-admin denial, self-promotion rejection, profile-edit compatibility, cross-owner admin media CRUD, canonical captions, source preservation, revocation and anonymous denial. All test writes roll back. This does not replace live OAuth/deployment checks.
