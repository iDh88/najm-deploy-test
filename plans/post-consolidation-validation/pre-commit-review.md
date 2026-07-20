# Pre-Commit Review — fix/post-consolidation-validation

Final review pass before committing. No commit created — this is a report only.

## 1. Git state

`git status`: 36 tracked files modified, 0 deleted, 0 renamed. Two untracked
paths: `plans/post-consolidation-validation/` (this validation's own reports)
and `firebase/functions/package-lock.json` (see §2).

`git diff --stat`: 620 insertions, 576 deletions across 36 files.

`git diff --check`: **clean** — no whitespace/conflict-marker errors.

## 2. Content review

- **Secrets**: none found. Grepped the full diff for key/token/password/AKIA
  patterns; every hit was either the test-only literal
  `"test-service-token"` (mirrors the existing `test_api.py` fixture pattern,
  not a real credential) or a false-positive substring match (`toDouble()`
  contains "toDo"). No `.env`, credentials, or service-account content
  touched.
- **Generated build artifacts**: none staged. `firebase/functions/package-lock.json`
  is untracked (created by `npm install` while re-running the functions
  test suite) — `firebase/test/package-lock.json` is already committed, so
  functions having no lockfile at all looks like a pre-existing gap rather
  than something this branch should paper over. **Left untracked, not
  added** — flagging for you to decide whether to commit it separately.
- **Unrelated files**: none. Every changed file sits in `flutter_app/`,
  `python_services/`, or `firebase/`, matching the stated validation scope.
  Nothing in `admin_panel/`, `vercel_api/`, docs, or CI config was touched.
- **Debug-only code**: none. No `print(`, `console.log`, `debugger;`, or
  stray `TODO`/`FIXME` markers were introduced (checked with word-boundary
  grep over the diff).
- **Weakened tests**: none found; if anything the opposite. Specific checks:
  - `test_api.py`: several `if response.status_code == 200: assert ...`
    soft-checks became unconditional `assert response.status_code == 200`
    followed by the same assertions — strictly stronger, not weaker.
  - Route/field renames in `test_api.py` (`/v1/auto-bid/update-preference` →
    `/v1/auto-bid/update-vector`, `userId` → `user_id` for AI chat,
    `initiatorId/offeredLegId` → `initiator_schedule/offered_duty`) were
    verified against the actual untouched router/engine source
    (`auto_bid/engine.py`, `ai/nlp_router.py`) — the tests were pointing at
    a stale contract, now corrected to match real production code.
  - `test_message_too_long_rejected`: bumped from a 600-char message
    against a "500-char limit" comment to 1100 against 1000 — confirmed
    `ai/nlp_router.py:411` (untouched) enforces exactly 1000; the old test
    was simply wrong.
  - `rules.spec.mjs`: the three previously-failing tests were fixed to use
    the file's actual helpers (`seed()`, `db()`) and the modular Firestore
    SDK API already used everywhere else in the file, replacing calls to
    `withAdmin`/`authedDb`, which don't exist anywhere in the file.
- **Unintentional architecture changes**: none identified.
  - `roster_sync/{router,schema,providers/__init__}.py`: now passes
    `request.user_id` into `resolve_user_id()` instead of a hardcoded `""`.
    Verified `resolve_user_id()` (`utils/auth.py:107`, untouched) only
    trusts the caller-supplied id when `claims["service"]` is true (i.e.
    the request came in via `X-Service-Token`); real end-user Bearer-token
    callers are always pinned to their verified token `uid` regardless of
    what's in the body. No user-impersonation path was opened.
  - `firestore.rules`: `isSignedIn()` → `isAuthenticated()` in 3 places is a
    typo fix restoring a function that already existed and was already
    used everywhere else in the file — not a new access-control policy.
  - `behavioral_learning/trade_event_service.py`: `record_event_raw()` is
    an additive method that forwards to the same `ProfileService.record_event()`
    every other method on the class already calls — same shape as its four
    siblings (`on_trade_viewed/accepted/rejected/expired`), just without a
    pre-bound outcome.

## 3. Final smoke validation (re-run just now)

| Suite | Result |
|---|---|
| `flutter analyze` | 0 errors, 1996 info/warning issues (pre-existing lint debt, unchanged) |
| `flutter test` | **61 passed, 0 failed** |
| `python -m pytest -q` (venv, `INTERNAL_SERVICE_TOKEN=dev-token`) | **762 passed, 1 skipped, 0 failed** |
| Firebase Functions `npm test` | **13 passed, 0 failed** |
| Firestore/Storage rules (`firebase emulators:exec`, JDK 21) | **15 passed, 0 failed** |

All five are stable on a clean re-run (not just the run that produced the fix).

## 4. Changed files by area

**Firebase (2 files)**
- `firebase/firestore.rules` — fixed undefined `isSignedIn()` → `isAuthenticated()` (×3): rules would have failed to deploy as written.
- `firebase/test/rules.spec.mjs` — fixed 3 tests calling nonexistent helpers/wrong SDK API.

**Flutter — models/services, defensive JSON casts (23 files)**
`core/models/filter_models.dart`, `core/roster_sync/sync_models.dart`,
`core/services/{ai_status_service,notification_service,offline_cache_service}.dart`,
`features/admin/knowledge_center/{models/knowledge_models,services/knowledge_center_service}.dart`,
`features/admin/subscription_admin/{screens/promo_campaign_screen,screens/subscription_control_panel_screen,screens/user_subscription_lookup_screen,widgets/feature_access_toggle_grid}.dart`,
`features/intelligence/{models/intelligence_models,providers/intelligence_providers,services/intelligence_service}.dart`,
`features/layover/{models/city,models/recommendation,services/auth_service}.dart`,
`features/profile/salary_calculator_screen.dart`,
`features/rest_legality/{models/rest_models,services/rest_legality_service}.dart`,
`features/subscription/{models/subscription_models,services/subscription_service}.dart`,
`features/trades/{recommendation/models,recommendation/trade_recommendation_service,trade_search_screen}.dart`
— all the same mechanical pattern: `j['x'] ?? default` → `j['x'] as Type? ?? default`, turning a silent-crash-on-malformed-data path into a graceful default.

**Flutter — tests (2 files)**
- `test/unit/roster_sync_test.dart` — ICS fixture gained `DTSTART`/`DTEND`; assertion updated to check the normalized on-device payload instead of the raw calendar (matches the Zero-Knowledge contract).
- `test/widget_test.dart` — replaced the stock counter-app smoke test (referenced a nonexistent `MyApp`) with a real theme-construction smoke test.

**Python — backend (4 files)**
- `roster_sync/router.py`, `roster_sync/schema.py`, `roster_sync/providers/__init__.py` — service-lane callers can now actually pass `user_id` through (was hardcoded to `""`); provider priority-order comment/list corrected.
- `behavioral_learning/trade_event_service.py` — added missing `record_event_raw()` (real `AttributeError` bug fix).

**Python — tests (3 files)**
- `tests/integration/test_api.py` — realigned to the current hardened-auth contract and actual router/engine schema (see §2).
- `tests/integration/test_roster_sync_api.py` — provider-catalog assertion updated to the full expected list.
- `tests/integration/test_trade_search_api.py` — added service-token auth headers to match `verify_service_or_user` on `/v1/trade`.

## 5. Remaining known gaps (not addressed, pre-existing)

- Flutter: repo-wide `dart format` drift; 1996 analyzer info/warnings (no errors).
- Python: `ruff` not installed in `python_services/.venv` (not installed here to avoid an unrequested dependency change).
- Firebase Functions: `npm run lint` has no ESLint config.
- `firebase/functions/package-lock.json` untracked (see §2) — your call.

## 6. Recommended commit message

Given the diff spans three unrelated fix areas, consider splitting into
2–3 commits instead of one:

1. `fix(roster-sync,behavioral-learning): pass service-lane user_id through; add missing record_event_raw`
   — `python_services/roster_sync/*`, `python_services/behavioral_learning/trade_event_service.py`
2. `test(python,flutter): align tests with current auth/engine/router contracts`
   — `python_services/tests/integration/*`, `flutter_app/test/*`, plus the Dart model cast-tightening batch (or split the Dart casts into its own `fix(flutter): guard JSON field casts` commit if you'd rather keep prod and test changes separate)
3. `fix(firebase): repair undefined isSignedIn() rule reference; fix broken rules tests`
   — `firebase/firestore.rules`, `firebase/test/rules.spec.mjs`

If you'd rather have one commit, a single message that covers it:

```
fix: close post-consolidation validation gaps in roster-sync, trade events, and Firestore rules

- roster_sync: pass service-lane user_id through instead of a hardcoded ""
- behavioral_learning: add TradeEventService.record_event_raw (was missing, 500'd)
- firestore.rules: isSignedIn() -> isAuthenticated() (undefined fn, undeployable as written)
- realign python/flutter integration tests and firestore rules tests with current
  router/engine contracts; tighten Dart JSON field casts flagged by flutter analyze

Flutter: 61/61 tests, 0 analyze errors. Python: 762/763 pytest (1 skip), 0 fail.
Firebase: 13/13 functions, 15/15 rules tests.
```
