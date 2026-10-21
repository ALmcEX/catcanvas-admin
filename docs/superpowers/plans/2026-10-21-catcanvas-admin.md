# CatCanvas Admin Implementation Plan
Goal: Deliver the approved independent admin application for the existing CatCanvas database.
Architecture: Next.js App Router, Google OAuth, session-bound admin RPCs and protected server actions.
Spec: ../specs/2026-10-21-catcanvas-admin-design.md
Execution: Native implementation following the owner's confirmed instruction.

## Constraints and review focus
English UI; actual statistics; no fabricated AI outputs or paid generation. Protect pages, actions and SQL functions, including revoked sessions. Reject profile self-promotion while preserving ordinary profile edits. Preserve canonical caption and image references. Validate identifiers, lengths, pagination, CSRF and failures. Verify exact OAuth callbacks and mobile layout.

## Tasks
- [x] 1. Establish independent project; test isAdmin(user, profile) and parseMedia(fields) with absent Google identity, revoked privilege, malformed IDs and oversized fields. Run failing tests, implement lib/access.ts and lib/validation.ts, run tests.
- [x] 2. Implement supabase/migrations/20261021000000_admin.sql and supabase/tests/admin_permissions.sql: admin_overview(), admin_profiles(q,page), admin_media(q,page), admin_votes(page), admin_media_mutate(action,payload). Verify self-promotion denial, normal profile edits and transactional media CRUD with rollback fixtures.
- [x] 3. Implement lib/auth.ts, lib/supabase.ts, app/(admin)/*, app/login/*, app/auth/callback/* and components/*. Add responsive dashboard, profiles/media/votes tables, validated actions, pagination, empty/error states and delete confirmation.
- [x] 4. Run relevant tests, lint, production build, database suites and browser authorization/layout checks.
- [x] 5. Create GitHub repository and Vercel project; configure only required public Supabase environment, precise OAuth callbacks and verified owner admin.
- [x] 6. Verify OAuth, incognito login wall and Vercel protection; record both commit-specific URLs.
