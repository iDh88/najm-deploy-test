# ARCHITECTURE REPORT — Najm CIP, Remediation v1.2.0 (2026-07-11)

## 1. The structural change of this release: one FTL brain

**Before:** three independent, mutually contradictory FTL rule tables
(`legality/engine.py` 14/15 h rest with a GOM citation; `rest_engine/rules.py`
10/11 h uncited; `intelligence/.../legality_checker.py` 10/11 h uncited), plus a
fourth copy in Flutter constants and a fifth in the AI prompt — and an admin
"Legality Rules" editor writing to a collection nothing read. Identical input
produced opposite legal verdicts at runtime (audit P0-1/P0-2).

**After:**

```
                 Firestore `legalityRules` (admin panel, superAdmin-only writes)
                                   │  TTL ≤ 5 min, sanity-clamped, fail-safe
                                   ▼
        python_services/legality/rules_source.py  ← CANONICAL_DEFAULTS (GOM 7.5.3 TF)
        get_effective_rules() · min_rest_minutes() · fdp_limit_minutes()
           │                  │                        │
           ▼                  ▼                        ▼
   legality/engine.py   rest_engine/rules.py   intelligence/…/legality_checker.py
   (FTLRules.effective) (build_profiles live)  (live facades, metaclass constants)
           │
           ├── GET /v1/legality/rules  (values + provenance + overrides)
           └── ai/nlp_router grounding block (live values + version stamp)
```

Design properties worth defending in review:

* **Fail-safe direction.** Any Firestore/parse failure yields the canonical
  defaults (the *most conservative* set present in the repo), logged — a broken
  config store can never loosen a safety rule.
* **Bounded admin power.** Overrides pass engineering sanity clamps (typo
  guards, e.g. rest ∈ [1 h, 48 h]); out-of-range values are rejected per-field
  with the default retained. Clamps are not regulatory judgments.
* **Profiles may tighten, never loosen.** Crew-type profiles keep their
  presentation/operational deltas (briefing times, the stricter cockpit FDP
  table) but rest minimums are floored at canonical and FDP is the
  min(profile, canonical) intersection.
* **What-if stays labelled.** Caller-supplied rules are honoured for analysis
  and stamped `caller-supplied (what-if)` so a simulation can never
  masquerade as an official verdict.
* **Interim FDP model = conservative intersection** of the flat category caps
  and the per-sector table, pending the owner's ODR-002 ruling — no consumer
  is more permissive than either project-native model in the meantime.

## 2. Contract repairs across tier boundaries

| Bridge | Before | After |
|---|---|---|
| Functions → Python `/v1/legality/check` | `{schedule, proposedChange, changeType}` → 422 always | `buildLegalityPayload` (pure, unit-tested): documented keys, legacy keys translated, `changeType` dropped |
| Functions → Python `/v1/ai/chat` | camelCase `userId`, top-level locale dropped → 422 always | `buildAiChatPayload`: snake `user_id`, `userMode`/`locale` merged into `context` with tested precedence |
| Flutter → Python intelligence | localhost:8000, no auth, unprefixed paths | env base URL + Bearer interceptor + `/v1/*`; response keys verified against server (`uploadId`/`lineId`) |
| Flutter internal navigation (layover) | pushed `/cities/*`, `/recommendations/*` (no such routes) | retargeted to the router's `/layover/*` scheme; `/layover/saved` added before the `:cityId` param route |
| Spec ↔ code | openapi documented nonexistent endpoints and the exact camelCase mistake F17 fixed | spec rewritten to wire reality (real paths, snake_case models, provenance fields, upload contract) |

## 3. Runtime configuration — single map

See NAJM_ARCHITECTURE.md §7 (rewritten). Net: FTL rules, the subscriptions
master switch, and the AI daily limit each now have exactly one authoritative
source with identical read precedence on every consumer.

## 4. Maintainability moves

* Pure, dependency-free `firebase/functions/src/mapping.ts` — the fragile
  translations live where plain `node --test` can pin them.
* `tools/offline_harness/` committed: future network-isolated audits start from
  a working mini-pytest + shims + TS stubs instead of rebuilding them.
* Flutter: missing `NajmTheme`/`AppConstants`/`ContentFilter` reconstructed
  from call sites (API dictated by usage, values from the existing brand
  palette / persisted data vocabulary); `period_utils` extracted for testability.
* Trade router docstrings restored to actual docstrings.

## 5. Remaining architectural debt (ranked)

1. **Two theme systems** (`CIPTheme` light/grey vs `NajmTheme` dark navy/gold)
   split roughly along feature lines. Cohabits fine; consolidate deliberately.
2. **`behaviorEvents` dual schema** — split into `bidEvents`/`tradeEvents`
   with a backfill migration; both index families already exist.
3. **HTTP client duplication** in Flutter (three hand-rolled authed Dio setups
   + one raw `http` usage) — extract a shared authenticated client factory.
4. **`cities_hub` seed list** is hardcoded while `layoverCities` exists in
   Firestore — promote to live data behind the existing `LayoverService`.
5. **Flutter store packaging** (`android/`/`ios/` directories) absent from the
   archive — regenerate via `flutter create .` + re-apply Firebase config
   before any store build (release-gate condition).
