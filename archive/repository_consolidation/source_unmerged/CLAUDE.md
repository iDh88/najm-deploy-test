# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Najm ("⭐" / نجم) — Crew Intelligence Platform (CIP): an unofficial scheduling assistant for
Saudi Airlines cabin crew. Three deployable pieces sharing one Firestore backend:

- `flutter_app/` — iOS/Android client (Flutter 3.x, Riverpod, GoRouter, Hive, Dio).
- `python_services/` — the engines: one FastAPI app (`main.py`) mounting one router per
  domain, deployed to Cloud Run.
- `firebase/functions/` — TypeScript Cloud Functions: Firestore triggers, admin callables,
  notifications, account deletion.
- `admin_panel/` — a static single-file SPA (`admin_panel/index.html`) that talks directly to
  Firestore and to Python admin endpoints. Not a built frontend project despite the
  `package.json`/`src/` scaffolding.

Read `NAJM_ARCHITECTURE.md` before making non-trivial changes — it is a maintained, accurate
map of topology, the Python router table, the data model, and known architectural risks
(cross-referenced to finding IDs like **F3**, **F9**, **F13**). Treat it as more current than
this file for anything about *why* the system is shaped the way it is. `plans/STATUS.md` has
the remediation history (Phase 0–2) and a short list of things intentionally left for local
follow-up (asset swaps, a dead Arabic toggle, a Freezed field removal).

## Commands

### Flutter app (`flutter_app/`)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerates *.freezed.dart / *.g.dart — required before analyze/test, they are not committed
flutter gen-l10n                                            # after editing lib/shared/l10n/app_{ar,en}.arb
flutter analyze                                             # static analysis gate (analysis_options.yaml: flutter_lints + strict-casts/strict-raw-types)
flutter test                                                # all tests
flutter test test/unit/                                     # unit only
flutter test test/widget/                                   # widget only
flutter test test/unit/roster_sync_test.dart                # single file
```

### Python services (`python_services/`)
```bash
python3.11 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export INTERNAL_SERVICE_TOKEN=dev-token   # required — the app refuses to start without it (fail-closed)
uvicorn main:app --reload --port 8080

ruff check .                              # BLOCKING lint gate; scope is deliberately narrow — see ruff.toml (only E9/F63/F7/F82 selected)
pytest -q                                 # all tests
pytest tests/unit/test_legality.py -v     # single file
pytest tests/unit/test_rest_engine.py::TestName::test_case -v   # single test
pytest tests/ --cov=. --cov-report=html
```
Test layout: `tests/unit/`, `tests/integration/`, `tests/eval/` (AI-grounding eval set).

### Firebase Functions (`firebase/functions/`)
```bash
npm install
npm run build          # tsc
npx tsc --noEmit        # typecheck only (CI step)
npm test                # builds then runs node:test against lib/*.test.js
npm run lint
firebase emulators:start --only functions,firestore,auth
```

### Firestore/Storage security rules (`firebase/`)
```bash
firebase emulators:exec --only firestore,storage \
  "npm --prefix test install && npm --prefix test test"
```

### Offline verification harness (`tools/offline_harness/`)
Used only in network-isolated environments (mini-pytest + dependency shims + TS stubs) — see
`tools/offline_harness/README.md` for what it can and cannot prove. It is a fallback, not a
replacement for the real toolchains above; CI (`.github/workflows/ci.yml`) is the source of
truth.
```bash
python3 tools/offline_harness/run_tests.py
```

### Seeding / admin
```bash
python scripts/seed_legality_rules.py     # seeds Firestore legalityRules collection (admin-editable FTL overrides)
scripts/setup_super_admin.sh
```

## Architecture

### Request flow
```
Flutter app  --Firebase ID token / X-Service-Token-->  Python services (Cloud Run, one FastAPI app, /v1/*)
     |  callable + Firestore SDK                                    |  Firebase Admin SDK
     v                                                               v
Firebase Cloud Functions (TS)  <--triggers/callables-->  Firestore + Storage + Auth (system of record)
     ^
     |  Firestore SDK
Admin Panel (static HTML/JS SPA)
```

### Python router surface (`python_services/main.py`)
One FastAPI app, one router per domain, each mounted with an explicit auth dependency
(`verify_service_token` / `verify_firebase_auth` / `verify_service_or_user` from `utils/auth.py`):

| Prefix | Engine module | Notes |
|---|---|---|
| `/v1/parser`, `/v1/upload`, `/v1/prn` | `parser/` | Excel + PDF (3-layer: pdfplumber→PyMuPDF→OCR) + PRN workflow |
| `/v1/legality` | `legality/engine.py` | Trade legality — its own `FTLRules`/`DEFAULT_RULES` |
| `/v1/rest` | `rest_engine/` | Rest/FDP/fatigue — separate `RulesProfile`, own hardcoded values |
| `/v1/ai` | `ai/nlp_router.py` | Intent classify → filter/legality/knowledge/chat; grounds on `legality.engine.DEFAULT_RULES`; per-user daily cap; cite-or-refuse |
| `/v1/ranking` | `ranking/` | Smart line scoring |
| `/v1/auto-bid` | `auto_bid/engine.py` | Preference-vector ranking, `MODE_WEIGHTS` (money/rest/balanced) |
| `/v1/salary` | `salary/` | Gross pay incl. per-diem/overtime |
| `/v1/trade-intel`, `/v1/whatsapp` | `trade_intel/` | |
| `/v1/intelligence` | `intelligence/` | PDF pairing reconstruction, FRMS fatigue scoring, line classifiers |
| `/v1/lines` | `filter_engine/` | Line search — manual/AI/hybrid clause filters, single evaluator |
| `/v1/roster-sync` | `roster_sync/` | Device-orchestrated sync import pipeline |
| `/v1/layover` | `layover/` | Layover city recommendations |
| `/v1/trade` | `trade_engine/` → `recommendation_engine/`, `compatibility_scoring/` | 7-factor trade compatibility scoring |
| `/v1/knowledge` | `knowledge_engine/` | extractors → chunker → embeddings/vector_store → retrieval; admin upload has no Admin-Panel UI yet |
| `/v1/subscription` | `subscription_engine/` | feature gating, reference example of "config-driven done right" |

**Known hazard (F3, partially open):** `/v1/legality` and `/v1/rest` are two independent engines
with two separate FTL rule definitions that can disagree. `legality/rules_source.py`
(`CANONICAL_DEFAULTS`) is meant to be the single source of truth going forward, with Firestore
`legalityRules` as the live override layer (TTL-cached, ~5 min, no deploy needed; inspect via
`GET /v1/legality/rules`; owner sign-off tracked in `OWNER_DECISION_REQUEST.md`). When touching
FTL/rest logic, check which engine you're in and whether it still needs reconciling against the
canonical source — don't assume the two are already unified.

### Configuration sources of truth
| Config | Source | Notes |
|---|---|---|
| FTL/rest rule values | `python_services/legality/rules_source.py` `CANONICAL_DEFAULTS` + Firestore `legalityRules` | TTL-cached, fail-safe to defaults, sanity-clamped |
| Subscriptions master switch | Firestore `subscriptionConfig/main` | Python `config_service.py` (30s cache); Cloud Functions read an env-var fallback |
| AI daily free limit | `subscriptionConfig/main.aiDailyFreeLimit` → env `AI_DAILY_FREE_LIMIT` → default 50 | Same precedence both sides |
| Scoring/ranking weights | Hardcoded by design, locked by unit tests | |
| `flutter_app/lib/shared/constants/constants.dart` | Display-only mirror of canonical FTL defaults | **Never branch logic on these values** — they're for UI display only |

### Auth model
- User calls: Firebase Bearer token, verified in `utils/auth.py`, requires
  `accountStatus == approved`; identity pinned to the token (`resolve_user_id`) so a user cannot
  act on another user's id.
- Service calls (Cloud Functions → Python): `X-Service-Token` header, constant-time comparison,
  fails closed (503) if `INTERNAL_SERVICE_TOKEN` is unset. Trusted to act on behalf of any user
  id present in the request body.
- Firestore rules gate reads/writes by `isApproved()` claim + owner/rank scoping.
- Admin privilege = `superAdmin`/`admin` claim + a `privileges` list (e.g.
  `manage_subscriptions`, `manage_knowledge_base`).
- Approval lifecycle: signup → `onUserCreated` writes `pendingApprovals` → admin calls
  `approveUser` (sets claim + user doc) → **client must refresh its ID token** before the new
  claim is visible to Python/Firestore rules.

### Data model (Firestore collections)
`users/{uid}`, `pendingApprovals/{id}`, `adminUsers/{uid}`, `flightLines/{id}`, `trades/{id}`,
`tradeContacts/{id}`, `bids/{id}`, `userLikes/`/`userSaves/`/`userRatings/` (owner-scoped),
`legalityRules/{id}` (admin-editable FTL overrides, read by every engine + AI grounding),
`subscriptionConfig/main`, `aiUsage/{uid}_{date}` (daily AI rate-limit counters), knowledge
documents/versions + Storage objects, `notifications/{id}`, `rosterSources/{uid}_{provider}`
(sync status — **never credentials**, enforced by `assert_no_credentials` + rules),
`rosterVersions/{id}` (per user+provider+period, checksum + leg-level diff), `syncEvents/{id}`
(service-only sync analytics), `autoBidRefresh/{uid}`.

### Roster sync pipeline
Device-orchestrated, credential-free on the backend: a `RosterConnector` on-device (CAE Crew
Access or an ICS calendar feed) holds credentials in Keychain/Keystore only, fetches the roster,
then `POST /v1/roster-sync/import` runs dedup (checksum) → versioning (leg-level diff) → line
build with canonical-rules enrichment (legality/rest/salary) → supersede-with-history → engine
fan-out. Priority order: CAE Sync → ICS → manual PDF. Full design in `docs/ROSTER_SYNC.md`.

### Line search / filter engine
Single endpoint `POST /v1/lines/search` (catalog: `GET /v1/lines/filters`) with three modes —
Manual (validated clauses only), AI (`ai_instruction` → NLP extractor → deterministic bridge →
clauses), Hybrid (both; **manual clauses lock** their filter id, conflicting AI clauses are
dropped with a written reason). All three converge on the one `filter_engine/registry.py`
evaluator, then `ranking/scorer` for mode-weighted results. See `VISION_GAP_ANALYSIS.md` for the
filter roadmap.

## Conventions worth knowing before editing

- **UI language is English-only (enforced)**, with full Unicode support for Arabic/multilingual
  *data* (roster content, names, etc.) — despite the README describing the app as "Arabic-first."
  `plans/STATUS.md` is the more current statement of this. Don't assume `app_ar.arb` drives
  active UI strings without checking current usage first.
- Subscriptions are fully built but launch-disabled (`SUBSCRIPTIONS_ENABLED=false`); billing is
  Apple IAP + Google Play via RevenueCat (future) — **no Stripe or HyperPay**, both were removed.
- FTL rule values live in code (`legality/engine.py`, `rest_engine/rules.py`) or Firestore
  overrides — never in the Flutter constants file. Any change to legality/rest thresholds needs
  to consider both engines (see the F3 hazard above) plus `tests/unit/test_engine_consistency.py`
  and `tests/unit/test_rules_source.py`.
- Flutter generated files (`*.freezed.dart`, `*.g.dart`) are not committed; `build_runner` must
  run before `flutter analyze` / `flutter test` will even compile.
- `firebase/functions` has no committed `package-lock.json` yet — CI falls back to
  `npm install` instead of `npm ci` until one exists.
- CI (`.github/workflows/ci.yml`) has four independent jobs: python-services, cloud-functions,
  flutter-app, firestore-rules. All are meant to be required status checks on `main`.
