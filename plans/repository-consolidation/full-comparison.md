# Full Repository Comparison — SOURCE vs TARGET

Method: read-only recursive walk of both trees excluding generated/cache/dependency
directories (`.git`, `node_modules`, `build`, `dist`, `.dart_tool`, `.venv`, `.vercel`,
`.pytest_cache`, `.firebase`, `test-results`, `playwright-report`, `__pycache__`, etc.),
SHA-256 content hashing, then per-file git-history and content inspection. Full per-file
detail is in `file-classification.csv` (604 rows).

## Headline numbers

| Category | Count |
|---|---|
| Files inventoried in SOURCE | 457 |
| Files inventoried in TARGET | 539 |
| Present in both, byte-identical | 344 |
| Present in both, different | 48 |
| Only in SOURCE | 65 |
| Only in TARGET | 147 |
| Probable renames (same content, moved) | 0 |

## Relationship between the repositories

The two repositories are **divergent lines from a common ancestor** (~2026-07-13/15
state of the NAJM project), not a linear old→new pair:

- **SOURCE** (`NAJM/extracted/najm_complete`) got a fresh `git init` on 2026-07-15 and
  received a "Phase 2/3" hardening line the same day: ops scripts (`setup.sh`,
  `doctor.sh`, `start.sh`, …), secrets management (docs/SECRETS.md, Secret Manager
  deploy injection, CI secret-isolation invariant), emulator-aware Python Firebase
  init, and test fixes. After its last commit it accumulated **uncommitted** work
  (as late as 2026-07-20 02:34–02:46): a router redirect fix, approval-gated roster
  sync, emulator-gated `main.dart`, plus untracked `python_services/ai_platform/`,
  `flutter_app/e2e/` (Playwright), and `docs/architecture/` (AI-platform target docs).
- **TARGET** (`NAJM_DEPLOY_TEST`) was created 2026-07-17 ("Prepare Najm deploy test")
  from a snapshot that predates SOURCE's hardening commits, then received 14 commits
  of its own newer work: real Firebase web config (`najm-dev-9159c`), Vercel
  deployment (`vercel.json`, `vercel_api/`, `scripts/deploy_vercel.sh`), GLM AI
  provider support, admin-panel `server.js`, full mobile/desktop platform scaffolding
  (android/ios/macos/linux/windows), line filters, and approval-flow stabilization.

Consequently freshness was determined **per file** by three-way comparison against
TARGET's first commit (`61242c5`, the fork base) plus content review — never from
timestamps alone:

- `TARGET_CHANGED_ONLY` (14 files) — TARGET evolved, SOURCE at fork base → keep TARGET.
- `SOURCE_CHANGED_ONLY` (29 files) — SOURCE evolved, TARGET never touched → merge
  candidates, each content-reviewed (7 adopted, rest kept/skipped with reasons).
- `BOTH_CHANGED` (4 files: `.gitignore`, `admin_panel/index.html`,
  `flutter_app/lib/app/router.dart`, `models.freezed.dart`) → see conflict-analysis.md.
- `NO_BASE` (1 file: `.flutter-plugins-dependencies`) — generated, keep TARGET.

## Only-in-SOURCE breakdown (65 files)

| Group | Files | Decision |
|---|---|---|
| Playwright E2E suite (`flutter_app/e2e/**`) | 6 | ADD |
| `python_services/ai_platform/**` (standalone scaffolding pkg) | 12 | ADD |
| ai_platform unit tests | 10 | ADD |
| AI-platform architecture docs (`docs/architecture/**`) | 11 | ADD |
| `docs/ARCHITECTURE_LOCK.md`, `docs/SECRETS.md` | 2 | ADD |
| Ops scripts (`setup/doctor/start/stop/restart/clean/reset/update.sh`) | 8 | ADD |
| `CLAUDE.md` | 1 | MERGE → new `AGENTS.md` + archived original |
| Historical phase reports (docs/phases ×2, plans/phase6 ×1) | 3 | ARCHIVE |
| Secrets (`.env`, `python_services/.env`) | 2 | SKIP (rule 11) |
| Logs/pids/caches (`.najm/*`, firebase debug logs) | 8 | SKIP (rule 10) |
| `.claude/settings.local.json` | 1 | SKIP (machine-local) |
| `python_services/openapi.json` | 1 | SKIP (generated; FastAPI serves it) |

## Only-in-TARGET (147 files)

All kept untouched: Vercel deployment assets, admin `server.js`, GLM client,
`create_admin.py`, Flutter platform scaffolding (android/ios/macos/linux/windows),
`AUDIT/product_recovery/**` (the checkpoint commit), consolidation plans, and
`python_services/serviceAccountKey.json` + `.env.local` (local secrets — verified
**not** git-tracked; see security-review.md).

## Notable byte-identical areas (no action)

`firebase/` rules, indexes, functions and rules tests; `docs/` core set
(api-contract, openapi.yaml, runbook, legal, ROSTER_SYNC, …); `plans/` phase 0–2
reports and STATUS.md; `python_services` engines (legality, rest, ranking, parser
core, knowledge engine); nearly all Flutter feature code; `reports/`; `tools/`;
`test_fixtures/`; `.github/workflows/security.yml` and `rules-tests.yml`.
