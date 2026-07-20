# Repository Consolidation — Final Report

Date: 2026-07-20 · Branch: `merge/repository-consolidation` · **Nothing committed, nothing pushed, nothing deployed.**

## Executive summary

All useful, non-secret, non-generated assets from the legacy SOURCE repository
(`/Users/monti/Desktop/NAJM/extracted/najm_complete`, read-only, verified
untouched) were selectively consolidated into TARGET
(`/Users/monti/Desktop/NAJM_DEPLOY_TEST`). The repos turned out to be **divergent
lines from a common ~July-13/15 ancestor**, so every differing file was resolved
per-file with TARGET as source of truth. Consolidation delivered: a Playwright
E2E suite (emulator-backed), the standalone AI-platform scaffolding package +
35 unit tests, 13 architecture docs, the 8-script local-ops suite, an
emulator-gated `main.dart`, four additive Python merges, a merged
`.env.example`/`.gitignore`, and a new authoritative `AGENTS.md`. Six
higher-risk SOURCE improvements were archived rather than merged, each with a
written rationale and a manual-review recommendation. All validation failures
were proven pre-existing (identical at checkpoint `67ca617`) except the new E2E
specs, which fail against TARGET's evolved app behavior and need adaptation.

## Initial state & protected references

- Initial state: `initial-state.md`. Working branch `merge/repository-consolidation`
  was fast-forwarded `d98162c` → `67ca617` (ancestor, no unrelated work) — the
  only branch movement performed; no history rewritten.
- **Protected & untouched**: branch `backup/before-consolidation` (= `67ca617`),
  tag `before-consolidation` (= `d98162c`), commit `67ca617` (reachable from the
  backup branch — verified before and after).
- SOURCE verified unchanged after all work (same git status: 8 modified + 14
  untracked entries, HEAD `d50c94b`).

## Change inventory (ledger: `applied-changes.md`; per-file: `file-classification.csv`)

| Category | Count | Detail |
|---|---|---|
| Files **added** | 51 | E2E suite (6) · ai_platform (12) + tests (10) · docs/architecture (11) · ARCHITECTURE_LOCK + SECRETS (2) · ops scripts (8) · AGENTS.md · archive README |
| Existing files **merged/modified** | 8 | `main.dart`, `utils/firebase.py`, `ai/status_router.py`, `tests/conftest.py`, `tests/unit/test_roster_sync.py`, `NAJM_ARCHITECTURE.md`, `.env.example`, `.gitignore` |
| Files **archived** | 10 | 7 → `archive/repository_consolidation/source_unmerged/` · 3 phase reports → `historical_phases/` |
| SOURCE files **skipped** | 12 | secrets (2), logs/pids (8), machine-local settings (1), generated openapi.json (1) |
| Diverged files **left as TARGET** | 40 | 24 kept-TARGET divergences + 14 TARGET-only-evolved + generated/lock files (see CSV) |
| **Conflicts** (TARGET kept, SOURCE archived) | 6 | router.dart, roster_sync_bootstrap.dart, queue_sync_service.dart, admin index.html, ci.yml, deploy.yml |
| Probable renames | 0 | — |

Probable duplicates & obsolete candidates: `duplicate-analysis.md` (nothing moved/deleted).

## Security findings (full detail: `security-review.md`)

- No secret copied from SOURCE; no secret values printed anywhere.
- `serviceAccountKey.json` + `.env.local` (real local credentials, pre-existing in
  TARGET) are **not git-tracked** and are covered by `.gitignore`.
- **S3 / production blocker**: `admin_panel/index.html:1300` hardcodes
  `'X-Service-Token': 'dev-token'` in client code (pre-existing; SOURCE's archived
  CI job would catch it).
- **S5 / mobile blocker**: `firebase_options.dart` android/ios blocks are still
  `REPLACE_WITH_*` placeholders (pre-existing; web config is real and untouched).
- Emulator gating verified end-to-end: release web bundle contains **0**
  occurrences of `demo-najm`/`demo-api-key`; Python emulator branch activates only
  under `*_EMULATOR_HOST`.
- Production config (firebase_options web, vercel.json, vercel_api, deploy.yml,
  firebase rules/indexes) is byte-identical to checkpoint `67ca617`.

## Validation results

| Check | Result | Pre-existing vs introduced |
|---|---|---|
| `flutter pub get` | **PASS** | — |
| `dart format --set-exit-if-changed` | **FAIL — pre-existing**: 106/132 files unformatted repo-wide at checkpoint too; the one consolidation-touched file (`main.dart`) was formatted; repo NOT mass-reformatted | pre-existing (105 files) |
| `flutter analyze` | 2379 issues (info/warning-heavy), **1 error**: `test/widget_test.dart` references non-existent `MyApp` (stock flutter-create test, broken at checkpoint). `lib/main.dart` (merged): **0 issues** | pre-existing |
| `flutter test` | **59 pass, 2 fail** — `widget_test.dart` compile (above) + `roster_sync_test.dart` "IcsFeedConnector stores the URL…" — both reproduced identically at checkpoint `67ca617` in a clean worktree | pre-existing |
| `flutter build web --release` | **PASS** (with merged main.dart) | — |
| Playwright E2E (new capability) | Stack fully boots (emulators + uvicorn + Flutter web); **6/6 specs fail against TARGET's app**: 4× a boot-time unauthenticated `GET /v1/roster-sync/status` → 401 captured as runtime error; 2× timeout on onboarding form semantics that changed in TARGET. Legacy specs need adaptation to TARGET behavior (and/or the archived roster-sync gating fix) | new capability; failures reflect TARGET/legacy-spec drift, not a regression |
| Admin panel | No lint/test/build/typecheck scripts exist (`dev`/`serve`/`deploy` only — deploy ops not run); `package.json` JSON valid | n/a |
| Python unit tests | **726 pass, 0 fail** (includes 35 new ai_platform tests) | — |
| Python full pytest | **741 pass, 21 fail, 1 skip** — the same 21 integration tests fail at checkpoint (verified in clean worktree) | pre-existing |
| ruff | **UNAVAILABLE** — not installed in `.venv` or system; not installed to avoid dependency changes; `python -m compileall` over touched/added packages: PASS | environment gap |
| Firebase functions | `npm install` + `npm test` (tsc build + node:test): **13/13 pass** | — |
| Firebase functions lint | **FAIL — pre-existing**: `npm run lint` has no ESLint config in either repo | pre-existing |
| Firestore/Storage rules tests | **12/15 pass, 3 fail** (`rosterSources` owner-read ×2, `syncEvents` isolation) — rules + tests byte-identical to checkpoint and to SOURCE; failures unrelated to consolidation. Requires JDK 21 (`temurin-21`; system default java 17 is rejected by firebase-tools 15.23 — doctor.sh flags this) | pre-existing |
| Firebase JSON configs | **PASS** (firebase.json, indexes, all package.json/lock parsed) | — |
| `git diff --check` | **PASS** (no whitespace errors) | — |
| Diff review | No deletions, no binary additions, no absolute local paths introduced (E2E JDK path made conditional), no disabled tests, no weakened validation | — |

## Exact git status & diff statistics

- Branch: `merge/repository-consolidation` @ `67ca617` + uncommitted work tree.
- Tracked modifications (8): `.env.example`, `.gitignore`, `NAJM_ARCHITECTURE.md`,
  `flutter_app/lib/main.dart`, `python_services/ai/status_router.py`,
  `python_services/tests/conftest.py`, `python_services/tests/unit/test_roster_sync.py`,
  `python_services/utils/firebase.py` → **329 insertions, 60 deletions**.
- Untracked additions: 51 consolidated files + 9 reports under
  `plans/repository-consolidation/` + 10 archived copies. No deletions of any kind.

## Remaining blockers (exact)

1. `admin_panel/index.html:1300` — client-side `X-Service-Token: dev-token` (S3).
2. `firebase_options.dart` — mobile platform placeholders (S5; run `flutterfire configure`).
3. E2E specs fail vs TARGET behavior (boot-time 401; onboarding semantics) — adapt specs or apply archived roster-sync fix.
4. 21 pre-existing Python integration-test failures; 2 pre-existing Flutter test failures; 3 pre-existing rules-test failures.
5. ruff missing from the venv; functions ESLint config missing; system default Java is 17 (emulators need the installed Temurin 21 on PATH).
6. Repo-wide Dart formatting drift (105 files).

## Recommended manual review items

1. Apply SOURCE's router `ref.read` redirect fix (archived) after confirming redirect semantics.
2. Evaluate approval-gated roster-sync bootstrap (archived) — would also fix the E2E 401s.
3. Fix admin-panel token handling, then adopt archived `ci.yml` secret-isolation job.
4. Adopt archived `deploy.yml` Secret Manager injection once the four secrets exist in GCP.
5. Decide offline-queue replay semantics (silent no-op vs explicit throw — archived variant).
6. Regenerate/adapt E2E specs to TARGET's current routes and onboarding flow.

## Recommended commit boundaries (not executed)

1. `docs: add architecture docs, SECRETS/ARCHITECTURE_LOCK, merged NAJM_ARCHITECTURE §0` (docs/*, NAJM_ARCHITECTURE.md)
2. `chore: add local-ops script suite + merged .gitignore/.env.example` (8 scripts, .gitignore, .env.example)
3. `feat(python): ai_platform scaffolding + tests; emulator-aware firebase init; status degradation` (python_services/*)
4. `test(e2e): add Playwright suite + emulator-gated main.dart` (flutter_app/e2e/*, lib/main.dart)
5. `docs: AGENTS.md + consolidation reports + archive` (AGENTS.md, plans/repository-consolidation/*, archive/*)

## Rollback instructions (do NOT run unless rollback is desired)

The consolidation is entirely uncommitted on `merge/repository-consolidation`;
the three protected references are intact:

- Inspect first: `git status`, `git diff`.
- To discard everything and return to the checkpoint: check out the backup
  branch (`git switch backup/before-consolidation`) or the checkpoint commit
  (`git switch --detach 67ca617`) from a clean state; the uncommitted
  consolidation files can be reviewed/removed selectively since every added path
  is listed in `applied-changes.md`. The pre-backup state is also reachable via
  tag `before-consolidation` (= `d98162c`).
- Nothing in SOURCE needs restoring — it was never modified.
