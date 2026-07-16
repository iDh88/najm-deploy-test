# NAJM CREW INTELLIGENCE PLATFORM — FORENSIC RELEASE AUDIT

**Independent Release Review Board · Aviation Safety · DevSecOps · QA · Production Readiness**
Audit date: 2026-07-09 · Artifact: `najm_complete_master.zip` · Method: evidence-based, source-of-truth = code/tests/CI, documentation treated as unverified claims.

---

## FINAL DECISION: **NO GO**

| Dimension | Score | Basis |
|---|---:|---|
| **Readiness (overall)** | **32 / 100** | Disqualified by a safety-critical correctness defect (below). |
| **Safety** | **26 / 100** | Two-to-three conflicting FTL/rest rule sets produce **opposite legal verdicts on identical input** (runtime-proven). Admin rule editor is inert. |
| **Security** | **70 / 100** | Strong auth/rules/secrets hygiene; suspension does not revoke sessions. |
| **Testing** | **34 / 100** | Suite does **not** pass clean; zero Flutter/Functions/rules tests; functions CI cannot run. |
| **Operations** | **30 / 100** | Advisory-only lint, broken CI job, no deploy/rollback workflow, no build artifacts. |
| **Governance** | **45 / 100** | Rich governance docs, but they record **unremediated P0s** and gate nothing. |
| **Documentation** | **55 / 100** | Candid about its own gaps; still drifts from code in several places. |
| **Maintainability** | **63 / 100** | Genuinely clean, modular, typed — the project's real strength. |

**Issue counts:** Critical (P0) **2** · High (P1) **5** · Medium (P2) **6** · Low (P3) **6**.
**Evidence artifacts produced:** 20+ tool-verified checks (compile, import-graph, test execution, dual-engine runtime comparison, rules/CI/auth reads).

> **The single disqualifying finding:** for an *aviation fatigue/legality* tool, the same regulation yields **different pass/fail answers depending on which screen the crew member opens.** No aviation-safety product can ship in that state, regardless of how polished the rest of the codebase is (and much of it is genuinely well built).

---

## What was, and was not, verifiable in this environment

Per the audit's own rule — *a feature is VERIFIED only if built, executed, tested, and evidenced* — the following honesty applies. This sandbox has **no network, no Flutter/Dart SDK, no Node/npm install, and no Firebase emulator.**

| Phase | Verifiable here? | How it was handled |
|---|---|---|
| Python compile | ✅ Yes | All 113 files byte-compiled; import graph resolved. |
| Python tests | ✅ Executed | Ran under a faithful offline test-runner + dependency shims; harness artifacts separated from real failures (documented). |
| Safety-engine behavior | ✅ Executed | Both legality engines instantiated and run head-to-head on identical duty input. |
| Firestore/Storage rules, CI, auth, Functions source | ✅ Read in full | Static audit of 100% of these files. |
| **Flutter build (Android/iOS/web)** | ❌ No SDK | **UNVERIFIED** — cannot be claimed. |
| **`flutter analyze` / widget tests** | ❌ No SDK + **zero tests exist** | **UNVERIFIED / MISSING.** |
| **Cloud Functions `tsc` typecheck** | ❌ No npm/@types | **UNVERIFIED** (blocked further by missing lockfile — see P1-4). |
| **End-to-end system run** | ❌ No emulator/network | **UNVERIFIED** — no live workflow could be exercised. |

Anything marked UNVERIFIED is scored as *unproven*, not *passing*.

---

## PHASE 1 — REPOSITORY INVENTORY

**Scale (clean, excluding generated `__pycache__`):** 260 files, 109 directories.

| Language | Files | LOC |
|---|---:|---:|
| Python | 113 | 18,790 |
| Dart (Flutter) | 100 | 31,051 |
| TypeScript (Cloud Functions) | 2 | 1,118 |
| Markdown (docs/plans) | 24 | 3,967 |
| Firestore/Storage rules | 2 | 429 |
| Admin panel (single `index.html`) | 1 | 1,223 |

**Architecture (as built):** Flutter client (13 feature modules) · FastAPI Python service with **16 mounted routers** (parser, legality, AI/NLP, ranking, auto-bid, salary, trade-intel, PDF-intelligence, layover, trade-recommendation, rest, knowledge, subscription, WhatsApp) · **33 Cloud Functions** (25 in `index.ts` + 8 admin in `admin_setup.ts`) · Firebase (Firestore, Storage, Auth, FCM) · single-file HTML admin panel · **65 Firestore composite indexes**.

**Dead code / duplication / placeholders (evidence):**
- **Two `LegalityEngine` classes** — `legality/engine.py:136` and `rest_engine/legality.py:63` — the root of the safety defect (Phase 5).
- **Stripe retained though "removed":** `functions/package.json` still declares `"stripe": "^15.2.0"`; `models.dart:40` still carries `stripeCustomerId`; `index.ts:494` is only a *comment* claiming removal. Dead third-party payment SDK in the dependency tree.
- **Mock/placeholder production paths:** `upload_search_comparison_screens.dart:37` hardcodes `/tmp/mock_schedule.pdf` and `demo_user`; `layover/screens/saved_screen.dart` is a labelled placeholder screen; `firebase_options.dart` is a `REPLACE_WITH_*` template (expected for source, but not launch-ready).
- **TODOs:** low count (4 in app code), e.g. rank hardcoded `'CA'` in `add_recommendation_screen.dart:89`, settings-not-loaded in `app.dart:64`.
- **`classification_engine.py:20` raises `NotImplementedError`** (intelligence classification stub).

---

## PHASE 2 — BUILD VERIFICATION

| Target | Result | Evidence |
|---|---|---|
| Python services (compile) | **PASS** | 113/113 files `py_compile` clean; internal import graph: **0 unresolved imports** across 21 packages. |
| Cloud Functions (`tsc`) | **UNVERIFIED → FAIL-blocked** | Cannot install types offline; **`npm ci` is impossible — no `package-lock.json`** (P1-4). `tsconfig` sets `strict` + `noUnusedLocals` (strict gate). |
| Flutter Android | **UNVERIFIED** | No SDK; no `android/` project directory present. |
| Flutter iOS | **UNVERIFIED** | No SDK; no `ios/` project directory present. |
| Flutter web | **UNVERIFIED** | Hosting serves `flutter_app/build/web`, which does not exist in the repo. |
| Firebase deploy validation | **PARTIAL** | `firebase.json`, rules, indexes are syntactically well-formed; deploy not executable here. |

**Verdict: BUILD NOT VERIFIABLE end-to-end.** Only the Python stack is provably compilable. The absence of `android/`/`ios/` directories means the "Android build / iOS build" mandated by Phase 2 cannot even be attempted from this artifact.

---

## PHASE 3 — TEST EXECUTION

**Executed** the Python suite (264 test functions) with a pytest-compatible runner + shims for absent binary deps (fastapi, pydantic, firebase_admin, pytz, anthropic). Harness-only failures were isolated and are **not** counted against the code.

**Result:** `212 passed · 8 assertion-failures · 15 errors` → of the 15 errors, **6 are harness artifacts** (my pydantic shim lacks `model_copy`) and are discounted; **~9 are genuine** test/code drift.

**Genuine failures (would fail under real pytest too):**

| Test | Root cause | Severity |
|---|---|---|
| `test_legality::TestBackwardForwardCheck::*` (4) + `TestEdgeCases::test_proposed_duty_overlapping…` | Tests call `check_schedule(proposed_duty=…)`; real signature is `proposed=`. **Safety backward/forward rest tests are broken against current code.** | High |
| `test_parser_ranking::…rank_lines_returns_sorted*` (2) | Tests call `rank_lines(mode=…, all_max=…)`; real signatures are `(lines, prefs, all_max_salary)` / `(self, lines, pref_vector, user_mode)`. | Med |
| `test_parser_ranking::test_preference_vector_defaults` | Asserts `PreferenceVector.dest_affinities`; real field is `destinationAffinity`. | Med |
| `test_legality::test_monthly_approaching_limit_triggers_warning` | Builds exactly 108h (=90%); code warns only when **> 90%** (strict `>`). Amber threshold boundary gap **in the safety engine.** | Med |
| `test_knowledge_engine::TestChunker::*` (3) | `MIN_CHUNK_CHARS=100` silently discards short text the tests expect to survive → 0 chunks / `IndexError`. | Med |
| `test_subscription_engine::test_unconfigured_feature_fails_open_to_public` | **Stale test:** expects fail-*open*; code correctly fails **closed** (denies). Code is safer than its test. | Low (test debt) |

**Coverage gaps (missing critical tests → issues raised):**
- **Flutter: ZERO tests.** `flutter_app/test/unit` and `/widget` are **empty directories.** Widget/contract tests mandated by Phase 3 do not exist.
- **Cloud Functions: ZERO tests.** No test files anywhere under `firebase/functions`.
- **Firestore rules: ZERO tests.** CI's rules job literally echoes *"No Firestore rules tests yet."*
- **Push/notification, admin-flow: ZERO tests.**

> The existing suite also **encodes the safety inconsistency**: `test_rest_engine` asserts 10h/11h minima while `test_legality` asserts 14h/15h — both "pass," locking in contradictory truth (matches the project's own finding F10/F11).

---

## PHASE 4 — END-TO-END SYSTEM TESTING

**UNVERIFIED — could not be performed.** No emulator, no network, no client runtime. None of the 15 mandated workflows (registration, approval, suspension, token revocation, trade create/approve/reject, rest calc, legality, AI, subscription, deletion, config change, admin approval, notification delivery) could be exercised live.

Two of these were instead **traced in source** and found defective on inspection:
- **Suspension / Token Revocation:** `suspendUser` (admin_setup.ts:138) sets `accountStatus:"suspended"` claim but **never calls `revokeRefreshTokens`**; the Python verifier calls `verify_id_token` **without `check_revoked=True`**. A suspended user retains access until their ID token refreshes (≤1h). See P1-1.
- **Config change → legality:** the Admin "Legality Rules" editor writes a Firestore collection **no engine reads.** See P0-2.

E2E remains a **hard gate that has not been cleared.**

---

## PHASE 5 — AVIATION SAFETY AUDIT  *(most important section)*

### P0-1 — Conflicting FTL/rest rule sets → opposite legal verdicts (RUNTIME-PROVEN)

Three separate sources of "truth" for the same GACA regulation:

| Rule (minimum rest) | `legality/engine.py` (→ `/v1/legality`, Trades, **AI grounding**) | `rest_engine/rules.py` (→ `/v1/rest`, **Rest Calculator screen**) | `flutter/constants.dart` (client) |
|---|---:|---:|---:|
| Domestic | **14.0 h** | **10.0 h** | 14.0 h |
| International | **15.0 h** | **11.0 h** | 15.0 h |
| Cumulative cap | 900 h/yr flight, 120 h/mo duty | 1000 h/yr block, 100 h/mo block | 900 h / 120 h |

**Executed head-to-head, identical input** (domestic, 12h00 rest between duties):

```
ENGINE A  rest_engine  (/v1/rest — Rest Calculator):  min applied 10:00  →  SUFFICIENT — LEGAL
ENGINE B  legality/engine (/v1/legality + AI):        required 14:00     →  VIOLATION (actual 12.0h / required 14.0h), forward AND backward
```

The AI assistant's `_ftl_grounding_block` injects **14h/15h** into the model prompt (confirmed by executing the grounding path). So a crew member who asks the AI, checks a trade, and opens the Rest Calculator can receive **three answers, two of them contradictory, for one duty.** For a fatigue-safety tool this is the highest-severity defect class.

### P0-2 — Admin "Legality Rules" editor is inert

`admin_panel/index.html:983,1017` reads/writes the `legalityRules` Firestore collection. **No engine reads it** — grep across all Python/TS/Dart shows only the admin writer and a *comment* in `constants.dart`. Both engines use hardcoded Python dataclass defaults (`DEFAULT_RULES`, `DEFAULT_PROFILE`). An administrator editing FTL limits believes they are changing safety rules; **runtime behavior does not change.** Silent, safety-relevant no-op.

**Other safety observations:** the engines themselves are individually well-constructed (WOCL windows, augmented-crew profiles, 7/28-day rolling windows, backward+forward rest checks). The failure is **architectural** — duplicated engines with no single source of truth — not arithmetic within any one engine.

---

## PHASE 6 — SECURITY AUDIT

**Overall the strongest area after maintainability.** No hardcoded secrets were found: every credential in `.env.example`/`firebase_options.dart` is a `REPLACE_WITH_*`/`change-me` placeholder; no live API keys, no `AIza…`, no service-account JSON committed.

| Control | Finding | Severity |
|---|---|---|
| Service-to-service auth | **Fail-closed** — `verify_service_token` raises 503 if `INTERNAL_SERVICE_TOKEN` unset; constant-time `hmac.compare_digest`. Good. | — |
| Identity spoofing | `resolve_user_id` pins user calls to token `uid`; service calls trusted only via header. Good. | — |
| Firestore rules | Comprehensive: rank-separation on lines/bids/trades, owner-scoping, `manage_*` privilege gates, explicit `deny-all` fallback, knowledge chunks server-only. Strong. | — |
| **Token revocation on suspend** | `suspendUser` does **not** `revokeRefreshTokens`; Python verifier omits `check_revoked=True`. Suspended/rejected users keep access ≤1h. | **High (P1-1)** |
| Authorization freshness | `accountStatus` read from token claims only — no Firestore re-check; a just-approved user needs a token refresh. Documented, but couples authz to token TTL. | Med |
| Storage rules vs usage | `storage.rules` permits **only Excel** MIME types on roster uploads, but the PDF-intelligence flow uploads PDFs — client writes would be rejected unless routed via the service account. | Med (P2) |
| PDPL / deletion | `processAccountDeletion` cascades Firestore + Storage + Auth deletion, idempotent with retry. Solid. | — |
| Dependency surface | Unused **`stripe` SDK** retained (supply-chain surface for a removed feature). | Med (P2) |

**Security tally:** Critical 0 · High 1 · Medium 3 · Low 1.

---

## PHASE 7 — CI/CD AUDIT

Only **one** workflow exists: `.github/workflows/ci.yml`. Against the mandated checklist:

| Required | Present? | Evidence |
|---|---|---|
| `deploy.yml` | ❌ Absent | No deploy workflow in repo. |
| `rollback.yml` | ❌ Absent | No rollback workflow (only a markdown runbook). |
| CODEOWNERS | ❌ Absent | File not present. |
| Dependabot | ❌ Absent | No `dependabot.yml`. |
| Branch protection / required checks | ⚠️ Unenforceable | CI *comments* say to make jobs required; not verifiable and undermined by the failures below. |
| Security scanning | ❌ None | No CodeQL/Snyk/secret-scan step. |
| Artifact signing / canary / WIF | ❌ None | Not implemented. |

**CI would not go green as written:**
- **Cloud-Functions job is broken:** it runs `npm ci` (which *requires* `package-lock.json`) and sets `cache-dependency-path: firebase/functions/package-lock.json` — **the lockfile does not exist.** Job fails at setup.
- **Python job would be red:** `pytest -q` hits the genuine failures in Phase 3.
- **Lint is non-blocking:** `ruff check . || true` — the "no warnings ignored" requirement is explicitly violated by design.
- **Rules job is a no-op:** self-describes as having no tests.

**DevSecOps verdict: not production-grade.** CI is a scaffold that currently cannot pass on two of four jobs.

---

## PHASE 8 — DOCUMENTATION DRIFT

The governance docs are unusually **honest** (VERSION.md and `NAJM_PRELAUNCH_AUDIT.md` record the P0s openly). Drift that remains:

| Claim (docs/comments) | Reality (code) |
|---|---|
| "Stripe removed (0.3) — not in roadmap" (`index.ts:494`, VERSION.md) | `stripe@^15.2.0` still in `functions/package.json`; `stripeCustomerId` still in `models.dart`. |
| Phase docs titled "certification" / "operational readiness" | No deploy/rollback workflow, no lockfile, red CI — nothing is actually gated or certified. |
| Test-coverage framing implies a working suite | Suite does not pass clean; Flutter/Functions/rules tests are **absent**, not merely thin. |
| "Legality Rules" admin editor (implied functional) | Writes a collection no engine reads (P0-2). |
| README/architecture describe Android & iOS apps | No `android/` or `ios/` project directories exist in the artifact. |

---

## PHASE 9 — RELEASE BLOCKERS

### P0 — Critical (must fix before any launch)
1. **Unify FTL/rest rules to one engine / one source of truth.** *Evidence:* dual `LegalityEngine`, runtime opposite-verdict test above. *Files:* `legality/engine.py`, `rest_engine/rules.py`, `flutter/constants.dart`, `ai/nlp_router.py`. *Root cause:* two independently-authored engines both mounted. *Fix:* pick the GACA-authoritative set (owner decision — see the project's own open question), delete the duplicate, route Rest/Trades/AI/client through it, delete contradictory tests. *Effort:* **3–5 days** + regulatory sign-off.
2. **Make the admin Legality editor authoritative or remove it.** *Evidence:* `legalityRules` written by admin, read by nobody. *Fix:* have the unified engine load rules from `legalityRules` at runtime (with a safe fallback), or remove the editor to avoid a false sense of control. *Effort:* **2–3 days** (folds into P0-1).

### P1 — High
1. **Revoke sessions on suspend/reject.** Add `admin.auth().revokeRefreshTokens(uid)` in `suspendUser`/`rejectUser`; set `check_revoked=True` in the Python verifier. *Effort:* **0.5 day.**
2. **Green the test suite.** Fix the ~9 drifted tests (`proposed_duty→proposed`, `mode`/`all_max` signatures, `dest_affinities→destinationAffinity`, chunker `MIN_CHUNK_CHARS`, monthly-warning boundary, stale fail-open test). *Effort:* **1–2 days.**
3. **Author the missing test tiers** — Flutter widget/unit, Cloud Functions, Firestore rules (emulator). Currently zero. *Effort:* **5–8 days.**
4. **Add `package-lock.json` (functions) and `pubspec.lock` (Flutter).** Without the former, functions CI cannot run. *Effort:* **0.25 day.**
5. **Ship the Knowledge-base admin upload UI (F9)** or disable the feature flag; backend is complete but unreachable by operators. *Effort:* **2–3 days.**

### P2 — Medium
1. `SUBSCRIPTIONS_ENABLED` split-brain (Functions read env; Python reads Firestore config) — unify.
2. `AI_DAILY_FREE_LIMIT` env-only — move to admin-controlled config for parity with the rest of the subscription system.
3. Storage rules reject PDFs while PDF-intelligence uploads them — align `storage.rules` with actual content types/paths.
4. Remove the dead **Stripe** dependency and `stripeCustomerId` (or reinstate intentionally).
5. Add **deploy/rollback** workflows and make CI lint **blocking** (drop `|| true`).
6. Replace the **mock file-picker/`demo_user`** path in the intelligence upload screen with the real `file_picker` flow before that screen ships.

### P3 — Low
1. Implement or hide the `saved_screen.dart` placeholder. 2. Populate `firebase_options.dart` via `flutterfire configure` at build time. 3. Resolve outstanding TODOs (hardcoded rank `'CA'`, settings load). 4. Implement `classification_engine` or remove the `NotImplementedError` stub. 5. Add CODEOWNERS + Dependabot. 6. Add security scanning (CodeQL/secret-scan) to CI.

---

## PHASE 10 — FINAL DECISION

# **NO GO**

| Score | /100 |
|---|---:|
| Readiness | **32** |
| Safety | **26** |
| Security | **70** |
| Testing | **34** |
| Operations | **30** |
| Governance | **45** |
| Documentation | **55** |
| Maintainability | **63** |

**Evidence count:** 20+ tool-verified checks. **Open issues:** Critical **2** · High **5** · Medium **6** · Low **6**.

**Path to GO WITH CONDITIONS** (fastest credible route): clear **both P0s** (unify legality truth + make/remove the admin editor) and **P1-1/P1-4** (session revocation + lockfile), then re-run the suite green and stand up the missing test tiers. Realistic critical-path: **~2 working weeks** of engineering plus a regulatory sign-off on the authoritative FTL numbers. Until the legality engines agree, launch is not defensible for a crew-fatigue product.

**What is genuinely good and should be preserved:** the code is clean, modular, and strongly typed; the Python service architecture (16 well-separated routers), the auth model (fail-closed service tokens, identity pinning), the Firestore rule design, and the PDPL deletion pipeline are all above the bar. The problem is not craftsmanship — it is **one architectural safety defect and an unfinished verification/release apparatus.**

---
*Verification stance: every "PASS" above is backed by an executed command or a full-file read. Every item that could not be run in this environment is marked UNVERIFIED and scored as unproven — not assumed working — per the audit's own definition of VERIFIED.*
