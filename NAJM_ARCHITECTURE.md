# NAJM_ARCHITECTURE.md
Technical architecture of the Najm Crew Intelligence Platform (CIP). Describes services, the data model, request
flows, the configuration/authorization model, and dependencies. Grounded in the `najm_complete` Master Archive as of
2026-07-08. Known deviations between this description and desired behaviour are cross-referenced to
`plans/NAJM_PRELAUNCH_AUDIT.md` (finding IDs like **F3**).

## 1. Topology (three tiers)
```
┌────────────────────────┐     Firebase ID token (Bearer)      ┌──────────────────────────────┐
│  Flutter app           │  ─────────────────────────────────▶ │  Python services (FastAPI)   │
│  (iOS / Android)        │        or  X-Service-Token           │  one app, many routers       │
│  Riverpod, Dio, Hive    │                                      │  /v1/*  (Cloud Run)          │
└───────────┬────────────┘                                       └───────────────┬──────────────┘
            │  callable + Firestore SDK                                           │  Firebase Admin SDK
            ▼                                                                     ▼
┌────────────────────────┐        triggers / callables          ┌──────────────────────────────┐
│  Firebase              │ ◀──────────────────────────────────▶ │  Firestore + Storage + Auth  │
│  Cloud Functions (TS)   │                                      │  (system of record)          │
└────────────────────────┘                                       └──────────────────────────────┘
        ▲
        │ Firestore SDK (admin console)
┌────────────────────────┐
│  Admin Panel (static    │
│  single-page HTML/JS)   │
└────────────────────────┘
```
- **Flutter app** (`flutter_app/`) — client. State via Riverpod, HTTP via Dio, local storage via Hive (partial — see **F13**).
- **Python services** (`python_services/`) — the engines, a single FastAPI app (`main.py`) mounting one router per domain.
- **Cloud Functions** (`firebase/functions/`, TypeScript) — Firestore triggers, admin callables (approve/reject/suspend, admin management), notifications, the account-deletion pipeline, and some AI/summary orchestration.
- **Admin Panel** (`admin_panel/index.html`) — a static SPA that talks directly to Firestore (and, for subscription/knowledge config, to the Python admin endpoints).
- **Firestore / Storage / Auth** — system of record.

## 2. Python service surface (`python_services/main.py`)
Each router is mounted with an auth dependency:

| Prefix | Router | Auth dependency | Engine module |
|---|---|---|---|
| `/v1/parser` | Excel roster parser | service token | `parser/` |
| `/v1/upload` | PDF parser | service-or-user | `parser/` |
| `/v1/prn` | PRN workflow | service-or-user | `parser/` |
| `/v1/legality` | **Trade legality** | service-or-user | `legality/engine.py` (**14h/15h rules — F3**) |
| `/v1/ai` | AI assistant | service-or-user | `ai/nlp_router.py` (grounds on `legality` rules — F3) |
| `/v1/ranking` | Smart ranking | user | `ranking/` |
| `/v1/auto-bid` | Auto-Bid | service-or-user | `auto_bid/engine.py` |
| `/v1/salary` | Salary calculator | service-or-user | `salary/` |
| `/v1/trade-intel` | Trade intelligence | user | `trade_intel/` |
| `/v1/intelligence` | PDF intelligence | service-or-user | `intelligence/` |
| `/v1/layover` | Layover intelligence | service-or-user | `layover/` |
| `/v1/trade` | Trade recommendations | service-or-user | `trade_engine/` → `recommendation_engine/`, `compatibility_scoring/` |
| `/v1/rest` | **Rest & legality** | user | `rest_engine/` (**10h/11h rules — F3**) |
| `/v1/knowledge` | Knowledge Engine | user | `knowledge_engine/` |
| `/v1/subscription` | Subscription/feature gate | in-router admin/user checks | `subscription_engine/` |

**Note the F3 hazard visible in this table:** `/v1/legality` and `/v1/rest` are two different engines with two
different, conflicting FTL rule sets, both reachable by the client.

## 3. Engines
- **Trade recommendation** — `recommendation_engine/engine.py` orchestrates `compatibility_scoring/scorer.py`
  (route, schedule, legality, fatigue, behavioural sub-scores; weights in `WEIGHTS`, cutoff `MIN_SCORE_THRESHOLD=30`).
  Behavioural signal via `behavioral_learning/` + `preference_engine/`.
- **Auto-Bid** — `auto_bid/engine.py` ranks lines against a learned preference vector using `MODE_WEIGHTS`
  (money/rest/balanced). Optional auto-submit of the top suggestions.
- **Rest / Legality / Fatigue** — `rest_engine/`: `calculator.py` (FDP/rest math), `legality.py` (`LegalityEngine`,
  violations/warnings), `fatigue.py` (FRMS scoring), `rules.py` (`RulesProfile` + four built-in profiles),
  `timezone_utils.py` (WOCL). **Rule values are hardcoded here.**
- **Trade legality** — `legality/engine.py`: a *separate* `LegalityEngine` with `FTLRules`/`DEFAULT_RULES`, forward &
  backward rest checks, cumulative 7/28-day windows. **Rule values are hardcoded here too, and differ from `rest_engine` (F3).**
- **AI assistant** — `ai/nlp_router.py`: intent classification → filter/legality/knowledge/chat handlers; injects an
  FTL grounding block from `legality.engine.DEFAULT_RULES`; enforces per-user daily cap (`AI_DAILY_FREE_LIMIT`, env — **F1**);
  cite-or-refuse prompt. Design is sound; the grounding **source** is the F3 problem.
- **Knowledge Engine** — `knowledge_engine/`: `extractors` → `chunker` → `embeddings`/`vector_store` → `retrieval_service`,
  with `storage_service`, `indexing_service`, `version_diff`, and admin upload/replace in `router.py`
  (privilege `manage_knowledge_base`). **Complete backend; no Admin-Panel UI to drive it — F9.**
- **Subscription / Feature Gate** — `subscription_engine/`: `config_service.py` (Firestore `subscriptionConfig/main`,
  30 s cache), `feature_gate.py` (`FeatureGate.can_access`, fails closed when enabled), `subscription_service.py`,
  `usage_tracker.py`, `trial_service.py`, `referral_service.py`. **The reference example of config-driven done right.**

## 4. Data model (Firestore — collections observed)
- `users/{uid}` — profile, `accountStatus`, rank, subscription mirror. **`accountStatus` here is not the authz source (F2).**
- `pendingApprovals/{id}` — signup queue (auto-populated by `onUserCreated`).
- `adminUsers/{uid}` / claims — admin & privilege records.
- `flightLines/{id}` — roster lines (rank-scoped reads).
- `trades/{id}`, `tradeContacts/{id}` — trade board and contacts (owner/rank-scoped).
- `bids/{id}` — bids.
- `userLikes/{uid_...}`, `userSaves/{uid_...}`, `userRatings/{uid_...}` — owner-scoped engagement.
- `legalityRules/{id}` — admin-editable FTL overrides; **read by every engine + AI grounding** via `legality/rules_source.py` (TTL-cached, sanity-clamped, fail-safe). Seeded by `scripts/seed_legality_rules.py`. *(Pre-remediation this collection was write-only — audit F4/P0-2.)*
- `subscriptionConfig/main` — the live subscription/feature config (admin-editable).
- `aiUsage/{uid}_{YYYY-MM-DD}` — daily AI rate-limit counters.
- Knowledge documents + versions + Storage objects — manuals, versions, embeddings/index.
- `notifications/{id}` — ad-hoc admin notifications.
- `rosterSources/{uid}_{provider}` — sync connection status (owner-read; service-write; NEVER credentials — double-walled by `assert_no_credentials` + rules).
- `rosterVersions/{id}` — roster version chain per user+provider+period (checksum, leg-level diff).
- `syncEvents/{id}` — sync analytics (service-only; success rate, duration, failures, duplicates).
- `autoBidRefresh/{uid}` — fan-out nudge consumed by the auto-bid engine.

## 5. Key request flows

### Roster sync (v1.4.0-dev) — sources → one pipeline → every engine
**Device-orchestrated, credential-free backend.** A `RosterConnector` on the
device (CAE Crew Access — config-activated, official-integration-only; ICS
calendar feed — live today) fetches the roster with credentials that exist
only in Keychain/Keystore, then `POST /v1/roster-sync/import` runs dedup
(checksum), versioning (leg-level diff), line build with canonical-rules
legality/rest/salary enrichment, supersede-with-history, and the engine
fan-out (salary/FTL/rest triggered; behavior + auto-bid queued;
trade/layover/knowledge on-demand). Priority: CAE Sync → ICS → manual PDF
(`preferred_source`). Design + sequence diagrams: `docs/ROSTER_SYNC.md`.

### Line search — the filter engine (v1.3.0-dev, Golden Rule)
**One endpoint, three modes** (`POST /v1/lines/search`, catalog at
`GET /v1/lines/filters`): *Manual* = validated clauses only; *AI* =
`ai_instruction` → NLP extractor → deterministic bridge → clauses; *Hybrid* =
both, where **manual clauses are locked** — AI clauses on a locked id are
dropped with a written reason. All three converge on the same
`filter_engine.engine` single-pass evaluator (the only result path), then the
transparent `ranking/scorer` (mode weights + per-line reasons). Responses
disclose applied manual/AI filters, dropped-AI reasons, matched-filter
checklists and component scores. Registry: 34 active / 14 pending-field
filters, declarative (`filter_engine/registry.py`). See
`VISION_GAP_ANALYSIS.md` for the pillar matrix and roadmap.

**Trade legality check (app):** app → `/v1/legality/check-trade` with both schedules → `legality/engine.py` builds
post-trade schedules, runs forward/backward rest + cumulative checks against the **effective rules** (canonical GOM 7.5.3 defaults + `legalityRules` admin overrides; provenance stamped in `rules_version`) → returns
violations/warnings.

**Rest check (app):** app → `/v1/rest/*` → `rest_engine` computes FDP/rest/fatigue against `RulesProfile` (10h/11h) →
returns legality + safety score. *(Different numbers than the trade check — F3.)*

**Ask-Najm (AI):** app → `/v1/ai/chat` → daily-cap check (`aiUsage`) → intent classify → for legality intents, ground
on `legality.engine.DEFAULT_RULES` and prefer running a legality check over stating rules from memory → cite-or-refuse.

**Approval lifecycle:** signup → `onUserCreated` adds `pendingApprovals` → admin calls `approveUser`
(sets claim `accountStatus=approved` **and** writes the user doc) → user must refresh ID token for the Python layer and
Firestore rules to see it (**F2**). Suspend/reject set the claim + doc but **do not revoke refresh tokens (F2)**.

**Feature access:** any gated action → `FeatureGate.can_access(uid, feature_key)` → reads `subscriptionConfig/main`;
while `subscriptions_enabled=false`, everything resolves allowed; when enabled, unconfigured keys **fail closed**.
*(Cloud Functions read the master switch from an env var instead — F8.)*

## 6. Authorization & service-auth model
- **User calls** carry a Firebase Bearer token; `utils/auth.py` verifies it and requires `accountStatus==approved`.
  Identity is pinned to the token (`resolve_user_id`) so a user cannot act on another user's id.
- **Service calls** (Cloud Functions → Python) carry `X-Service-Token`; verification **fails closed** (503 if
  `INTERNAL_SERVICE_TOKEN` unset) with constant-time comparison. Service calls may act on behalf of any user id in the
  (trusted) body.
- **Firestore rules** gate reads/writes by `isApproved()` (claim-based) and owner/rank scoping.
- **Admin** privilege via `superAdmin` / `admin` + a privileges list (e.g. `manage_subscriptions`, `manage_knowledge_base`).

## 7. Configuration sources (authoritative map)
Updated by remediation v1.2.0 (was: PART D of `plans/NAJM_PRELAUNCH_AUDIT.md`).

| Config | Source of truth | Notes |
|---|---|---|
| **FTL / rest rules** | `python_services/legality/rules_source.py` `CANONICAL_DEFAULTS` **+ Firestore `legalityRules` overrides** | Single source for all three engines and AI grounding. TTL-cached (env `LEGALITY_RULES_TTL_SECONDS`, default 300 s), fail-safe to defaults, sanity-clamped. Inspect live: `GET /v1/legality/rules`. Seed the admin editor: `scripts/seed_legality_rules.py`. Owner confirmation tracked in `OWNER_DECISION_REQUEST.md`. |
| Subscriptions master switch | Firestore `subscriptionConfig/main` | Read by Python (`config_service.py`) **and** Cloud Functions (env fallback) — split-brain closed (F19). |
| AI daily free limit | `subscriptionConfig/main.aiDailyFreeLimit` → env `AI_DAILY_FREE_LIMIT` → 50 | Identical precedence both sides (F20; pure `resolveAiDailyLimit`, unit-tested). |
| Scoring/ranking weights | Hardcoded by design | Locked by unit tests. |
| Flutter FTL constants | `shared/constants/constants.dart` | **DISPLAY-ONLY** mirrors of the canonical defaults; never used for verdicts (F8). |

## 8. External dependencies
Firebase (Auth, Firestore, Storage, Cloud Functions), Cloud Run (Python), Anthropic API (AI assistant), an embeddings
provider (Knowledge Engine), and — *future only* — RevenueCat (Apple IAP / Google Play). **No Stripe / HyperPay.**

## 9. Build / deploy / CI
CI (`.github/workflows/ci.yml`) spans Flutter, Cloud Functions, Python, and Firestore rules. Rollback runbook and
deploy notes in `docs/devops-runbook.md` and `plans/phase2/rollback-runbook.md`. Store version is `1.0.0+1`
(`flutter_app/pubspec.yaml`); the Master-Archive version is tracked in `VERSION.md`.

## 10. Known architectural risks (status after remediation v1.2.0)
1. ~~Two FTL rule sources that disagree (F3) + dead admin editor (F4)~~ — **CLOSED.** Single source
   (`legality/rules_source.py`) + live `legalityRules` overrides + engine-consistency regression tests.
   Residual: owner sign-off on the canonical values (ODR-001/002/003).
2. ~~Claims-only authz with no refresh-token revocation (F2)~~ — **CLOSED** (pass 1 revocation + pass 2 closed the
   `check_revoked` bypass in the subscription/knowledge admin routers).
3. ~~Split-brain master switch (F8)~~ — **CLOSED** (F19/F20). Flag taxonomy (F5) unchanged — accepted for launch.
4. **Knowledge backend with no admin UI (F9).**
5. ~~No Flutter/Cloud-Functions tests (F10); tests locking in F3 (F11)~~ — **REDUCED**: Flutter unit tests, Functions mapping tests (executed), Firestore/Storage rules tests (CI-executed) added; suites now assert the canonical values. Widget/E2E coverage remains thin (see reports/TESTING_REPORT.md).
6. **Offline caching scaffolded but not wired (F13).**
