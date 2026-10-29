# Assignment 7 — extend CatCanvas administration

Date: 2026-10-29 (America/New_York)
Status: Proposed design; existing-project approach confirmed by the owner. Implementation awaits design approval.

## Intent and evidence

Extend the Assignment 6 admin app in `ALmcEX/catcanvas-admin`, retaining its English interface, Google-only superadmin authorization, existing statistics, profile email directory, media CRUD/uploads, and vote ledger. Continue using Supabase project `zsuvcnbgsvcxlwiankbf` and the existing creation/rating app in `ALmcEX/assignment-1-nextjs`.

Local admin baseline: `828044235bb9375714f55ed8179b3c61fa77f78f`. Creation baseline: `29db7295706b4b63a99d61c20ad759048148eb6a` on `codex/assignment-4-rants`. Both remote branch heads matched these SHAs during this design pass. Recheck before implementation or deployment.

On 2026-10-29 the authenticated Supabase Table Editor listed admin_media_audit, ai_generation_usage, ai_generations, courses, image_test_budget, meme_provider_usage, profiles, rant_comments, rant_votes, and rants. None of the Assignment 7-specific tables were present. This is live inventory evidence; complete column/function definitions still need to be checked before applying production migrations.

A live read-only metadata query additionally confirmed the columns of profiles, ai_generations and rants, including existing admin_version/admin_caption on generations and is_superadmin on profiles. The only non-internal auth.users trigger returned was on_auth_user_created AFTER INSERT, calling public.handle_new_user to insert the profile. Implement signup enforcement as a separate BEFORE INSERT guard without replacing that existing profile trigger, subject to live migration-role privilege verification.

Course source checked: https://www.thehumorproject.org/assignment/23. It specifies operations but does not define columns or the semantics of terms, generation examples or chain mix; https://www.thehumorproject.org/documentations currently says “No documentation yet.” Therefore the definitions below are explicit CatCanvas implementation proposals, not a claim to reproduce an unseen course schema. They must remain visible in the approval summary.

The full Week 7 rubric gives 50 points for previous-week feedback implementation and 50 for technical functionality. Assignment 6 grade details at https://www.thehumorproject.org/assignment-submission/5568/grades show full marks and no specific improvement comments on the displayed rubric. Preserve its accepted behavior and keep an evidence checklist for any additional feedback the owner supplies. Week 7 is due 2026-10-29 at 14:00 EDT according to the live assignment page.

The creation app currently calls Gemini through three paths: four caption choices, a single meme caption, and cat-image generation. It stores successful media in ai_generations, but has no durable request/response history. Historical generations cannot establish failed requests, provider latency, token counts, or raw response payloads.

## Approach and scope

Selected by the owner: extend the existing Assignment 6 CatCanvas backend and database.

Other approaches considered: connect to a separate course database, which would require a supplied schema and would not directly describe CatCanvas's current users/media; build a replacement admin application, which duplicates working auth, CRUD and deployment. Neither is selected.

Recommended implementation within the selected approach: additive PostgreSQL migrations, protected admin pages, and a small integration in all three existing server-side generation paths. Admin-only empty tables without real producer integration would not provide useful observability; inventing historical request/response records would be misleading. These are implementation recommendations, not claims of prior owner approval.

This is a multi-part extension across two repositories. The admin repository owns the new schema, admin RPCs, and migration tests; the creation repository owns runtime reads and logging integration. Do not apply duplicate migrations from both repositories. Deploy the schema before the updated applications. No new external project or AI provider is needed.

## Assignment coverage

| Resource | Required operations | Proposed route |
| --- | --- | --- |
| Users/profiles | Read | Existing /profiles |
| Prompt chains | Read | /prompt-chains |
| Prompt chain steps | Read | Chain details on /prompt-chains/[id] |
| Prompt chain mix | Read/update | /prompt-chain-mix |
| Terms | Create/read/update/delete | /terms |
| AI generated media | Read/view | Existing /media |
| Generation requests | Read | /generation-requests and /generation-requests/[id] |
| AI generation examples | Create/read/update/delete | /generation-examples |
| LLM models | Create/read/update/delete | /llm-models |
| LLM providers | Create/read/update/delete | /llm-providers |
| LLM responses | Read | /llm-responses and response details linked to requests |
| Allowed signup domains | Create/read/update/delete | /allowed-signup-domains |
| Whitelisted email addresses | Create/read/update/delete | /whitelisted-emails |
| Images, including uploads | Create/read/update/delete | Existing /media forms and previews; verify full coverage |

Existing overview and ratings routes remain available. Table pages support bounded pagination, search where useful, actual counts, understandable empty/error states, and relation links. Reuse current typography, components, responsive navigation and form conventions. The builder may group navigation labels to keep the sidebar usable; this is an implementation choice.

## Data model and meaning

Use explicit tables with typed columns and foreign keys, not one unvalidated JSON collection. UUID primary keys, timestamps, input bounds, and optimistic concurrency/version checks apply to editable records.

- llm_providers: name, stable provider slug, optional official website and description. No API keys, arbitrary inference endpoints, or browser-supplied URLs used for server fetches.
- llm_models: provider reference, provider model identifier, display name, modality and descriptive metadata. Provider/model identifiers used by fixed runtime steps cannot be renamed/deleted while referenced. Creating a model catalog record does not activate it or switch generation providers.
- prompt_chains: stable code, name, purpose, description, and implementation version. Read-only to admin users as required. Deployment-owned definitions describe actual runtime paths.
- prompt_chain_steps: chain reference, sequence, model reference, operation identifier and documented prompt-template/configuration metadata. Read-only. Each current path is truthfully a one-provider-call chain; do not invent a multi-step pipeline.
- prompt_chain_mix: one row per deployed eligible chain/purpose with enabled flag and integer allocation weight. Admins update existing rows; no UI create/delete is required. Updates for a purpose are atomic and must leave enabled positive weights totaling 100. Runtime selection uses only code-supported chain identifiers, and stores the selection/version snapshot on the request. Arbitrary model/prompt execution is outside scope.
- terms: a managed terminology/glossary resource with unique term and definition, optional example/context. This means vocabulary entries, not legal Terms of Service. Management is supported; generation is not silently changed to inject glossary content.
- ai_generation_examples: curated example input, expected caption/text output, purpose, optional model/media reference, and notes. Records are explicitly curated examples, not provider logs. This work provides example management; it does not silently add few-shot examples to existing prompts.
- generation_requests: user reference, purpose, selected chain/version snapshot, bounded input prompt and safe input metadata, pending/succeeded/failed status, timestamps, nullable duration/error code and optional ai_generations reference. Timeouts/interrupted work must not appear successful. Show old pending entries as unfinished, without inventing a provider failure outcome.
- llm_responses: request reference, step/model references plus immutable identifiers snapshot, provider HTTP status when received, bounded visible text/structured output, optional reported token counts, finish/block information, and timings. Missing provider fields remain null. Store useful observed output and approved metadata, not an unrestricted raw response blob.
- allowed_signup_domains: normalized unique DNS domain; exact domain matches only, no implicit wildcard/subdomain matching.
- whitelisted_emails: normalized unique exact email address with optional note. Email local/domain comparison is case-insensitive for this application's allowlist policy.

Initialize only catalog/chain definitions that are demonstrably present in source: Gemini and the two existing provider model identifiers, with one chain/step for each supported generation path. Do not generate example media or seed fabricated requests, responses, glossary entries, or allowlist identities.

There is initially one eligible chain per purpose with 100 weight. Mix editing can pause/resume a path through a separate enabled state, but an active purpose must total 100; an entirely disabled purpose is permitted and makes that purpose unavailable before any provider call. If multiple compatible code-supported chains are deployed later, allocation weights determine actual selection; do not offer invented variants just to demonstrate randomization. The implementation must clearly show that only one variant currently exists and cannot accept a positive active total other than 100.

## Runtime integration and truthful history

Keep the existing prompt builders, model identifiers, output validation, quotas, storage behavior and AI feature flags. Runtime step definitions identify the existing implementations; admin CRUD does not turn configuration rows into executable code. Runtime resolution validates the configured chain/model/step against a server-owned registry and fails before spending if no eligible supported chain is enabled. Deployed code and seeded definition versions must match.

After authentication and bounded input validation, create a request record before executing the generation workflow. Capture accepted requests that later fail quota/reservation, upload, provider, validation, or persistence operations. Reject anonymous, cross-origin or malformed requests without persisting untrusted payloads. A disabled AI feature may still return the existing unavailable response before request creation; the request page must describe that its coverage begins with accepted generation attempts.

Capture provider outcomes at the provider-call boundary. A successful provider response followed by a failed save is a response attached to a failed generation request. A network timeout has no fabricated HTTP status or output. Record only actual returned token usage; exclude model reasoning/thought parts, base64 image content, API keys, request headers, authorization tokens, cookies and signed URLs. Image responses use safe MIME/size metadata and a relation to the saved media rather than duplicating image bytes. Cap stored text and metadata sizes with explicit truncation indicators.

Logging initialization failure prevents a new paid/provider call, avoiding intentionally untracked spending. Once a provider call has completed, a logging failure must not retry that provider call. Preserve successful media results when only telemetry finalization fails and return the normal successful result to the API caller. Write a sanitized diagnostic to server logs only; do not turn a successfully saved generation into a client-visible failure. Leave the pending record visibly incomplete for diagnosis. Idempotent request/step correlation prevents duplicate response records. No automatic retry spending is introduced.

Historical ai_generations remain unchanged. Show historical media through the existing library; do not claim that missing request/response records were reconstructed. New media links to its request when available, and requests link to responses and resulting media.

## Signup policy

This is a proposed implementation choice for approval: make allowlist configuration effective for future signup, not merely decorative CRUD.

- With both lists empty, preserve existing signup behavior.
- With either list populated, permit a new account if its exact email is whitelisted OR its exact normalized domain is allowed.
- Apply the rule at the authoritative Supabase auth-user creation boundary, using a narrowly scoped database trigger/hook selected after inspecting the current auth schema. A UI-only callback check is insufficient.
- Existing accounts and superadmin access are not retroactively revoked. Allowlist membership never confers superadmin status.
- Seed neither list automatically. Show the effective rule, including the empty-list behavior, before saving or deleting entries. Admin privileges are rechecked when changing entries.
- Do not expose the whitelist or private emails to anonymous clients. Preserve existing profile creation triggers and Google login behavior.

## Authorization and mutations

Every new page, server action and admin RPC independently requires the current verified Google OAuth session and current profiles.is_superadmin flag. New tables enable RLS and revoke anonymous/ordinary-user access. Use the existing fixed-search-path, explicit-grant, internally guarded RPC pattern. Runtime service-role usage remains confined to the existing creation server; no service credential enters admin browser code or Git.

CRUD handlers use a server-owned resource/field allowlist, validate identifiers/lengths/relations, and do not accept arbitrary table names, column names, SQL, or provider URLs. Normal users cannot write chains, logs, catalog records, or signup policy through REST. Runtime reads expose only required chain resolution, not arbitrary admin tables. Log writes are server-only and must correlate users, requests, steps, and media correctly.

Deleting referenced providers/models/examples must show an actionable conflict rather than cascade-delete observations. Request/response rows preserve historical snapshots; no admin CRUD is offered for these logs. Existing media removal can set a request's optional media reference to null, while retaining the observed history. Forms surface stale versions and require record-specific deletion confirmation. Browser tests must not delete existing genuine records just to prove CRUD.

## Deployment, validation and acceptance

1. Recheck complete live schema, remote heads, deployed source branches and precise production migrations before applying additive changes. Keep local disposable DB coverage for schema/role behavior.
2. Test CRUD and negative authorization for all six new CRUD resources plus the update-only mix; read denial for every new read-only resource; stale writes, duplicate normalization, invalid FK references, and referenced-record deletion conflicts.
3. Test mix sum/disabled rules, active runtime resolution, signup OR semantics, empty-list behavior, exact domain matching, existing-user access, profile-trigger compatibility and privilege non-escalation.
4. Test request/response recording for successful provider output, provider failure/timeout/block, quota/upload/save failures, and logging failure. Verify redaction, bounds, missing usage values, and no duplicate provider calls.
5. Re-run existing admin DB compatibility, media CRUD, unit tests, lint and production builds; run appropriate existing creation-app tests and its build. Review new code with a fresh agent before integration.
6. Inspect desktop/mobile admin pages, forms, pagination, request-response links, media previews/uploads and error states. Verify anonymous and ordinary accounts cannot access new pages or RPCs, including after privilege revocation.
7. Apply migration in a controlled order, preserve recovery SQL for additive changes, deploy both updated apps, add exact OAuth callback URLs when required, and check final source SHA-to-deployment mapping. Do not weaken application authentication.
8. Check Vercel Deployment Protection and signed-out access for both commit-specific deployments. If a security-setting change is required through browser UI, obtain action-specific confirmation when required by computer-use policy.
9. Prepare a submission note containing the two latest verified commit-specific Vercel URLs and an evidence checklist for the feedback-implementation rubric. Course submission itself is a separate action; do not report it as sent without evidence.

No billing changes, automatic paid AI smoke tests, credential transfers, bulk data changes or unsolicited course submissions. A real provider smoke test requires an already authorized budget; otherwise report provider integration as mock-tested and await an approved live test.

## Builder decisions and remaining checks

Builder may choose component composition, resource route file layout, table/index names consistent with this design, and transaction-safe mix editing UX. Stable chain codes and templates must be derived from current source, with tests proving registry consistency. Preserve known model constraints rather than casually broadening generation validation.

Before implementation is called production-ready, confirm the live auth signup boundary supports the proposed enforcement mechanism and inspect the full current schema. Any live-only incompatibility that materially changes signup semantics or generation behavior requires returning with that concrete issue. Otherwise execute within this scope after owner design approval.

## Design review

A fresh builder review identified two questions: caller behavior on telemetry-finalization failure, and evidence for course resource semantics. Resolved above: the caller receives success after a successful media save; course source and absent supplemental definitions are recorded explicitly, with proposed meanings subject to owner approval. No product code, database migration or production setting was changed during this design pass.
