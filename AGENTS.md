# AGENTS.md — NAJM (Crew Intelligence Platform)

Primary instruction file for coding agents working in this repository.

> **This repository (`NAJM_DEPLOY_TEST`) is the authoritative NAJM repository.**
> The legacy repository (`NAJM/extracted/najm_complete`) is read-only history; its
> useful assets were consolidated here on 2026-07-20
> (see `plans/repository-consolidation/`). When this file and archived legacy
> documents disagree, this file and the current TARGET code win.

## What this is

Najm ("⭐" / نجم) — an unofficial scheduling assistant for Saudi Airlines cabin
crew. Deployable pieces sharing one Firestore backend:

- `flutter_app/` — Flutter 3.24 client (Riverpod, GoRouter, Hive, Dio) with full
  platform scaffolding (web + android/ios/macos/linux/windows).
- `python_services/` — FastAPI app (`main.py`) mounting one router per domain
  (parser, legality, rest, ranking, AI assistant, knowledge engine, roster sync).
- `firebase/` — Firestore/Storage rules, indexes, TypeScript Cloud Functions,
  rules tests, emulator config.
- `admin_panel/` — single-file SPA (`index.html`) plus a small local `server.js`
  (`npm run dev`).
- `vercel_api/` + `vercel.json` + `scripts/deploy_vercel.sh` — current web
  deployment path (Vercel serving the built Flutter web app + `/api`).
- `python_services/ai_platform/` — standalone scaffolding for the approved
  provider-independent AI platform (documentation-driven; **not** wired into
  `main.py` yet). See `NAJM_ARCHITECTURE.md` §0 and `docs/architecture/`.

Read `NAJM_ARCHITECTURE.md` before non-trivial changes. `docs/ARCHITECTURE_LOCK.md`
records ADRs from the legacy hardening line; treat it as guidance, not as an
override of current TARGET code.

## Repository conventions (differ from legacy CLAUDE.md — follow these)

- **Generated Dart files ARE committed** (`*.freezed.dart`, `*.g.dart`).
  Regenerate with build_runner after editing `models.dart`; commit the result.
  (The legacy repo ignored them — that rule does not apply here.)
- Python virtualenv lives at `python_services/.venv` (Python 3.11).
- Local backend runs on port **8000** via `./start.sh`; Cloud Run uses 8080.
- Secrets live in `.env` (never committed). `serviceAccountKey.json` and
  `.env.local` are local-only and git-ignored. Never hardcode secrets; the
  Flutter/admin clients must never receive server secrets
  (`INTERNAL_SERVICE_TOKEN`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
  `ADMIN_SETUP_TOKEN`) — see `docs/SECRETS.md`.

## Commands

### Local dev stack (emulator-backed, credential-free)
```bash
./setup.sh      # one-time bootstrap (idempotent, non-sudo)
./doctor.sh     # read-only environment diagnostics
./start.sh      # Firebase emulators + uvicorn (:8000) + Flutter web
./stop.sh       # graceful shutdown (per-service args supported)
./update.sh     # re-sync deps to manifests after pulling
./clean.sh      # remove regenerable artifacts; reset.sh = deep reset (guarded)
```
`reset.sh` deletes generated Dart files; restore/regenerate them (they are
committed here) before committing anything after a reset.

### Flutter (`flutter_app/`)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after editing models
flutter gen-l10n                       # after editing lib/shared/l10n/app_{ar,en}.arb
flutter analyze
flutter test                           # test/unit/, test/widget/
flutter build web --release
```

### Flutter E2E (`flutter_app/e2e/`, Playwright + Firebase emulators)
```bash
cd flutter_app/e2e && npm ci
npx playwright install chromium        # once
npm run test:e2e                       # boots emulators+backend+app via scripts/start-local.sh
```
Runs entirely against the `demo-najm` emulator project — never against production.

### Python services (`python_services/`)
```bash
source .venv/bin/activate
pip install -r requirements.txt
export INTERNAL_SERVICE_TOKEN=dev-token    # fail-closed: app refuses to start without it
uvicorn main:app --reload --port 8000
ruff check .                               # blocking lint gate (narrow scope, see ruff.toml)
pytest -q                                  # tests/unit/, tests/integration/, tests/eval/
```

### Firebase (`firebase/`)
```bash
cd firebase/functions && npm install && npm run build && npm test && npm run lint
firebase emulators:start --only functions,firestore,auth
# rules tests:
firebase emulators:exec --only firestore,storage "npm --prefix test install && npm --prefix test test"
```

### Deployment
- Web: `scripts/deploy_vercel.sh` (builds Flutter web with
  `AI_SERVICE_URL=https://najm-dev.vercel.app/api`, copies `vercel_api/`, runs
  `vercel --prod`). Do not deploy without the owner's go-ahead.
- `.github/workflows/deploy.yml` (Cloud Run/Firebase Hosting) is the earlier
  path; a hardened Secret-Manager variant is archived under
  `archive/repository_consolidation/source_unmerged/.github/workflows/`.

## AI providers

The NLP assistant supports `AI_PROVIDER=anthropic` (default) or `glm`
(`python_services/ai/glm_client.py`). Direct provider calls are acknowledged
legacy debt; the approved target is the adapter-based AI platform documented in
`docs/architecture/` — do not add new direct provider calls to product code.

## Consolidation provenance

- Active plans live in `plans/`; historical phase reports in
  `archive/repository_consolidation/historical_phases/` (they reference legacy
  commit hashes that do not exist in this repo's history).
- SOURCE work that could not be merged safely (router redirect fix,
  approval-gated roster sync, offline-queue strictness, hardened CI/deploy
  workflows, legacy admin SPA) is preserved under
  `archive/repository_consolidation/source_unmerged/` with rationale in
  `plans/repository-consolidation/conflict-analysis.md`. Archived files are
  reference material, not implementation directives.
- The original legacy `CLAUDE.md` is archived at
  `archive/repository_consolidation/source_unmerged/CLAUDE.md`.
