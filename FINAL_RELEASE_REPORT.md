# FINAL RELEASE REPORT — Najm Crew Intelligence Platform
**Release candidate v1.2.0 · 2026-07-11 · Remediation Pass 2 (full repository)**

---

## 1. Verdict

**GO-WITH-CONDITIONS — readiness 84/100** (from 32/100 NO-GO).
Full gate table, scoring basis, and the four release conditions:
`reports/RELEASE_READINESS.md`. No code-side absolute blocker remains; the
conditions are (1) owner sign-off on the FTL values (ODR-001/002/003),
(2) a first green CI run, (3) one-time rollout tasks (seed rules, deploy
indexes/rules, org CI config), (4) a scripted staging smoke.

## 2. The headline problem, and what changed

The audit's P0 was existential for a crew-safety tool: **three engines
carried three different flight-time-limitation rule sets** (14 h/15 h rest
vs. 10 h/11 h twice), producing opposite LEGAL/ILLEGAL verdicts on identical
input — while the Admin Panel's rules editor wrote a Firestore collection
**nothing read**.

Now every threshold in the platform resolves through ONE module —
`python_services/legality/rules_source.py`:

```
CANONICAL_DEFAULTS (GOM 7.5.3 Table F set — the project's own citation)
        ▲ fail-safe fallback
        │
Firestore `legalityRules` (Admin-Panel-editable, seeded, sanity-clamped,
TTL-cached ≤300 s)
        │
        ├── legality/engine.py      → /v1/legality/check, /check-trade,
        │                             NEW GET /v1/legality/rules (provenance)
        ├── rest_engine profiles    → calculator, fatigue, safety scorer
        ├── intelligence checker    → PDF-pipeline legality
        └── ai/nlp_router grounding → the numbers the assistant is allowed
                                      to state
```

Every verdict is stamped with provenance (`"GACA-GOM-7.5.3-TF (defaults)"`,
`"… (+N admin overrides)"`, or `"caller-supplied (what-if)"`). A 57-test
regression lock (`test_rules_source.py`, `test_engine_consistency.py`) —
**executed green** — asserts all surfaces agree, that an admin override
propagates to every one of them including the AI grounding, and that the
pre-fix divergent values (600/660 min, 1000 h) can never silently return.

**No regulatory value was guessed.** Where the repo conflicted, the unified
defaults are its own best-cited, most conservative set; each such decision is
recorded for the accountable owner in `OWNER_DECISION_REQUEST.md`, and
confirmed corrections require **no deploy** — they are admin edits.

## 3. Everything else fixed (39 items + 6 found during the pass)

Full per-item detail with file references: `REMEDIATION_CHANGELOG.md`
(“Remediation Pass 2”). By area:

* **Security (9)** — upload identity pinning + 20 MB cap + fail-loud status;
  revocation-check unification (suspended admins die within seconds again);
  claim-merge on re-approval; signup no longer aborts pre-setup; Storage rule
  for layover photos; authenticated Flutter service client; scoped
  `userSaves` owner-list rule. → `reports/SECURITY_REPORT.md`.
* **Broken bridges (4)** — the Functions→Python `checkLegality` and
  `aiAssistant` calls 422'd on *every* invocation (wrong contract); mapping
  extracted to pure `src/mapping.ts`, pinned by 13 locally-executed tests.
  `intelligence_service.dart` pointed at `localhost:8000` with no auth.
  Five layover routes navigated to a nonexistent path scheme.
* **Flutter compile & completion (12)** — three referenced-but-absent files
  reconstructed from their call sites (`NajmTheme`, `AppConstants`,
  word-boundary `ContentFilter` — "Barcelona" is no longer profanity); 20
  broken imports fixed; a compile-breaking unclosed widget tree in
  `lines_screen.dart`; real file picker + authenticated identity replacing
  `demo_user`; profile-sourced rank; **Arabic actually enabled** (the
  settings toggle was a silent no-op); Saved Places implemented end-to-end
  (service → rules clause → composite index → screen → route → entry point).
* **Config split-brain (2)** — subscriptions master switch and the AI daily
  limit now resolve identically on both sides of the system
  (Firestore-config → env → default), unit-tested.
* **Toolchain truths (3)** — `tsconfig` target es2017 could not compile the
  committed `Promise.allSettled` code → es2021; `firebase-functions@^5`
  requires the `/v1` entrypoint for the 1st-gen API this codebase uses
  (incl. the v1-only `auth.user()` trigger); dead Stripe dependency and
  model field removed.
* **CI/CD & governance (5)** — ruff now BLOCKING (fatal rule set, tree
  pre-verified); deploy + rollback workflows (WIF, approval-gated,
  traffic-shift rollback); CODEOWNERS routing safety-critical paths to the
  safety owner; Dependabot; CodeQL + gitleaks.
* **Docs (3)** — OpenAPI rewritten to the real wire contracts (the spec's
  camelCase `userId` had *taught* the F17 bug); architecture/README
  single-source sections; ODR sign-off document.

## 4. Verification evidence (executed vs. authored)

| Layer | Executed here (offline harness — see `tools/offline_harness/README.md`) | Authored → first executes in CI |
|---|---|---|
| Python | **315 tests green**, 0 failed/errors (py_compile 117/117; F821 clean) | 9 integration tests (need real FastAPI/httpx) |
| TypeScript | `tsc --noEmit` strict clean; **13 mapping tests green** (node:test) | eslint; build against real `node_modules` |
| Firebase rules | — (no emulator offline) | **12 rules tests** (`firebase/test/`), wired into the CI emulator job |
| Dart/Flutter | import/`part` resolution, 104-file bracket-balance state machine, symbol spot-checks, pubspec completeness | `flutter analyze` + `flutter test` + build_runner codegen |

**Disclosure — process incident:** an early Dart-import check ran from the
wrong working directory, walked an empty tree, and reported a false
“0 unresolved”, briefly masking 20 broken imports. Re-verification caught it;
the imports were then actually fixed, and the checker guidance now makes an
empty walk visible. Recorded in the changelog verification summary — reports
in this repo state what was *executed*, not what was intended.

## 5. Audit dispositions — false positives (with proof)

| Audit finding | Verdict | Why |
|---|---|---|
| P2-3 “Storage rules reject the PDFs the PDF-intelligence flow uploads” | **False positive** | Client PDFs never transit client Storage: intelligence uploads are multipart direct to the Python service; knowledge docs are written server-side via the Admin SDK (rules don’t apply). The *real* Storage gap was the layover photo path — found and fixed (S7). |
| P3-4 “classification_engine is a NotImplementedError stub” | **False positive** | The `raise` is the abstract base method of a proper strategy pattern; ten concrete classifiers implement it and the pipeline consumes them (`intelligence/router.py`). |
| “behaviorEvents dual schema = broken pipeline” | **Downgraded to documented tech debt** | Two coherent writer/reader families share the collection (Functions camelCase bid events ↔ auto-bid reader; Python snake_case trade events ↔ profile service), each with its own composite index. Splitting collections is a data migration, not a release fix. |

## 6. Residual risks (ranked)

1. **Dart is verified, not compiled.** Structural checks are strong but only
   `flutter analyze` proves type-correctness of the reconstructed files —
   hence release condition 2. Mitigation: the three created files were built
   strictly from enumerated call-site contracts.
2. **FTL values await human sign-off** (ODR-001/002/003). Interim posture is
   the most conservative in-repo set; corrections are admin edits.
3. **Codegen not committed** — `models.freezed.dart`/`.g.dart` are generated
   in CI; a build_runner version skew would surface there.
4. **Pipelines authored, unexercised** — deploy/rollback/security workflows
   and the rules-test job first run in the org’s environment.
5. **No android/ios platform directories in the archive** — store packaging
   assets are managed outside this repo; flag when cutting store builds.
6. **behaviorEvents dual schema** — consolidate post-launch with a backfill.

## 7. Change inventory (mechanical `diff -rq` vs. the uploaded archive)

**51 files modified · 61 files added** (24 top-level additions incl. 4 new
directories). Highlights:

* NEW core: `python_services/legality/rules_source.py`, `scripts/seed_legality_rules.py`,
  `firebase/functions/src/mapping.ts`, `flutter_app/lib/core/{theme/app_theme,constants/app_constants,utils/content_filter,utils/period_utils}.dart`
* NEW tests: `tests/unit/{test_rules_source,test_engine_consistency,test_layover_content}.py`,
  `firebase/test/rules.spec.mjs` (+pkg), `firebase/functions/test/mapping.test.js`,
  `flutter_app/test/unit/{content_filter_test,app_constants_test}.dart`
* NEW ops/governance: `.github/workflows/{deploy,rollback,security}.yml`,
  `.github/{CODEOWNERS,dependabot.yml}`, `python_services/ruff.toml`,
  `firebase/functions/.gitignore`
* NEW verification tooling: `tools/offline_harness/**` (runner, shims, TS stubs, F821 checker)
* NEW docs: `OWNER_DECISION_REQUEST.md`, `reports/{SECURITY_REPORT,ARCHITECTURE_REPORT,PERFORMANCE_AND_TESTING,RELEASE_READINESS}.md`

The exhaustive machine-generated lists ship in this archive at
`reports/CHANGED_FILES.txt`.

## 8. Where to start reading

1. `reports/RELEASE_READINESS.md` — the decision and its conditions.
2. `OWNER_DECISION_REQUEST.md` — the three sign-offs only you can give.
3. `REMEDIATION_CHANGELOG.md` (Pass 2) — every fix, file-by-file.
4. `reports/SECURITY_REPORT.md` / `ARCHITECTURE_REPORT.md` /
   `PERFORMANCE_AND_TESTING.md` — domain deep-dives.
5. `tools/offline_harness/README.md` — exactly what the offline verification
   does and does not prove.

---

## Addendum — v1.3.0-dev feature work (same day, post-verdict)

After this report's verdict, the owner's product vision ("AI + Advanced
Manual Filters") was implemented server-side as **additive** feature work.
The v1.2.0 verdict and its four conditions are **unchanged** — nothing above
was modified except one orphaned default in `ranking/scorer.py` now deriving
from the canonical rules source.

Delivered: `python_services/filter_engine/` (declarative 48-filter registry —
34 active / 14 honestly-pending; single-pass evaluator; **hybrid merge where
manual filters are locked against AI override by construction**),
`GET /v1/lines/filters` + `POST /v1/lines/search` (Manual/AI/Hybrid in one
contract with full transparency: applied filters, dropped-AI reasons,
per-line matched-filter checklists, component scores, prose reasons), chat
integration (`rich_content.filter_query`), Flutter contract files, OpenAPI,
and `VISION_GAP_ANALYSIS.md` (pillar matrix + roadmap B–E; the 3-mode UI is
Phase C). Executed evidence: **33 new tests green; full suite 348 · 0
failed**. Details: VERSION.md 1.3.0-dev and the changelog's Phase-2 section.

---

## Addendum — v1.4.0-dev feature work (2026-07-12, post-verdict)

**Automatic Roster Synchronization** was implemented as additive feature work;
the v1.2.0 verdict and its four conditions remain **unchanged**.

Scope: provider-based roster sync layer (backend `roster_sync/` + Flutter
`core/roster_sync/` + Settings screens) with the spec's two hard constraints
enforced structurally — the CAE Crew Access provider is config-activated and
refuses credentials until an official integration is configured (no
unofficial automation exists in the codebase), and credentials live only in
device Keychain/Keystore with a server-side pre-parse leak guard (422) as the
second wall. ICS calendar feeds are live end-to-end today; imports are
checksummed (dedup), diffed, versioned (history preserved; failures keep the
cached roster), and fan out to the intelligence engines automatically. Manual
PDF upload remains as the fallback source per the priority order.

Executed evidence: full suite **382 passed · 0 failed** (34 roster-sync unit
tests; 5 integration tests green in CI, skipped-offline locally by design);
Flutter roster-sync suite added. Details: VERSION.md 1.4.0-dev, changelog
Phase-3 section, `docs/ROSTER_SYNC.md` (incl. sequence diagrams + CAE
activation checklist).

---

## Addendum — v1.5.0-dev (2026-07-13): Zero-Knowledge Credential Model

Adopted as a permanent platform rule (`docs/ZERO_KNOWLEDGE_CREDENTIALS.md`);
v1.2.0's verdict and conditions remain **unchanged**. An audit of the existing
implementation against the directive closed two gaps that were green in tests
and broken in reality: (1) `RosterSyncBootstrap` had zero callers, so
"automatic sync after restart" never actually ran — now mounted above every
route; (2) device-side normalization had created a second ICS parser with no
parity guard (and a comment falsely claiming one existed) — now locked to the
canonical parser by a shared golden fixture asserted on both sides, so
divergence fails the build instead of silently corrupting rosters.

**ODR-004** added (architectural, non-blocking): server-managed credentials can
never be enabled by ops configuration alone; the switch requires the owner's
explicit approval reference, per provider.

Executed evidence: **436 passed · 0 failed**.

---

## Addendum — v1.6.0-dev (2026-07-14): Professional Profile Screen

Ten sections, each bound to a real service; no duplicated logic. New backend
endpoint `GET /v1/ai/status` reports AI state from real sources only (never
"online" without a configured key; an empty knowledge base shows "—", not
"Today"). Email Import — which does not exist — renders as **"Not available
yet"** rather than as a convincing fake; Excel import, which is real, is listed
as available. The old screen's working features (Optimization Mode, ranking
preferences) were preserved verbatim, not dropped. Zero-Knowledge is reinforced:
the Security card reads no credential source by construction, Disconnect-All
wipes the secure enclave while keeping roster history, and Logout preserves
credentials per the directive.

Executed evidence: **449 passed · 0 failed**. v1.2.0's verdict and conditions
remain unchanged.
