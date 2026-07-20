# Applied Changes Ledger

Every action taken on the TARGET working tree (branch `merge/repository-consolidation`,
based on checkpoint `67ca617`). SOURCE was never modified. Nothing was committed.
Per-file classification for ALL 604 inventoried files: `file-classification.csv`.

## ADDED — 51 files (new to TARGET, copied from SOURCE)

### Playwright E2E suite (6) — risk: low/medium
| File | Notes |
|---|---|
| `flutter_app/e2e/package.json` | scripts: test:e2e / :headed / :report; @playwright/test ^1.54.1 |
| `flutter_app/e2e/package-lock.json` | valid lockfile for npm ci |
| `flutter_app/e2e/playwright.config.js` | chromium desktop+mobile, local webServer via start-local.sh, remote via E2E_BASE_URL |
| `flutter_app/e2e/tests/app.spec.js` | public-route smoke + runtime-error capture; stubs one googleapis config call |
| `flutter_app/e2e/.gitignore` | node_modules, test-results, playwright-report |
| `flutter_app/e2e/scripts/start-local.sh` | **modified during add**: hardcoded Temurin-21 JDK PATH prefix made conditional (`[[ -d $JDK_BIN ]]`); everything else verbatim; kills only processes it spawned; targets `demo-najm` emulators only. Executable bit preserved. |
Justification: TARGET had no E2E capability; suite is self-contained, emulator-only, no production access.
Validation: shell syntax check; E2E run attempted in Step 6.

### Python AI-platform scaffolding (12) + unit tests (10) — risk: low
`python_services/ai_platform/{__init__,budget,contracts,errors,gateway,ledger,orchestrator,policy,pricing,prompt_renderer,provider_adapter,registry}.py`
`python_services/tests/unit/test_ai_platform_{budget,contracts,gateway,ledger,orchestrator,policy,pricing,prompt_renderer,provider_adapter,registry}.py`
Justification: standalone package implementing the approved target AI-platform
contracts (docs/architecture); verified **not imported** by `main.py` or any
runtime module — zero runtime behavior change. Tests self-contained.
Validation: full pytest run in Step 6.

### Documentation (13) — risk: low
`docs/architecture/` (11 files: AI_PLATFORM_OVERVIEW, AI_ORCHESTRATOR,
AI_GATEWAY_AND_PROVIDER_ADAPTERS, AI_REGISTRIES, PROMPT_REGISTRY,
AI_FEATURE_FLAGS_AND_ENTITLEMENTS, AI_CREDITS_LEDGER_AND_BILLING,
AI_SAFETY_OBSERVABILITY_AND_INCIDENTS, AI_DATA_MODEL_PROPOSALS,
AI_MIGRATION_STRATEGY, AI_ARCHITECTURE_DECISION_BACKLOG),
`docs/ARCHITECTURE_LOCK.md`, `docs/SECRETS.md` (SOURCE working-tree versions —
the newest; SECRETS.md verified to contain no actual secret values).
Justification: referenced by merged NAJM_ARCHITECTURE.md §0; documentation only.

### Ops scripts (8) — risk: low (clean/reset: medium)
`setup.sh doctor.sh start.sh stop.sh restart.sh clean.sh reset.sh update.sh`
(executable bits preserved). Inspected line-by-line: repository-relative paths;
non-sudo; fail-fast; stop.sh kills only pids recorded by start.sh in `.najm/`;
clean.sh removes only regenerable artifacts; reset.sh is confirmation-guarded,
preserves `.env`/sources — **caveat**: it deletes `*.g.dart`/`*.freezed.dart`,
which TARGET commits (restorable via git / build_runner; noted in AGENTS.md).
Validation: `bash -n` all scripts; `doctor.sh` (read-only) smoke run in Step 6.

### Project instructions (1)
`AGENTS.md` — newly authored primary instruction file. Incorporates compatible
commands from SOURCE `CLAUDE.md`; corrects legacy-only conventions (generated
files ARE committed here, `.venv` not `venv`, port 8000, Vercel deploy path,
GLM provider); states TARGET authority; links archive provenance.

### Archive documentation (1)
`archive/repository_consolidation/README.md`.

## MERGED — 9 existing TARGET files modified

| File | How merged | Risk | Validation |
|---|---|---|---|
| `python_services/utils/firebase.py` | adopted SOURCE version: adds `_AnonymousCredentials` + emulator branch active only when a `*_EMULATOR_HOST` env var is set; explicit-key and ADC (Cloud Run) paths preserved | low | pytest; path review |
| `python_services/ai/status_router.py` | adopted SOURCE version: `get_firestore()` failure now degrades knowledge-base card to 'unavailable' instead of 500 | low | pytest |
| `python_services/tests/conftest.py` | adopted SOURCE version: adds `pytest.run_async` shim (offline-harness parity) | low | pytest |
| `python_services/tests/unit/test_roster_sync.py` | adopted SOURCE version: repo-scan test skips vendored/build dirs | low | pytest |
| `flutter_app/lib/main.dart` | adopted SOURCE version: `USE_FIREBASE_EMULATORS` compile-time gate (default **false**) wiring auth/firestore/storage emulators for E2E; production path unchanged (`DefaultFirebaseOptions.currentPlatform` — TARGET's real config file untouched); rest of diff is comments | medium | analyze, test, release web build |
| `NAJM_ARCHITECTURE.md` | adopted SOURCE working-tree version: adds §0 "AI Platform authority" (references the docs/architecture files added); only 2 lines reworded, rest additive | low | manual diff review |
| `.env.example` | rebuilt on SOURCE ADR-003 structure (secrets vs config separation, Secret Manager ids, OPENAI_API_KEY, LEGALITY_RULES_TTL_SECONDS, CAE owner-gating); added TARGET-specific `AI_PROVIDER`/GLM vars and Monitoring (SENTRY_DSN) section. No secret values. | low | manual review |
| `.gitignore` | selective union: added `.env.*` + `!.env.example`, serviceAccount/credential patterns, venv variants, ruff/mypy/coverage caches, node_modules, functions lib, `.najm/`, emulator logs, `.claude/settings.local.json`, `*.iml`; **rejected** SOURCE's `*.freezed.dart`/`*.g.dart`/l10n ignores (TARGET commits generated Dart) and blanket `*.log` (too broad); kept every TARGET rule | low | `git ls-files -i` check |
| `flutter_app/e2e/scripts/start-local.sh` | (listed under ADD) JDK path made conditional | low | bash -n |

## ARCHIVED — 10 files preserved, TARGET behavior unchanged

Under `archive/repository_consolidation/source_unmerged/` (paths mirrored):
`flutter_app/lib/app/router.dart`, `flutter_app/lib/core/roster_sync/roster_sync_bootstrap.dart`,
`flutter_app/lib/core/services/queue_sync_service.dart`, `admin_panel/index.html`,
`.github/workflows/ci.yml`, `.github/workflows/deploy.yml`, `CLAUDE.md`.
Under `archive/repository_consolidation/historical_phases/`:
`PHASE_2_dev_environment.md`, `PHASE_3_secrets.md`, `phase6-closure-report.md`.
Justifications: `conflict-analysis.md` items 1–6; phase reports reference
legacy-only commit hashes.

## SKIPPED — nothing copied (14 SOURCE files/groups)

| SOURCE path | Reason |
|---|---|
| `.env`, `python_services/.env` | secrets (rule 11); values never read |
| `.claude/settings.local.json` | machine-local settings |
| `.najm/*.log`, `.najm/*.pid` (6) | runtime logs/pids |
| `firebase/firebase-debug.log`, `firestore-debug.log` | emulator debug logs |
| `python_services/openapi.json` | generated FastAPI export; TARGET serves `/openapi.json` in dev |
| `flutter_app/pubspec.lock` (SOURCE variant) | TARGET's lock is what TARGET builds/deploys with; pubspec.yaml identical |
| 24 diverged files kept as TARGET | see conflict-analysis.md §9 and CSV |

## CONFLICT (kept TARGET, archived SOURCE) — 6
Router, roster-sync bootstrap, queue-sync service, admin SPA, ci.yml, deploy.yml
(details in conflict-analysis.md).

## Explicitly NOT done
- No commit, push, deploy, or external-service change.
- No TARGET file moved to archive or deleted (rule 9) — obsolete candidates only documented.
- SOURCE untouched (verified again after apply: `git -C SOURCE status` unchanged).
