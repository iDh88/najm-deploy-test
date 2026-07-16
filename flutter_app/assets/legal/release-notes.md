# VERSION HISTORY — Najm Crew Intelligence Platform (CIP)

> Master Project Archive changelog. Newest release at the top. History is **appended**, never overwritten.
> Note: the "Semantic Version" below is the **project/master-archive** version. The Flutter app's own store version (`flutter_app/pubspec.yaml`) is `1.0.0+1` and is unchanged by this release.

---

## 1.6.0-dev — 2026-07-14

### Summary of Changes
**Profile screen rebuilt** — ten sections, every value sourced from a service that
really exists. The screen composes existing providers (`entitlementProvider`,
`syncStatusProvider`, `rosterSyncServiceProvider`, `authService`,
`credentialManager`); no business logic, service, or model was duplicated.

**New (backend):** `GET /v1/ai/status` (`ai/status_router.py`) — reports AI status from
real sources only: `status` is `online` **only** if `ANTHROPIC_API_KEY` is configured
(otherwise `unconfigured`, with the reason), `model` and `engines` come from the shared
`CLAUDE_MODEL` / `ENGINE_REGISTRY` constants rather than a second hardcoded list, and the
knowledge-base counts/timestamps are read from Firestore. An empty knowledge base returns
**no timestamp** — the UI shows "—", never a reassuring "Today". `trialStartedAt` is now
exposed on `/me/entitlement` so the subscription card's Start date is real (paid plans
have no start date on the payload, so it renders "—" rather than inventing one).

**Honesty decisions (deliberate, not oversights):**
- **Email Import is rendered as "Not available yet."** It does not exist anywhere in the
  codebase. The spec lists it as a provider; the roster catalog now returns it with a
  `not_implemented` availability so the UI can be truthful. Excel import, by contrast, is
  **real** (Cloud Function → `/v1/parser/parse`) and is listed as available.
- **Roster Sources renders the live backend catalog**, including provider priority and
  each provider's own availability note (e.g. CAE's "awaiting official integration").
  Nothing about provider state is hardcoded in the UI.
- **Optimization Mode + ranking preferences were preserved, not deleted.** The old profile
  screen contained two genuinely working features; they were lifted verbatim into
  `preferences_screen.dart` (same `authService.updateUserMode` / `updatePreferences`
  calls) and linked from the new Profile. No regression.
- **Offline is not an error.** The sync card shows the cached roster and says NAJM will
  resync automatically, because that is exactly what the scheduler does.

**Zero-Knowledge reinforced:** the Security card reads **no credential source at all** —
it cannot leak one by construction, and a widget test asserts no credential-shaped word
ever renders. Disconnect-All wipes Keychain/Keystore (`wipeAll` after per-provider
`disconnect`) and **keeps roster history**. Logout **preserves** credentials, per the
directive: they are erased only when a user explicitly disconnects a source.

**Fixed:** `AppConstants` carried `https://cip.app/privacy`, `/terms`, `/help` and
`support@cip.app` — a domain that does not exist. Nothing consumed them (verified), so no
live link was broken, but they are gone: Terms, Privacy and Release Notes now render
**offline, in-app** from `assets/legal/` via `LegalDocumentScreen`, and the real support
addresses are in one place.

### Verification (executed)
**449 passed · 0 failed · 0 errors** (was 436) — 13 new backend tests
(`test_profile_backend.py`: AI status is never "online" without a key; model/engines come
from the shared constants; an empty KB yields no timestamp; a KB read failure degrades
instead of throwing; Excel real; Email `not_implemented`; provider priority order).
Flutter: `test/unit/profile_test.dart` — sync-badge matrix (an error never shows green),
trial/renewal day maths (never negative, `null` → "—"), mailto construction, and the
SecurityCard leak assertion — runs in CI. py_compile clean (139 files); F821 0; 127 Dart
files balanced; imports resolve (2 codegen parts).

### Release status
v1.2.0's GO-WITH-CONDITIONS verdict and its four conditions remain **unchanged**.
ODR-004 (architectural) remains open and non-blocking.

---

## 1.5.0-dev — 2026-07-13

### Summary of Changes
**Architecture: Zero-Knowledge Credential Model adopted as a PERMANENT platform rule**
(owner directive), plus the two gaps that audit exposed — both of which would have
passed every existing test while failing real users.

**Gap 1 — automatic sync after restart was not actually wired.** `RosterSyncBootstrap`
existed but had **zero callers**: the `SyncScheduler` was never started, so credentials
survived a restart and still nothing synced until the user opened Settings. Now mounted
above every route in `app/app.dart` — app start, resume, and connectivity-regained all
trigger sync with no login prompt. The directive's session criterion is now true at
runtime, not just in a class.

**Gap 2 — the two ICS parsers had no parity guard.** Zero-knowledge requires the DEVICE
to normalize, which created a second implementation (`ics_normalizer.dart`) alongside the
canonical `ics_parser.py`. Only one runs in this suite; drift would ship crew a different
roster than the backend would have produced, silently, with everything green. (The Dart
file's own comment *claimed* a shared golden fixture locked them together — the fixture
and its test did not exist.) Now they really are locked:
`test_fixtures/roster_sync/ics_golden.{ics,json}` — the JSON **generated from the
canonical parser** — asserted by `tests/unit/test_ics_parity.py` (here) and
`test/unit/ics_normalizer_test.dart` (CI). Fixture durations are quarter-hour multiples
because Python rounds half-to-even and Dart rounds half-away-from-zero.

Also delivered:
- `docs/ZERO_KNOWLEDGE_CREDENTIALS.md` — the permanent rule: the mandated flow, the six
  walls (secure enclave · normalized-only uploads · inbound guard · outbound guard · log
  redaction · Firestore rules), the forbidden-field list enumerated verbatim from the
  directive, dual client/server provider models, and every acceptance criterion mapped to
  executed evidence.
- **ODR-004** — the architectural approval gate. Server-managed credentials can never be
  enabled by ops config alone: `CAE_INTEGRATION_MODE=enterprise_service` is ignored unless
  `ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL` carries the owner's explicit reference. Approval
  is per-provider, never platform-wide.
- Honest finding recorded, behaviour unchanged: the aircraft-code pattern does not match
  `77W` (it expects `77`+digit, e.g. `773W`/`777`), so such legs carry an empty
  `aircraftType`. The golden fixture now locks this real behaviour rather than papering
  over it; fixing the pattern is a deliberate two-sided change.

Verification (executed): **436 passed · 0 failed** (was 430) — 6 new golden-parity tests;
Dart normalizer parity + private-event-never-uploaded assertions run in CI. Full battery:
py_compile clean, F821 0, Dart imports resolve (2 codegen parts), 119 Dart files balanced.

### Release status
v1.2.0's GO-WITH-CONDITIONS verdict and its conditions remain **unchanged**. New open
item: **ODR-004** (architectural, not blocking — nothing is gated on it today).

---

## 1.4.0-dev — 2026-07-12

### Summary of Changes
**Feature: Automatic Roster Synchronization** — connect a roster source once; NAJM keeps
the roster synchronized, versioned, deduplicated, and fans every successful import out to
the intelligence engines automatically. Manual PDF upload remains as the fallback source.

**Spec constraints honored structurally, not by promise:**
- **No unofficial integrations, ever.** The CAE Crew Access provider ships
  *config-activated*: it is fully wired (catalog, connect flow, sync routing) but reports
  `pending_official_integration` — and refuses to accept credentials — until an official
  API/enterprise agreement is configured via `CAE_INTEGRATION_BASE_URL` +
  `CAE_INTEGRATION_MODE` (`device_oauth` | `enterprise_service`). No scraping, no
  reverse engineering, no fake success states. Activation checklist: `docs/ROSTER_SYNC.md`.
- **Credentials never touch NAJM servers.** Two independent walls: (1) client-side, all
  secrets live only in iOS Keychain / Android Keystore (`flutter_secure_storage`,
  `encryptedSharedPreferences`) via `CredentialManager`; connectors authenticate
  device-side and upload only roster *data*. (2) server-side, `assert_no_credentials`
  scans every raw import body **before parsing** and rejects with 422 if credential-shaped
  fields appear. Errors never echo URLs or tokens.

Delivered:
- Backend `python_services/roster_sync/` — provider catalog with priority
  (CAE > ICS feed > manual PDF), connection registry (honest `awaiting_official_integration`
  status), `POST /import` pipeline: leak-guard → parse → **checksum dedup short-circuit**
  → leg-level diff → line build (canonical-rules enrichment) → **version history**
  (previous line deactivated, never deleted) → engine fan-out → sync bookkeeping +
  `syncEvents` analytics. `GET /status` computes the preferred source per spec priority.
  Endpoints: `GET /v1/roster-sync/providers`, `POST/DELETE /connections`,
  `POST /connections/{id}/sync-now`, `POST /import`, `GET /status`.
- **ICS Calendar feed provider is live end-to-end today** (real parser, https-only,
  validates before storing the feed URL as a credential) — proving the full pipeline with
  an integration that requires no third-party agreement.
- Engine fan-out on every import: salary, FTL/legality, rest run immediately;
  behaviorEvents recorded; auto-bid refresh queued; trade/layover/knowledge marked
  on-demand (they read the fresh line at next use). No manual upload required.
- Flutter `lib/core/roster_sync/` — `CredentialManager`, `RosterConnector` interface +
  registry (future providers: implement one class), CAE + ICS connectors,
  `RosterSyncService` (connect/disconnect/syncNow/syncAll), `SyncScheduler` (6h periodic
  + on-connectivity-restored + on-app-resumed), `ConnectionHealthMonitor`; Riverpod
  providers. Settings → **Roster Sources** screens: catalog with Recommended/Active
  badges, provider connect flow (dynamic auth fields), **Sync Status screen** exactly per
  spec (Status / Last Sync / Imported Flights / Last Successful Import / Next Sync:
  Automatic / Sync Now / Disconnect-with-secure-wipe).
- Failure semantics per spec: failed sync **keeps the cached roster** (previous line
  stays active), meaningful errors, retry; offline-first — engines keep working on the
  latest synced roster; scheduler resyncs when connectivity returns.
- Docs: `docs/ROSTER_SYNC.md` (component map, 4 sequence diagrams, security model,
  CAE activation checklist), OpenAPI (all 6 paths + schemas), architecture §4/§5 updates.

Verification (executed): full suite **382 passed · 0 failed** (34 roster-sync backend
unit tests; 5 API integration tests running against an in-memory Firestore, classified
skipped-offline under the no-network harness, green in CI); Flutter
`test/unit/roster_sync_test.dart` covering credential namespacing/wipe scoping, ICS
validation + token-never-leaked assertions, CAE-pending stores-nothing, health matrix.

### Release status
v1.2.0's GO-WITH-CONDITIONS verdict and conditions remain **unchanged**; this is additive
feature work. New rollout note: deploy updated Firestore rules/indexes (rosterSources,
rosterVersions, syncEvents, autoBidRefresh already covered in `firebase/`).

---

## 1.3.0-dev — 2026-07-11

### Summary of Changes
**Feature: AI + Advanced Manual Filters — the filter-engine core.** Implements the product
vision's Golden Rule server-side: *the filtering engine is the search engine; AI only
generates filters, ranks, and explains.* One endpoint, three modes.

- NEW `python_services/filter_engine/` — declarative filter **registry** (48 registered:
  **34 ACTIVE** across all 8 vision categories, grounded in real `flightLines` fields incl.
  leg-derived red-eye/haul/time-of-day/consecutive-days/per-layover/per-rest; **14
  REQUIRES_FIELD** listed honestly in the catalog with the missing data named, never
  faked), typed **schema** validation, compile-once **engine** (single pass, AND
  semantics, list-quantified ranges), **hybrid** merge with hard lock precedence
  (manual clauses can never be overridden or dropped by AI — AI clauses on locked
  filters are rejected with a written reason), deterministic **ai_bridge** from the
  existing NLP extractor, and the mounted router.
- NEW API: `GET /v1/lines/filters` (catalog for UI rendering) ·
  `POST /v1/lines/search` (manual / AI / hybrid in one contract; response returns
  applied manual filters, applied AI filters, **dropped AI clauses with reasons**,
  per-line matched-filter checklists, component scores and plain-language reasons —
  no black boxes).
- `ranking/scorer.py`: explanations now also returned as a structured `reasons[]`
  (EN+AR strings kept); `UserPreferences.min_rest_hours` default now derives from the
  canonical rules (was a hardcoded 10.0 — last orphan of the P0 unification).
- `ai/nlp_router.py`: the chat filter intent additionally emits
  `rich_content.filter_query` — validated engine clauses + rejected items — so the
  app can pipe chat straight into the same search endpoint (legacy `filter_result`
  kept for back-compat).
- Flutter contract: `core/models/filter_models.dart` + `core/services/line_search_service.dart`
  (plain Dart, no codegen dependency).
- Docs: `VISION_GAP_ANALYSIS.md` (vision-pillar → SHIPPED/PARTIAL/PLANNED matrix +
  phased roadmap B–E), OpenAPI paths/schemas for the two endpoints.
- Tests: NEW `tests/unit/test_filter_engine.py` — **33 tests executed green**
  (registry integrity/breadth, per-kind predicate truth tables on realistic line
  fixtures, list-quantifier semantics, malformed-value validation, **Golden-Rule
  lock precedence**, AI-failure degradation, bridge mapping incl. Arabic rank-mode
  inference, end-to-end 3-mode search with transparency assertions).
  Full suite: **348 passed · 0 failed** (was 315).

### Release status
v1.2.0's GO-WITH-CONDITIONS verdict and its four conditions are **unchanged**; this is
additive feature work on top of the release candidate. UI for the three workflows is
Phase C of the gap-analysis roadmap.

---

## 1.2.0 — 2026-07-11

### Summary of Changes
**Full-repository release remediation.** Every finding from `FORENSIC_RELEASE_AUDIT.md` and the TS/Dart static
addendum was re-verified against code and either fixed or dispositioned with a written verdict; defects discovered
during the pass (including two compile-breakers no audit had caught) were fixed alongside. **The P0 safety defect is
closed:** all three legality engines and the AI grounding now derive every FTL threshold from one source
(`python_services/legality/rules_source.py`), and the Admin Panel's `legalityRules` editor is live at runtime.
No regulatory value was guessed — the canonical defaults are the project's own GOM-7.5.3-cited set, and every value
requiring owner confirmation is tracked in `OWNER_DECISION_REQUEST.md` (ODR-001/002/003).

### Highlights (full detail: REMEDIATION_CHANGELOG.md "Pass 2", reports/*)
- **Safety (P0-1/P0-2):** single rule source + live admin overrides + `GET /v1/legality/rules` + engine-consistency
  regression tests; conservative FDP intersection pending ODR-002; augmented-crew 18 h rest enforced.
- **Security:** upload identity pinned to token + 20 MB cap; `check_revoked` bypass closed in two admin routers;
  approve-flow claim clobbering fixed; storage rule added for layover photos.
- **Broken bridges fixed:** Functions→Python payloads (422 on every call), Flutter intelligence client
  (unauthenticated, wrong port, unprefixed paths), layover navigation (nonexistent route scheme).
- **Compile-breakers fixed:** `lines_screen.dart` unclosed widget tree; missing `NajmTheme`/`AppConstants`/
  `ContentFilter` files reconstructed from call sites; 20 wrong Dart import paths; `tsconfig` target vs
  `Promise.allSettled`; `firebase-functions/v1` entrypoint (A1).
- **Features completed:** Saved Places end-to-end; Arabic locale actually enabled + persisted; real file picker +
  authenticated identity in the intelligence upload flow.
- **CI/CD & governance:** ruff blocking; deploy + rollback + security-scanning workflows; CODEOWNERS; Dependabot;
  Firestore/Storage rules tests + Functions mapping tests wired into CI.
- **Verification (offline harness; CI re-runs real toolchain):** Python 258/258 executed tests green; `tsc` strict
  clean; 13/13 mapping tests executed; 104 Dart files structurally verified.

### Release Gate
`reports/RELEASE_READINESS.md` — **GO-WITH-CONDITIONS** pending ODR sign-off and first green CI run.


---

## 1.1.1 — 2026-07-08

### Summary of Changes
**Documentation & governance release. No code, schema, or config was changed.** Adds the project's governing
documents and the first comprehensive business-logic/configuration audit. This release exists to (a) answer the
open questions from the owner's review, (b) establish the supreme project reference, and (c) define the pre-launch
certification gate. All findings are documented, not yet remediated.

### Added Documents
- `NAJM_MASTER_PROJECT_DIRECTIVE.md` (root) — the supreme project reference (20 sections + Permanent Rules).
- `NAJM_ARCHITECTURE.md` (root) — technical architecture, services, data model, flows, dependencies.
- `plans/NAJM_PRELAUNCH_AUDIT.md` — evidence-based business-logic & configuration audit (findings F1–F16).
- `plans/PHASE_3_operational_readiness_and_DR_certification.md` — the new launch-gate phase with executable checklists.

### Key Findings Recorded (see the audit for full detail + evidence)
- **P0 · F3** — two conflicting hardcoded FTL/rest rule sets (`legality/engine.py` 14h/15h vs `rest_engine/rules.py`
  10h/11h); the Rest screen, the trade legality check, and the AI each use a different set for the same regulation.
- **P0 · F4** — the Admin Panel "Legality Rules" editor writes to `legalityRules`, which **no engine reads** (edits have no effect).
- **P1 · F2** — `accountStatus` is enforced from token claims only (no SSOT; suspend does not revoke refresh tokens).
- **P1 · F9** — Knowledge Engine backend is complete but has **no Admin-Panel UI** to upload manuals.
- **P1 · F10/F11** — no Flutter/Cloud-Functions/push/admin tests; existing tests **lock in** the F3 inconsistency.
- **P2 · F1** — `AI_DAILY_FREE_LIMIT` is an env var (×2 services), not admin-configurable.
- **P2 · F8** — `SUBSCRIPTIONS_ENABLED` split-brain (Cloud Functions read env; Python reads Firestore config).
- **P2 · F5** — no feature flags for Auto-Bid / Analytics / Smart Search / Knowledge Center.
- Cleanup (verified still open): placeholder logo, live Arabic toggle, `stripeCustomerId` field, incomplete Hive caching.

### Changed / Fixed / Removed
- None. (This release adds documents only.)

### Configuration / Database Changes
- None.

### Migration & Rollback Notes
- No migration. Rollback = remove the four added documents; nothing else is affected.

### Required Next Decision (owner)
- Confirm the **authoritative FTL numbers** (the `legality/engine.py` GOM-cited set vs the `rest_engine` set) before
  F3/F4 can be remediated. See `plans/NAJM_PRELAUNCH_AUDIT.md` PART G.

---

## 1.1.1 — 2026-07-08

### Summary of Changes
**Documentation & governance only — no code changed.** Adds the comprehensive business-logic/configuration audit that
Phases 0–2 did not produce, plus the two governance documents and the pre-launch certification phase. This release
records findings; it does **not** modify engines. The safety-critical fixes it identifies (chiefly the FTL rule
unification) are deliberately left for a follow-up release once the project owner confirms the authoritative rule set.

### Added
- `plans/NAJM_PRELAUNCH_AUDIT.md` — evidence-based audit answering the open questions (AI daily limit source,
  `accountStatus` single-source-of-truth, hardcoded-rule inventory) with a severity-ranked findings register
  (F1–F16), a configuration-ownership matrix, a test-coverage matrix, and a prioritised remediation roadmap.
- `NAJM_MASTER_PROJECT_DIRECTIVE.md` — the supreme project reference (vision, principles, config/admin/AI/testing
  policy, Permanent Rules).
- `NAJM_ARCHITECTURE.md` — technical architecture (services, data model, flows, auth model, config sources, risks).
- `plans/PHASE_3_operational_readiness_and_DR_certification.md` — the new pre-launch certification phase (user/admin/
  engine/push/offline/load/backup-restore/DR/rollback matrices with pass criteria and a sign-off gate).

### Key findings recorded (see the audit for detail)
- **P0 — F3:** two conflicting hardcoded FTL rule sets (`legality/engine.py` 14h/15h vs `rest_engine/rules.py` 10h/11h);
  Rest screen, Trade legality, and the AI can each report different numbers for the same regulation.
- **P0 — F4:** the Admin "Legality Rules" editor writes to a `legalityRules` collection that no engine reads — edits
  have no effect.
- **P1 — F2:** `accountStatus` is enforced from token claims only (no refresh-token revocation on suspend; Firestore
  user doc not consulted for authz).
- **P1 — F9:** Knowledge Engine backend is complete but has no Admin-Panel UI. **F10/F11:** no Flutter/Cloud-Functions/
  push/admin tests, and existing tests lock in the F3 inconsistency.
- **P2 — F1/F8/F5:** `AI_DAILY_FREE_LIMIT` and the Cloud Functions copy of `SUBSCRIPTIONS_ENABLED` are env-only;
  feature-flag taxonomy incomplete. **F13:** offline Hive cache adapters commented out. Cleanup items F12/F14/F15/F16 still open.

### Not changed
- No engine, endpoint, rule value, schema, or dependency was modified. Store version remains `1.0.0+1`.

---

## 1.1.0 — 2026-07-08

### Summary of Changes
First consolidated Master Archive. Folds in the Phase 0 critical fixes, the Phase 1 security & foundation hardening, and the Phase 2 production-readiness work into one backward-compatible release. No feature was removed from the user-facing app; the subscription-ready UI is retained with billing disabled (free launch).

### Added Features
- Server-side account-approval enforcement on all Python user endpoints.
- Per-user daily AI rate limiting on the real `/v1/ai/chat` path (`AI_DAILY_FREE_LIMIT`).
- AI regulatory **grounding**: the assistant now uses the app's actual FTL thresholds and follows cite-or-refuse (never invents a regulation).
- Structured, secret-redacting JSON logging (`utils/logging_config.py`) wired into service startup.
- CI pipeline (`.github/workflows/ci.yml`) across Flutter, Cloud Functions, Python, and Firestore rules.
- Automated tests: identity unit tests (executable-proven) and an AI-grounding eval set.

### Modified Features
- Identity on 10 dual-caller endpoints is now derived from the verified token for user calls (`resolve_user_id`); service calls still act on behalf of a user.
- Firestore rules scoped to owners for `tradeContacts`, `userLikes`, `userSaves`, `userRatings`, and usage counters.
- Feature gate now **fails closed** on unconfigured feature keys once subscriptions are enabled (was fail-open).
- `weeklyProfileRebuild` paginates **all** approved users (was capped at 500) with bounded concurrency + 540 s timeout.
- Admin push-token lookups in `onChangeSummaryGenerated` parallelised (was N sequential reads).
- AI service URL and other endpoints read from `AppConfig` (was hard-coded `localhost:8080`).

### Fixed Bugs
- Service-auth token verification failed **open** when unset → now fails closed (503) with constant-time compare.
- CORS origins parsed as `"".split(",")` → `['']` (malformed) → now a clean list.
- `auth_provider.dart` rank field referenced a non-existent symbol → fixed.
- `admin` SDK import shadowed by a loop variable in `onChangeSummaryGenerated` → renamed.
- Build-blocking `pubspec.yaml`: declared-but-absent `assets/icons/` and Inter fonts → removed; referenced `najm_logo.png` provided (placeholder).

### Removed Components
- Legacy **Stripe** webhook + claims-overwrite path (`stripeWebhook`).
- Two redundant subscription systems (collapsed to one Firestore-config-driven gate).
- Dead duplicate `firebase/functions/src/triggers.ts`.
- Four empty `functions/src` subdirectories (`api`, `middleware`, `utils`, `triggers`).
- Stripe/HyperPay Flutter dependency and env entries.

### Security Improvements
- All previously-open Python routers now require authentication; service token fails closed and the service refuses to boot without `INTERNAL_SERVICE_TOKEN`.
- Authenticated users can no longer act on another user's id (token-pinned identity).
- Account approval enforced centrally; owner-scoped Firestore rules; `/openapi.json` gated off outside development.
- Account-deletion pipeline rewritten to be PDPL-complete (all per-user collections + Storage, Auth deleted last, idempotent).
- Secret redaction in logs; PDPL stance documented (no roster/PII in logs).

### Performance Improvements
- N+1 admin token reads parallelised.
- Weekly profile rebuild paginated + bounded-parallel (no longer silently skips users past 500).

### Files Modified (by area)
- **Python:** `main.py`, `utils/auth.py`, `utils/logging_config.py` (new), `ai/nlp_router.py`, `auto_bid/engine.py`, `trade_engine/router.py`, `subscription_engine/feature_gate.py`, `tests/unit/test_auth_identity.py` (new), `tests/eval/test_ai_grounding.py` (new).
- **Cloud Functions:** `firebase/functions/src/index.ts` (auth wiring, deletion pipeline, performance), removed `triggers.ts` + 4 empty dirs.
- **Firestore:** `firebase/firestore.rules`.
- **Flutter:** `pubspec.yaml`, `assets/images/najm_logo.png` (new placeholder), `core/auth/auth_provider.dart`, 5 service/screen files (endpoint config).
- **Config/CI:** `.env.example`, `.github/workflows/ci.yml` (new).

### Database Changes
- No schema migration required. New Firestore collection used at runtime: `aiUsage/{uid}_{date}` (AI rate-limit counters). Deletion pipeline reads a broader set of per-user collections.

### Configuration Changes
- Added: `SUBSCRIPTIONS_ENABLED=false`, `AI_DAILY_FREE_LIMIT=50`, `LOG_LEVEL`. `ENV=development` now also controls `/openapi.json` exposure. Removed Stripe/HyperPay vars.

### Migration Notes
- Set `INTERNAL_SERVICE_TOKEN` in every environment (the service fails closed without it).
- Set `ALLOWED_ORIGINS` for the admin panel origin (empty blocks all cross-origin).
- Just-approved users may need an ID-token refresh before the Python layer sees `approved` (same as Firestore rules).

### Rollback Notes
- Per-component rollback plans in `plans/phase2/rollback-runbook.md` (rules / functions / Cloud Run revision / mobile staged rollout). All releases are backward-compatible so components roll back independently.

### Known Issues / apply locally (this environment can't run Dart codegen or install deps)
- Replace the **placeholder** `assets/images/najm_logo.png` with the real logo.
- Remove the leftover `stripeCustomerId` Freezed field via `build_runner` (source edit is documented; codegen must run locally).
- Apply the T3 UI/accessibility pass and remove the dead Arabic-locale toggle (traced steps in `plans/phase2/production-readiness.md`).
- Reconcile the inferred deletion-pipeline collection field names against the data model (a wrong field only under-deletes).
- Nothing Dart/TS was compiled and Python deps weren't importable here — run `flutter analyze` / `tsc --noEmit` / `pytest` / rules emulator before release.

---
<!-- Append the next release ABOVE this line. Do not edit entries below. -->
