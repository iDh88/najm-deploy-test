# RELEASE READINESS — Najm CIP v1.2.0 (2026-07-11)

Prior state: **NO-GO, 32/100** (FORENSIC_RELEASE_AUDIT.md). This document
re-scores after Remediation Pass 2 using a weighted gate model. Every gate's
evidence is executed or authored artifacts in this repository — not intent.

## Gate table

| Gate (weight) | Score | Basis |
|---|---:|---|
| **Safety correctness — FTL rules (25)** | **22/25** | P0-1/P0-2 closed: one source of truth (`legality/rules_source.py`), all three engines + AI grounding derive from it, admin `legalityRules` collection is live (TTL-cached, clamped, fail-safe), 57-test regression lock **executed green**, conservative-intersection FDP. Held back 3: the canonical values await owner sign-off (ODR-001/002/003) — they are the project's own best-cited, most conservative set, but "confirmed against current GOM" is a human gate. |
| **Security (20)** | **18/20** | 9 findings fixed (see SECURITY_REPORT §1): identity pinning, upload caps, revocation-check unification, claim-merge, storage rules, client auth. Rules default-deny with 12 authored emulator tests. Held back 2: rules tests + CodeQL/gitleaks first execute in CI; secret rotation + App Check enforcement are operational tasks. |
| **Build & compile integrity (15)** | **10/15** | Executed: `py_compile` 117/117, F821-clean, `tsc --noEmit` strict-clean (structural stubs) with two real compile blockers fixed (es2017→es2021; `firebase-functions/v1` entrypoint). Dart: 104 files bracket-balanced, all imports/`part`s resolve, all packages declared, symbol spot-checks pass — **but no Dart compiler ran offline**, and `models.freezed.dart`/`.g.dart` remain CI-generated. First `flutter analyze` is the proof point. |
| **Tests (15)** | **12/15** | Executed offline: **315 Python tests green** (incl. the new 57-test P0 lock) + **13 Functions mapping tests** via node:test. Authored→CI: 9 integration tests, 12 Firestore/Storage rules tests, 2 Flutter unit suites. Held back: no E2E, no load test, live-model eval skipped. |
| **CI/CD & operations (10)** | **8/10** | CI hardened (ruff blocking, functions tests, emulator rules job, build_runner step); `deploy.yml`/`rollback.yml` authored with WIF + `production` approval gate; Dependabot + CodeQL + gitleaks. Held back: pipelines unexercised; WIF/vars/environment and CODEOWNERS handles must be configured by the org. |
| **Docs & traceability (10)** | **10/10** | OpenAPI matches the wire (the drift that *taught* the F17 bug is gone); architecture/README single-source-of-truth sections; ODR sign-off doc; changelog reflects executed reality incl. a disclosed verification-process incident; runbook/harness READMEs. |
| **Data & config rollout (5)** | **4/5** | Idempotent, value-preserving seeder for `legalityRules`; `userSaves` composite index and rules ready. Held back: seeding + `firebase deploy --only firestore:indexes,firestore:rules,storage` not yet run against the project. |

## Score: **84 / 100**

## Verdict: **GO-WITH-CONDITIONS**

No code-side absolute blocker remains. Release is gated on the following
**conditions**, in order:

1. **ODR sign-off** — safety/compliance owner confirms or amends ODR-001/002/003
   (`OWNER_DECISION_REQUEST.md`). Amendments need **no code change**: edit the
   values in the Admin Panel (or re-seed) — provenance will show the overrides.
2. **First green CI run** on `main` — this executes everything the offline
   environment could only author: real pytest (incl. integration), `npm ci` +
   `tsc` + mapping tests against real packages, `flutter analyze`/`test` with
   build_runner codegen, and the emulator rules suite. Treat any red as a
   release blocker.
3. **One-time rollout tasks** — run `scripts/seed_legality_rules.py`; deploy
   Firestore rules + indexes and Storage rules; set the CI/deploy org config
   (WIF provider + service account vars, `production` environment reviewers,
   real CODEOWNERS handles); commit `firebase/functions/package-lock.json`
   from the first `npm install` and flip the CI install step to `npm ci`.
4. **Staging smoke** — one scripted pass: sign-up → approve → roster upload →
   `/v1/legality/check` (verify `rules_version` provenance) → AI chat →
   layover recommendation with photo → save → Saved Places.

## What would flip this to NO-GO

* Owner determines the canonical FTL values are wrong **and** stricter than
  the GOM requires in a direction that blocks legal operations (loosening is
  an admin edit; a structurally different rule model would need code).
* First CI run reveals Dart type errors beyond mechanical fixes (the one
  verification class this environment could not execute).
