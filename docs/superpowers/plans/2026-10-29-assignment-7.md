# Assignment 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Extend the approved CatCanvas admin with configuration CRUD, real generation observability and signup policy.
**Architecture:** Add guarded PostgreSQL RPCs and typed tables in the admin repository. Reuse the admin interface and integrate a server-owned chain registry and telemetry into the existing creation repository.
**Tech Stack:** Next.js App Router, TypeScript, Supabase PostgreSQL, Vitest, PGlite.
**Spec:** docs/superpowers/specs/2026-10-29-assignment-7-design.md (owner approved 2026-10-29).

## Global Constraints
- Google OAuth and profiles.is_superadmin on every admin read/write.
- No fabricated historical requests/responses, no secrets or image bytes in telemetry.
- Empty signup lists preserve existing signup; populated lists use exact email OR exact domain.
- Existing media CRUD, quotas, prompt builders, model constraints and feature flags remain authoritative.
- Schema owned by admin repository; deployment schema precedes app deployments.

## Review Focus
- Concurrent stale mix/config edits must not overwrite another admin's changes.
- Missing or incompatible chain definitions stop provider calls without quota leaks.
- A provider success followed by media-save failure remains distinguishable from provider failure.
- Telemetry finalization failure after successful save still returns media success and never retries generation.
- Existing auth profile trigger and existing users survive signup restrictions.

### Task 1: Database configuration and observability
Files: supabase/migrations/20261029000000_observability.sql, supabase/tests/observability.sql, scripts/test-db.mjs.
Interfaces: admin_observability_list(p_resource,p_query,p_page), admin_observability_record(p_resource,p_id), admin_configuration_save(p_resource,p_record), admin_configuration_delete(p_resource,p_id,p_version), admin_chain_mix_save(p_chain_id,p_enabled,p_weight,p_version); service-only begin_generation_request(p_user_id,p_purpose,p_prompt,p_metadata), record_llm_response(p_request_id,p_response), finish_generation_request(p_request_id,p_generation_id,p_error_code).
- [ ] Write DB assertions for CRUD, normalizations, read denial, stale edits, fixed registry resolution, log/media correlation and signup policy; run and observe missing-function failure.
- [ ] Implement additive migration, fixed resource mapping and service-only recording; run DB suite including existing compatibility.
- [ ] Commit validated schema.

### Task 2: Admin resource pages and forms
Files: lib/admin-resources.ts, components/configuration-form.tsx, app/(admin)/[resource]/page.tsx, app/(admin)/[resource]/[id]/page.tsx, app/(admin)/configuration-actions.ts, components/nav.tsx, app/globals.css, tests/admin-resources.test.ts.
Consumes: Task 1 RPCs. Produces: all assignment routes and typed server-owned resource definitions; normalizeConfiguration(resource,input).
- [ ] Write validation/UI behavior assertions for field allowlists, bounds, foreign keys, protected read-only resources and deletion confirmation; run failing tests.
- [ ] Implement searchable paginated lists, meaningful detail links, typed forms/selects, stale-version feedback, mix controls and signup-policy explanation.
- [ ] Run unit tests, lint and build; commit.

### Task 3: Creation runtime telemetry
Files in creation repo: src/lib/observability/registry.ts, telemetry.ts, telemetry.test.ts; three generation route/provider files; route tests as needed.
Consumes: Task 1 service-only RPCs. Produces: withGenerationTelemetry(user,purpose,input,operation), observed provider wrapper with bounded allowlisted metadata.
- [ ] Test initialization failure prevents execution; unsupported registry stops execution; success returns despite telemetry-finalization failure; provider/save failures retain separate statuses; redaction/truncation; request IDs prevent duplicate provider response records.
- [ ] Instrument three authenticated validated generation workflows and provider boundaries; preserve existing quotas and prompt builders.
- [ ] Run full creation suite, lint and build; commit.

### Task 4: Review, deployment and release evidence
Files: docs/verification.md, external assignment-7-evidence release notes.
- [ ] Fresh whole-change review; fix important findings with regression tests.
- [ ] Apply migration and rollback tests through authorized Supabase session; verify anonymous/non-admin denial.
- [ ] Push approved implementation branches and deploy both applications; verify SHA mappings, OAuth redirects, new pages, incognito app login wall, and protection settings.
- [ ] Prepare two verified commit-specific URLs; record live-test limitations without fabricating provider calls or course submission.
