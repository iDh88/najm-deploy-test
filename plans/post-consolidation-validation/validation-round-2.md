# Post-Consolidation Validation — Round 2

Continuation of `initial-validation.log`. That baseline was captured at the
start of a prior session on this branch (`fix/post-consolidation-validation`)
*before* the uncommitted fixes already in the working tree were made, and its
Python section never actually ran (`No module named pytest` — system Python,
not the venv). This round re-validates against the current working tree and
finishes the Python/Firebase gaps.

## Flutter — re-confirmed (no changes made this round)

The working tree already contained (from the prior session) fixes for both
previously-known Flutter failures plus a batch of `as Type?` cast tightenings
across ~20 model/service files. Re-ran to confirm they hold:

| Check | Result |
|---|---|
| `flutter analyze` | **0 errors** (was 1: `test/widget_test.dart` referenced non-existent `MyApp`), 1996 info/warning issues (pre-existing lint debt, down from 2379) |
| `flutter test` | **61 passed, 0 failed** (was 59 passed, 2 failed — `widget_test.dart` compile error + `roster_sync_test.dart` IcsFeedConnector) |

No further action needed. Repo-wide `dart format` drift is untouched/unfixed
(pre-existing, cosmetic, not a blocker).

## Python backend

Baseline (from the original consolidation `final-report.md`): 741 pass / 21
fail / 1 skip, with the 21 failures attributed to hardened service-auth
requirements merged from SOURCE without matching test updates.

Running via the venv (`python_services/.venv`) with `python -m pytest -q`
(plain `pytest` fails to resolve first-party packages — no rootdir/path
config, must invoke as `python -m pytest` from `python_services/`):

1. **Before this round's fixes**: 6 failed, 756 passed, 1 skipped — the prior
   session's uncommitted work (`test_api.py`, `test_roster_sync_api.py`,
   `roster_sync/{router,schema,providers}.py`) had already closed 15 of the
   21 known failures. Remaining 6 were all in `test_trade_search_api.py`,
   401ing because that file never got the `X-Service-Token` header the
   hardened `/v1/trade` router now requires (`verify_service_or_user`).
2. Fixed: added the same `SERVICE_HEADERS` / autouse-token fixture pattern
   already used in `test_api.py` to `test_trade_search_api.py`.
3. Re-ran: 5 of those 6 fixed; one remained —
   `test_record_event_accepted` → `AttributeError: 'TradeEventService'
   object has no attribute 'record_event_raw'`. This is a **real backend
   bug**, not a test issue: `trade_engine/router.py`'s `/events` endpoint
   calls `_events.record_event_raw(...)`, a method that was never defined on
   `TradeEventService` (only the specific `on_trade_{viewed,accepted,...}`
   wrappers exist).
4. Fixed: added `TradeEventService.record_event_raw()`, forwarding straight
   to `ProfileService.record_event()` — the same thing the existing
   `on_trade_*` wrappers do, just without pre-binding the outcome (the
   endpoint already validates `req.outcome` against `TradeOutcome` before
   calling in).

**Result: 762 passed, 1 skipped, 0 failed.** `ruff` remains unavailable (not
installed in the venv or system, and not installed here to avoid an
unrequested dependency change) — same environment gap noted in the original
report.

## Firebase

### Functions (`firebase/functions`)
`npm test` (tsc build + `node --test`): **13/13 pass**, unchanged from
baseline. `npm run lint` still has no ESLint config (pre-existing gap,
untouched).

### Firestore/Storage rules (`firebase/test`)
Needed `JAVA_HOME` pointed at the installed Temurin 21
(`/Library/Java/JavaVirtualMachines/temurin-21.jdk`) since system default
`java` is 17 and firebase-tools rejects it for the emulators.

1. **Before this round's fixes**: 12/15 pass — reproduced the documented
   baseline exactly (`rosterSources` owner-read ×2, `syncEvents` isolation).
2. Root-caused: the three failing tests in `rules.spec.mjs` called helpers
   that don't exist in the file (`withAdmin`, `authedDb`) and used the
   Firestore v8 namespaced chain API (`.doc().set()`) instead of the modular
   API (`doc()`, `setDoc()`, ...) every other test in the file uses. Rewrote
   them to use the file's real helpers (`seed()`, `db()`) and modular calls.
3. Re-ran: 14/15 — one new, more serious finding surfaced once the test
   itself was correct: `Function not found error: Name: [isSignedIn]`.
4. Root-caused: **`firebase/firestore.rules` calls `isSignedIn()` in three
   places** (`rosterSources`, `rosterVersions`, `autoBidRefresh` read rules)
   but only `isAuthenticated()` is defined — `isSignedIn` doesn't exist
   anywhere in the file. Rules referencing an undefined function fail to
   *compile*, so `firebase deploy --only firestore:rules` would have
   rejected this file outright — a real production blocker, not a cosmetic
   test gap. Fixed all three call sites to `isAuthenticated()`.

**Result: 15/15 pass.**

## Files touched this round

- `python_services/behavioral_learning/trade_event_service.py` — added
  missing `record_event_raw` method (real bug fix).
- `python_services/tests/integration/test_trade_search_api.py` — service-auth
  headers (test-only, matches existing `test_api.py` pattern).
- `firebase/firestore.rules` — `isSignedIn()` → `isAuthenticated()` ×3 (real
  bug fix; rules were undeployable as written).
- `firebase/test/rules.spec.mjs` — fixed three tests using undefined helpers
  and the wrong Firestore SDK API style.

Everything above is uncommitted on `fix/post-consolidation-validation`, per
instructions (no commits made).

## Remaining known gaps (pre-existing, not addressed this round)

- Flutter: repo-wide `dart format` drift; 1996 analyzer info/warning issues
  (lint debt, no errors).
- Python: `ruff` not installed in the venv/system.
- Firebase functions: no ESLint config for `npm run lint`.
- `firebase/functions/package-lock.json` is now untracked/new in the working
  tree — a side effect of running `npm install` during this validation
  (`firebase/test/package-lock.json` already existed and was unaffected).
  Left as-is; not committed.
- Not covered this round (out of scope per task instructions): admin_panel,
  Playwright E2E, Vercel deploy path.
