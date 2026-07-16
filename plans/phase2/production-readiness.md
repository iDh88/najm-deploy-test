# Phase 2 — Production Readiness (T3 · T4 · T7)

This document holds the Phase 2 items that are **guidance / analysis** rather than blind code edits. Where a change needs a Dart/TS compiler, a build-runner regeneration, or a visual preview that this environment doesn't have, it is specified precisely for you to apply and verify locally — not executed blind.

---

## T3 — UI / visual consistency & accessibility (guidance, not a blind redesign)

**Why guidance, not edits:** a sweeping design-token refactor across screens, done without a compiler or a rendered preview, is high-regression and low-confidence. The safe, high-value changes are enumerated here so you can apply them with `flutter run` open.

**Design tokens (already partly centralised).** `lib/app/theme.dart` builds text themes via `_buildTextTheme(...)` and defines colour constants (`grey900`, etc.). Consolidate remaining hard-coded values:
- Replace scattered `TextStyle(fontFamily: 'Inter', ...)` in `legality_badge.dart`, `shared_widgets.dart`, `router.dart` with the theme's text styles (`Theme.of(context).textTheme.*`). With Inter removed (T1), these hard-coded `'Inter'` references now silently fall back — routing them through the theme makes that intentional.
- Move ad-hoc colours/spacings to theme constants so light/dark stay in lockstep.

**Accessibility (WCAG-oriented):**
- **Contrast:** audit text-on-colour pairs (badges, chips) for ≥ 4.5:1; the legality/fatigue badges are the main risk.
- **Tap targets:** ensure interactive elements are ≥ 48×48 dp.
- **Semantics:** add `Semantics(label: ...)` to icon-only buttons and status badges so screen readers announce them.
- **Dynamic type:** the app already clamps `textScaler` to 0.85–1.3 in `app.dart` — verify no layout overflow at 1.3.

**Dead Arabic-locale toggle (found in T9):** `settings_screen.dart` (~line 195) sets `localeProvider` to `Locale('ar')`, but `app.dart`'s `localeResolutionCallback` hard-returns `Locale('en')`, so the toggle does nothing and `app_ar.arb` is unreachable. This is a **product decision**, applied locally (needs a compiler):
- **Option A (match English-only):** remove the toggle UI, delete `localeProvider`, remove `locale: locale`/`supportedLocales` Arabic wiring, delete `app_ar.arb`. Trace every `localeProvider` reference first (app.dart:18/63, settings:37/195).
- **Option B (ship Arabic properly, later):** add `Locale('ar')` to `supportedLocales`, drop the hard-coded `en` return, complete `app_ar.arb`, and handle RTL — a larger effort, explicitly out of the current English-only decision.
Recommendation: **Option A** now (removes a confusing no-op control), revisit B if Arabic UI is prioritised.

---

## T4 — Dead-code analysis (analyse → verify → document → remove)

**Removed (safe, done in this phase):** the four empty `functions/src` subdirectories (`api`, `middleware`, `utils`, `triggers`) — no code referenced them.

**Verified NOT dead — retained intentionally:**
- `subscriptionTier` / `subscriptionExpiry` are **live**: they drive the client PRO/free UI in `trades_screen`, `profile_screen`, `home_screen`, `bids_screen`, `auth_provider`, and the `models.dart` model. With billing disabled everyone is `free`, so these paths render upgrade prompts / gate PRO features. **Do not remove** — this is the subscription-ready UI.

**Orphaned but needs `build_runner` (documented, not removed here):**
- `stripeCustomerId` (`models.dart:40`, `@Default('') String stripeCustomerId`) is a leftover Stripe field with no live reads/writes. Removing a Freezed model field requires regenerating `*.freezed.dart` / `*.g.dart`, which needs `flutter pub run build_runner build --delete-conflicting-outputs` — can't run in this sandbox. **To remove locally:** delete the field + the `auth_provider` write if any, then run build_runner.

**Offline caching claim (Hive):** `_registerHiveAdapters` is empty / adapters commented out, so advertised offline caching isn't wired. Decide: (a) implement the adapters and register them, or (b) drop the offline-caching claim from docs/UX. Not removed blind (multi-file Dart + generated adapters).

---

## T7 — Architecture, deployment & operations

**System shape.** Flutter app → Firebase (Auth custom-claims RBAC, Firestore, ~17 Cloud Functions in `functions/src/index.ts` + `admin_setup.ts`) → Python FastAPI services (`python_services/`, 16 engines) on Cloud Run. A single-file HTML admin panel manages users/knowledge/subscription config.

**Trust boundaries (post Phase 0/1).**
- Client → Python: Firebase Bearer token; Python verifies the token, enforces `accountStatus == approved`, and pins user identity to the token (`resolve_user_id`).
- Function → Python: `X-Internal-Service-Token` (fail-closed; the service refuses to boot without it).
- Client → Firestore: owner-scoped rules (users can only touch their own `bids`/`likes`/`saves`/`ratings`/`tradeContacts`/counters).

**Required configuration (server).** `INTERNAL_SERVICE_TOKEN` (required, fail-closed), `ANTHROPIC_API_KEY`, `ALLOWED_ORIGINS` (comma-separated; empty blocks all cross-origin), `ENV` (`development` exposes `/docs` + `/openapi.json`), `AI_DAILY_FREE_LIMIT` (default 50), `SUBSCRIPTIONS_ENABLED=false`, `LOG_LEVEL`. See `.env.example`.

**Deployment order (matters).**
1. Deploy Firestore rules to **staging**, run the emulator/rules tests.
2. Deploy Cloud Functions (`firebase deploy --only functions`) — verify `tsc --noEmit` + eslint pass in CI first.
3. Deploy the Python service to Cloud Run with all env vars set (it will refuse to start without `INTERNAL_SERVICE_TOKEN`).
4. Release the Flutter app (after `flutter analyze` + `flutter test`).
Keep the app and backend backward-compatible across a release so either can roll back independently.

**Observability (T6).** Structured JSON logs with `request_id` and secret redaction are available via `utils/logging_config.setup_logging()` (wired into service startup). Add Cloud Monitoring dashboards + alert policies for Cloud Run error rate / latency and Cloud Functions failures. **PDPL:** never log names, crew ids, schedules, or salary — redaction is a backstop for secrets, not a licence to log PII.

**Naming.** Internally the project is `crew_intelligence_platform` / CIP; the product is **Najm**. Align README/labels for maintainers; do **not** rename identifiers/collections (stability risk) — documentation-level only.
