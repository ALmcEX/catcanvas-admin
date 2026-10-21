# CatCanvas Admin — proposed design

Status: Approved by the owner; implemented, reviewed and deployed; release verification is recorded separately.
Date: 2026-10-21 (America/New_York)

## Purpose and acceptance

Create a separate GitHub repository and Vercel application for the course admin assignment. Reuse the CatCanvas Supabase database so moderation and statistics describe the existing creation/rating app. The existing app repository is ALmcEX/assignment-1-nextjs; its verified remote branch head is 29db7295706b4b63a99d61c20ad759048148eb6a.

Suggested new repository/project name: catcanvas-admin. Use an English interface consistent with the current CatCanvas application.

## Approach

Recommended: independent Next.js application connected to the existing Supabase project. This satisfies the separate-repository requirement and keeps admin routing and deployment independent.

Alternatives: an /admin section in the existing app would simplify reuse but would not meet the requested new repository/project separation; a separate database would isolate data but would not manage the existing community. Neither is selected.

## Interface

Use a responsive editorial dashboard: dark sidebar, warm neutral workspace, orange accent, compact statistic cards and readable tables. Four protected sections:

1. Overview: actual user count, AI generation count, published media count, votes cast; a 14-day activity chart; generation-to-publication conversion; vote balance; most divisive works ranked by vote disagreement with minimum vote count and clearly displayed sample sizes. Empty states use actual zeros and explanatory labels.
2. Profiles: paginated, searchable read-only profiles with ID, names, join date and admin status. Do not expose credentials or build user deletion/privilege-edit controls.
3. Media: browse published AI images/captions and generation provenance; create publications from existing genuine AI generations; edit supported titles/captions/location; delete an explicitly selected publication with a confirmation showing affected votes/comments. Do not fabricate generation provenance. Existing generation and caption constraints remain authoritative. Removing a publication does not automatically erase its source generation or storage object.
4. Ratings: paginated, read-only upvote/downvote records with media reference and timestamp; show user identity only within the authorized admin context.

## Authentication and authorization

Public surfaces are limited to the Google login screen, OAuth callback and access-denied screen. No private data is embedded in these responses. Every protected page, server action and data endpoint validates the current Supabase user and Google sign-in identity plus profiles.is_superadmin === true. Fail closed on missing sessions, profiles, fields or database errors. Authenticated ordinary users see an access-denied screen.

Add profiles.is_superadmin boolean not null default false. Protect insert/update paths against self-promotion; the existing profile policies currently permit users to update their own row, so adding the field alone is insufficient. Preserve normal name/avatar edits in the existing application.

Prefer session-bound Supabase queries and narrow admin-only SQL functions/RLS with explicit authorization. Never grant broad public access or ship service-role credentials to the browser. SQL functions use fixed search_path, explicit grants, authorization checks, bounded pagination and validated inputs. Mutations recheck privileges on every call, validate input and use safe HTTP methods. Authorized content updates preserve the original app's generation/publication invariants.

Bootstrap the first admin through the authenticated Supabase project owner dashboard/SQL Editor, selecting the owner's verified existing Google identity UUID. Do not guess the account and do not add an auto-promote-first-user flow. Document the exact bootstrap procedure and verify ordinary users cannot assign the flag through REST.

## Deployment

Create the separate GitHub repository and Vercel project using available account sessions. CLI inspection currently shows no gh login and no global vercel executable; browser sessions or authenticated APIs must be checked before reporting an account-access blocker.

Configure only required environment variables without printing secrets. Add precise Supabase OAuth callback URLs for the admin deployment. Disable Vercel deployment protection while retaining application authorization. Verify both apps' latest commit-specific deployment URLs. Prepare those two links for the course Submissions section; do not claim submission unless it is actually performed.

## Validation

- Authorization tests for signed-out, non-admin, Google admin and revoked admin across protected pages, direct data endpoints and mutations.
- Database rollback tests for attempted self-promotion through insert/upsert/update, cross-account access, ordinary profile-edit compatibility, admin reads and media CRUD.
- Confirm anonymous and non-admin requests cannot obtain admin statistics/private generation data.
- Check media edits preserve feed visibility and canonical caption/image references; deletion affects only a deliberately created test publication and its dependent rows.
- Run lint, relevant tests and production build. Inspect desktop/mobile layouts and empty/error states.
- Confirm live OAuth, exact callback URL, incognito login wall and deployment protection settings. Record any verification requiring owner account interaction as pending.

## Boundaries

No billing changes, automatic paid AI generation, bulk deletion, unsolicited outreach or fabricated statistics. Do not modify or delete existing posts merely to demonstrate CRUD. No real credentials enter Git, screenshots or chat output.
