# Merge Plan — Authoritative Implementations per Subsystem

TARGET is authoritative throughout; SOURCE contributes only where demonstrably
newer, compatible, and validated. Per-file rationale: `file-classification.csv`.

| Subsystem | Authoritative | Useful SOURCE additions | Incompatible / legacy SOURCE work |
|---|---|---|---|
| Flutter application | TARGET (14 commits newer: line filters, approval flow, platform scaffolding) | `main.dart` emulator gating (compile-time `USE_FIREBASE_EMULATORS`, default off) | theme retune, labelAr blanking, BadgesRow refactor, `displayName` removal |
| Authentication | TARGET (`auth_provider.dart` evolved) | none merged | — |
| Routing | TARGET | SOURCE redirect fix archived (manual review #1 — TARGET likely still has router-rebuild-on-auth bug) | — |
| Roster synchronization | TARGET | SOURCE approval-gated bootstrap archived (manual review #2) | — |
| Firebase initialization (Flutter) | TARGET `firebase_options.dart` (real config; SOURCE has placeholders) | emulator wiring in `main.dart` | SOURCE placeholder firebase_options |
| Firebase initialization (Python) | fork base | **MERGED** SOURCE `utils/firebase.py` — emulator-aware Admin init, only active when `*_EMULATOR_HOST` set; explicit-key/ADC paths unchanged | — |
| Firebase rules / indexes / functions / rules-tests | byte-identical in both | — | — |
| Firebase emulators | TARGET `firebase.json` (identical) | E2E start script + `main.dart` gating use them | debug logs skipped |
| Admin panel | TARGET (`server.js` + evolved SPA) | none merged | SOURCE SPA variant archived |
| Python services (engines, routers, main) | TARGET | **MERGED** `ai/status_router.py` (Firestore-unavailable degradation) | SOURCE `nlp_router.py` predates TARGET's GLM support |
| AI platform scaffolding | — (absent from TARGET) | **ADDED** `python_services/ai_platform/` (12 modules, standalone, not imported by `main.py`) + 10 unit tests | — |
| API contracts | both identical (`docs/api-contract.yaml`, `docs/openapi.yaml`) | `openapi.json` skipped (generated) | — |
| Models & generated models | TARGET `models.dart` + its generated pair (rule 19) | — | SOURCE generated pair |
| Database / migrations | none present in either repo (Firestore rules/indexes identical) | — | — |
| Vercel configuration | TARGET only (`vercel.json`, `vercel_api/`, deploy script) — untouched | — | — |
| GitHub workflows | TARGET (`ci.yml`, `deploy.yml`, `security.yml`, `rules-tests.yml`) | SOURCE ci/deploy hardening archived (manual review #3, #4) | — |
| Playwright E2E | — (absent from TARGET) | **ADDED** `flutter_app/e2e/**` (config, spec, lockfile, start script with JDK-path made defensive) | — |
| Shell scripts | — (absent from TARGET) | **ADDED** all 8 ops scripts (ADR-011 suite), inspected line-by-line; `reset.sh` caveat re generated Dart noted | — |
| Setup & doctor scripts | added from SOURCE | `doctor.sh` smoke-run in validation | — |
| Architecture documentation | TARGET base | **MERGED** `NAJM_ARCHITECTURE.md` (additive §0), **ADDED** `docs/architecture/**`, `ARCHITECTURE_LOCK.md`, `SECRETS.md` | — |
| Phase plans & reports | TARGET `plans/` (phase 0–2 identical) | phase-2/3/6 completion reports → `archive/repository_consolidation/historical_phases/` | archived docs reference SOURCE-only commit hashes |
| CLAUDE.md / AGENTS.md / CODEX.md | no TARGET instruction file existed; **new `AGENTS.md` authored** (TARGET-authoritative, incorporates compatible CLAUDE.md commands, corrects SOURCE-only conventions like "generated files not committed") | original CLAUDE.md archived for provenance | SOURCE rules that contradict TARGET (venv name, port, generated-file policy) not carried over |
| README | identical in both | — | — |
| Env template / gitignore | merged (see applied-changes.md) | SOURCE structure + secret-isolation notes | `*.freezed.dart` ignore rejected |

## Unresolved uncertainty (kept TARGET, flagged)

1. Router rebuild-on-auth fix (archive → manual review).
2. Approval-gated roster sync (archive → manual review).
3. CI client-secret-isolation job — blocked by `admin_panel/index.html` dev-token.
4. Cloud Run Secret Manager injection — requires GCP-side secrets to exist.
5. Offline-queue replay semantics (silent no-op vs explicit throw).
