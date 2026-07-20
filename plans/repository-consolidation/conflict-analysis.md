# Conflict Analysis

Files where both lines did meaningful, incompatible work, or where a SOURCE
"improvement" would regress TARGET. In every conflict TARGET was kept unchanged
(rule 6); substantive SOURCE versions are preserved under
`archive/repository_consolidation/source_unmerged/`.

## 1. `flutter_app/lib/app/router.dart` — BOTH changed — HIGH value conflict

- TARGET: heavy post-fork evolution (line filters, detail routes, approval flow).
- SOURCE (uncommitted, 2026-07-20): changes `routerProvider` to `ref.read` inside
  `redirect` instead of `ref.watch` at provider scope, so a Firebase auth emission
  no longer rebuilds the entire `GoRouter` (which resets the navigation stack).
- TARGET **still has** the `ref.watch(authStateProvider)` pattern at
  `flutter_app/lib/app/router.dart:138`, so it likely still carries the
  navigation-reset bug SOURCE fixed.
- Why not merged: the fix's safety depends on every auth transition being handled
  by explicit navigation (SplashScreen + screen-level actions). TARGET's approval
  flow (commit `6c6ac2d`) may rely on redirect re-evaluation via rebuilds. Blind
  application could strand unauthenticated users on protected routes.
- **Recommended manual review item #1** — archived at
  `archive/repository_consolidation/source_unmerged/flutter_app/lib/app/router.dart`.

## 2. `flutter_app/lib/core/roster_sync/roster_sync_bootstrap.dart` — SOURCE-only change — HIGH

- SOURCE (uncommitted, 2026-07-20): starts roster sync only when the signed-in
  user's custom claims show `accountStatus == 'approved'` (or admin), stops the
  scheduler on sign-out, and re-checks on auth transitions.
- TARGET: fork-base version (starts sync unconditionally on app start) but TARGET
  separately stabilized its approval flow elsewhere (`6c6ac2d`).
- Why not merged: overlapping intent with TARGET's own approval work; depends on
  custom-claim names (`accountStatus`, `admin`, `superAdmin`) that TARGET's
  backend must actually set; double-gating or claim-name drift would silently
  disable sync.
- **Recommended manual review item #2** — archived.

## 3. `flutter_app/lib/core/services/queue_sync_service.dart` — SOURCE-only change — MEDIUM

- SOURCE converts silent `break` no-ops for unwired offline replay actions
  (bid reorder, trade accept, preferences, trade cancel) into explicit
  `UnsupportedError` throws, and **unwires** the `cancelTrade` replay that TARGET
  has wired to `tradesRepo.cancelTrade(...)`.
- Merging would remove working TARGET behavior and could crash queue draining.
  Kept TARGET; archived.

## 4. `admin_panel/index.html` — BOTH changed (300 diff lines) — MEDIUM

- TARGET variant pairs with TARGET-only `admin_panel/server.js` and a `dev`
  npm script; includes a hardcoded `'X-Service-Token': 'dev-token'` header
  (security finding — see security-review.md).
- SOURCE variant follows the "static SPA, no server" architecture.
- Unmergeable single-file SPA divergence; kept TARGET; archived.

## 5. `.github/workflows/ci.yml` — SOURCE adds `client-secret-isolation` job — MEDIUM

- The job asserts no server secret names / `X-Service-Token` appear in
  `flutter_app/lib` or `admin_panel`. Verified it would **fail today** against
  TARGET (`admin_panel/index.html:1300`). Adopting a failing gate would break CI
  (and fixing the panel is a functional change beyond consolidation scope).
- Kept TARGET; archived. **Recommended manual review item #3**: fix the dev-token
  usage, then adopt SOURCE's job verbatim.

## 6. `.github/workflows/deploy.yml` — SOURCE adds Secret Manager injection — MEDIUM

- SOURCE's Cloud Run deploy step injects `INTERNAL_SERVICE_TOKEN`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ADMIN_SETUP_TOKEN` from Google Secret
  Manager and sets production env vars; fails closed if secrets don't exist.
- Rule 13 (do not alter production deployment behavior) + the secrets are not
  verified to exist in TARGET's GCP project. Kept TARGET; archived.
  **Recommended manual review item #4.**

## 7. `flutter_app/lib/core/models/models.freezed.dart` (+ `.g.dart`) — generated

- Each side's generated files match its own `models.dart`. TARGET's `models.dart`
  is newer (TARGET_CHANGED_ONLY), so TARGET's generated files are the consistent
  pair; regeneration via `build_runner` is the authoritative path (rule 19).
  Kept TARGET; not archived (regenerable from SOURCE's models.dart in SOURCE).

## 8. `flutter_app/lib/firebase_options.dart` — config conflict resolved by rule 13

- TARGET: real `najm-dev-9159c` web client config (public identifiers, not secrets).
- SOURCE: `REPLACE_WITH_*` placeholders. Keeping TARGET is mandatory.

## 9. Minor kept-TARGET divergences (full list in CSV)

`theme.dart` (cosmetic values), `app_en.arb` (apostrophe style),
`shared_widgets.dart` (import order), `legality_card.dart` (formatting),
`trade_detail/trade_initiate` (labelAr strings TARGET keeps),
`upload_document_screen.dart` (import namespace style),
`profile_screen.dart`/`ai_status_service.dart` (paired refactor SOURCE-side),
`web/index.html` (TARGET uses non-deprecated meta), `pubspec.lock`,
`.metadata`, `admin_panel/package.json`, `python_services/ai/nlp_router.py`
(TARGET's GLM support supersedes), `python_services/main.py`, `pdf_parser.py`,
`utils/auth.py` (TARGET evolved).
