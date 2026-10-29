# Assignment 7 release checklist

Design: `docs/superpowers/specs/2026-10-29-assignment-7-design.md`.

- Migration owner: this admin repository. Apply `supabase/migrations/20261029000000_observability.sql` after the existing Assignment 6 migrations, before deploying the new creation runtime.
- New tables use RLS and deny direct anonymous/ordinary-client reads and writes. Admin RPCs require current Google superadmin status. Runtime telemetry functions execute only for service_role.
- Terms and curated examples are managed content, not automatically injected prompts. Provider/model catalog edits do not activate arbitrary inference endpoints. Deployed chains remain maintained in versioned code.
- Enabled chain allocation currently has one supported variant per purpose at 100%; disabling it pauses the path. Do not change SQL definitions without deploying a matching runtime registry version.
- Both signup lists empty preserves signup. Once either list has entries, exact domain OR exact e-mail allows a future account. Existing accounts are not revoked. No allowlist seed entries are inserted by migration.
- Creation integration: `/api/captions/generate`, `/api/memes/generate`, `/api/generate`. Only validated, authenticated workflow attempts are logged after enabled-feature checks. Historical media is not backfilled. Pending records may indicate interruption or recording failure.
- Successful generation still returns success if telemetry finalization fails. Do not retry paid inference as a logging recovery strategy.
- Provider outputs exclude thought parts, inline image bytes, headers, keys and signed URLs. Missing token usage remains unknown.
- Recovery: redeploy the prior creation and admin commits while preserving the additive tables and collected logs. Do not drop observability tables as a routine rollback. Any change to signup enforcement should be performed deliberately by the database owner after inspecting its lists and preserving the existing profile-creation trigger.
- Verify both commit-specific Vercel URLs, Google callbacks and application login wall. Do not claim a real AI-provider smoke test or course submission without performing the separately authorized action.

Live checks, release SHAs and screenshots are recorded outside the repositories in `assignment-7-evidence` after deployment.
