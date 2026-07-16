# PERFORMANCE REPORT — Najm CIP, Remediation v1.2.0 (2026-07-11)

Scope: performance-relevant changes made this pass, hot-path review, and the
measurements that must run in a real environment (none were executable
offline — no load generation, no Firestore, no devices).

## 1. Performance-relevant changes in this pass

| Change | Effect |
|---|---|
| `rules_source` TTL cache (default 300 s, thread-safe, failure-cached) | Rule resolution costs **zero Firestore reads** on the hot path between refreshes; a Firestore outage cannot stampede (failures cached for the TTL too). |
| `rest_engine.get_profile()` builds profiles per call **from the cached rules** | Dataclass construction only (~µs); admin edits propagate ≤ TTL without redeploy. Import-time snapshot singletons retained for tests/back-compat. |
| Upload endpoint chunked read (64 KiB) + 20 MB cap | Replaces unbounded in-RAM buffering — worst-case memory per upload drops from "size of attacker's body" to one chunk. |
| Functions shared-config cache (60 s) | `subscriptionConfig/main` read at most once/min/instance for the master switch + AI limit. |
| `Promise.allSettled` batches retained (expiry sweep, notification fan-out) | Now actually compiles (tsconfig es2021); parallel fan-out preserved. |
| Saved Places query | Indexed (`userId ASC, createdAt DESC`) + parallel `Future.wait` doc resolution; N = user's saves (small). Acceptable; revisit only if saves grow unbounded. |

## 2. Hot-path review (no regressions introduced)

* `/v1/legality/check`: pure CPU over the request payload after a cached-rules
  lookup; FDP intersection adds two dict lookups + one `min()` per duty.
* AI grounding: one cached-rules read per chat; no extra network.
* Layover content filter: 24 pre-compiled word-boundary regexes per submission
  (client and server) — micro-cost; regexes compiled once at import.

## 3. Required post-deploy measurements (owner checklist)

1. Cloud Run p50/p95 for `/v1/legality/check` and `/v1/ai/chat` under expected
   concurrency; alert thresholds in the runbook.
2. Cold-start behaviour with `min_instances=0` vs `1` (region me-central1).
3. Firestore read budget with the two config caches in place (expect ≪ 1 read
   /req/instance amortised).
4. PDF pipeline wall-time per page on production hardware (OCR fallback path).

---

# TESTING REPORT — Najm CIP, Remediation v1.2.0 (2026-07-11)

## 1. What was EXECUTED during remediation (offline harness)

| Suite | Result |
|---|---|
| Python unit + eval (`python_services/tests`) | **315 passed · 0 failed · 0 errors** · 1 skipped (live-model eval, needs API key) |
| Python integration (`tests/integration`) | 9 tests **SKIPPED-OFFLINE** by design (need real FastAPI/httpx) — run in CI |
| Functions mapping contracts (`firebase/functions/test`) | **13/13 passed** — executed with real Node 22 + tsc-compiled output |
| `tsc --noEmit` (strict) over `firebase/functions/src` | **clean** (structural stubs; real-`node_modules` run happens in CI) |
| `py_compile` | 115/115 |
| Undefined-name check (F821 approx.) | 0 findings |
| Dart structural verification | 104/104 files bracket-balanced (state-machine parser); imports resolve except the 2 CI-generated codegen parts; all `package:` imports declared |

Harness fidelity limits are documented in `tools/offline_harness/README.md`
— a green harness proves logic + models, not HTTP/SDK behaviour. **CI is the
source of truth** and re-runs everything with the real toolchain.

## 2. What is AUTHORED and runs first in CI

* `firebase/test/rules.spec.mjs` — 11 Firestore + Storage rules tests
  (user isolation, self-approval blocked, `legalityRules` superAdmin-only,
  `userSaves` owner-list/forgery, notification field-clamp, behaviorEvents
  pinning/immutability, recommendations photo size/type/anon/delete, roster
  type/owner). Runs in the `firestore-rules` emulator job.
* Flutter unit tests: `content_filter_test.dart` (word-boundary regression
  lock; fixtures twinned with `test_layover_content.py` so the client and
  server filters cannot drift silently) and `app_constants_test.dart`
  (persisted category vocabulary, sort options, `yearFromPeriod` incl.
  lookaround edge cases). Regex semantics pre-validated via Python `re`
  (identical constructs) — see transcript evidence in FINAL_RELEASE_REPORT.
* Integration suite (`test_api.py`, `test_trade_search_api.py`) — unchanged,
  runs under real pytest in CI.

## 3. New regression locks added this pass

* `test_engine_consistency.py` — all three legality engines must agree on
  minimum rest and verdict for identical input (**the P0-1 lock**).
* `test_rules_source.py` — defaults, override merge, sanity clamps,
  fail-safe, TTL/invalidations.
* `_resolve_rules` provenance test — what-if marking can't regress.
* Content-filter false positives (Barcelona/public/clubhouse/…) locked on
  **both** client and server.
* Mapping tests lock the exact 422-causing payload bugs (F16/F17) and config
  precedence (F19/F20).

## 4. Coverage gaps (honest)

| Gap | Risk | Recommendation |
|---|---|---|
| No widget/golden tests; `test/widget/` empty | Med | Start with LineCard, RecommendationCard, SavedScreen states. |
| No E2E (auth → upload → verdict) | Med | Post-first-deploy smoke via Firebase Test Lab / Patrol. |
| Functions triggers beyond the mappers untested | Low-Med | Add firebase-functions-test harness for `onBidCreated`, expiry sweep. |
| Admin panel JS untested | Low | Manual checklist exists in runbook; consider Playwright later. |
| Parser xlsx paths exercised only via pure helpers offline | Low | CI runs the full parser suite with real openpyxl. |
