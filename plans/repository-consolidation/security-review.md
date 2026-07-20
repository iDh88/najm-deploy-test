# Security & Configuration Review (post-consolidation)

Scope: full TARGET tree after Step 4, excluding `.git`, dependency and build
dirs. Secret **values** are never printed here — only locations and classifications.

## Findings summary

| # | Finding | Classification | Status |
|---|---|---|---|
| S1 | `python_services/serviceAccountKey.json` — real service-account credential (contains `private_key`, project `najm-dev-9159c`) on disk | potential secret (local dev credential) | **Not git-tracked**, matched by `.gitignore` (`serviceAccountKey.json`, `*serviceAccount*.json`). Pre-existing in TARGET; NOT copied from SOURCE; left in place. Recommend keeping it out of any backup/zip that gets shared. |
| S2 | `.env.local` (repo root) — local env file | potential secret | Not git-tracked; ignored via `.env.*`. Pre-existing; untouched; contents not read. |
| S3 | `admin_panel/index.html:1300` — hardcoded `'X-Service-Token': 'dev-token'` header in client SPA | production blocker (client holds a server auth header) | Pre-existing TARGET code; unchanged (functional fix out of consolidation scope). This is exactly what SOURCE's archived `client-secret-isolation` CI job would catch — **manual review item #3**: replace the dev token path, then adopt the archived ci.yml job. |
| S4 | Firebase client API keys (`AIza…`) in `firebase_options.dart` (web), `admin_panel/index.html`, `google-services.json`, `GoogleService-Info.plist` | legitimate public client identifiers | Firebase web/app API keys are public config, not secrets (documented in docs/SECRETS.md and .env.example). Pre-existing; unchanged. |
| S5 | `flutter_app/lib/firebase_options.dart` android/ios/macos blocks still `REPLACE_WITH_*` | production blocker for mobile builds only | Pre-existing in TARGET (only the web block is real). Not introduced or worsened by consolidation. Run `flutterfire configure` before shipping mobile. |
| S6 | `demo-api-key` / `demo-najm` / `127.0.0.1` emulator values in `flutter_app/lib/main.dart` | legitimate emulator use, properly gated | Introduced by the merged main.dart, but only reachable when built with `--dart-define=USE_FIREBASE_EMULATORS=true`; `bool.fromEnvironment` default is `false`, so production builds compile the real `DefaultFirebaseOptions` path. Verified by grep + release web build in Step 6. |
| S7 | `http://localhost:8080` defaults in 4 Dart service files (`roster_sync_api.dart`, `ai_status_service.dart`, `line_search_service.dart`, `intelligence_service.dart`) | development-only defaults | Pre-existing pattern: `String.fromEnvironment('AI_SERVICE_URL', defaultValue: localhost)`; the deploy script always passes the real URL via `--dart-define`. Unchanged. |
| S8 | `INTERNAL_SERVICE_TOKEN=dev-local-token` in `flutter_app/e2e/scripts/start-local.sh` | legitimate test/emulator use | Local-only value handed to a local uvicorn bound to 127.0.0.1; never a real secret. |
| S9 | `.najm/` runtime logs & firebase debug logs (SOURCE) | machine-local | Skipped entirely; `.najm/`, `firebase-debug.log`, `firestore-debug.log` now git-ignored in TARGET. |
| S10 | SOURCE `.env`, `python_services/.env` | secrets | Never read, never copied (rule 11/12). |
| S11 | `docs/SECRETS.md`, `docs/ARCHITECTURE_LOCK.md` (added) | documentation | Scanned for real key patterns (`sk-ant-…`, `sk-…`, `AIza…`, PEM blocks): none — placeholders/examples only. |
| S12 | `.env.example` (merged) | documentation example | Placeholder values only (`sk-ant-...`, `REPLACE_WITH_RANDOM_SECRET_STRING`). |
| S13 | `vercel_api/api/v1/ai/chat.js` | correct secret handling | Reads `GLM_API_KEY` from environment; no hardcoded secret. Unchanged. |

Secret-pattern scan (Anthropic/OpenAI/Google key shapes, private-key PEM blocks,
Slack/GitHub tokens) over the whole tree returned **no real secrets in tracked
files** — the only hits are the public Firebase client keys above and the
untracked local files S1/S2.

## Gating verification

- **Emulator config is gated**: `USE_FIREBASE_EMULATORS` is compile-time, default
  false; emulator hosts appear only inside that branch. Python emulator branch in
  `utils/firebase.py` activates only when a `*_EMULATOR_HOST` env var is set;
  Cloud Run continues to use ADC; explicit `GOOGLE_APPLICATION_CREDENTIALS` path
  unchanged.
- **Production config not replaced**: `firebase_options.dart` (real web config),
  `vercel.json`, `vercel_api/`, `.github/workflows/deploy.yml`, `firebase/` rules
  and indexes are all byte-identical to the checkpoint (`git diff 67ca617 --stat`
  shows no changes to them).
- **Ignore rules**: `git ls-files -ci --exclude-standard` is empty — no tracked
  file is now ignored; the `*.freezed.dart`/`*.g.dart` ignore from SOURCE was
  deliberately NOT adopted.
- **No secret copied from SOURCE**: the only SOURCE files containing secrets
  (`.env` ×2) were skipped; everything copied was content-reviewed.
