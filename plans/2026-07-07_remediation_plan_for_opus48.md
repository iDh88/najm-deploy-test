# Najm / CIP — Remediation Plan for Opus 4.8

**Prepared by:** Najm Improve Framework (review pass, no code changed)
**Date:** 2026-07-07
**Audience:** Claude Opus 4.8, executing fixes
**Scope reviewed:** 239 files — Flutter app, Firebase (rules + ~27 Cloud Functions), Python FastAPI services (16 engines), admin panel, docs

---

## How to use this document

This is an ordered work plan, not a code dump. Each item has: **what's wrong**, **why it matters**, **the fix**, and **files touched**. Do them in phase order — Phase 0 items are the ones that make the app unsafe or unshippable *today*. Do **not** batch-apply; each numbered item should be one reviewable change with its own test.

**Rule for the executor:** after each item, stop and confirm the change compiles / rules still pass the emulator before moving on. Several of these interact (subscription tiers, custom claims, auth). Order matters.

---

## Executive summary

The architecture is genuinely strong — clean feature-module separation, a properly abstracted feature-gate, RevenueCat-shaped subscription models, versioned RAG knowledge engine, PDPL-aware deletion flow. The problems are not architectural. They fall into four buckets:

1. **One critical security hole**: 12 of 14 Python routers have no authentication, and the one shared-secret guard fails *open*. Crew roster data is effectively public if the Cloud Run URL leaks.
2. **One critical data-integrity bug**: the Stripe webhook overwrites Firebase custom claims, which would wipe `accountStatus`/`rank`/`admin` — locking paying users out of the whole app.
3. **Three overlapping subscription generations** left in the tree (new FREE/PRO feature-gate; legacy `free/pro/elite/enterprise` Stripe tiers; a HyperPay stub). They contradict each other.
4. **Ship-blockers**: hardcoded `localhost` service URLs, empty test dirs, a compile error, missing declared assets, forced-English locale on an Arabic-first product.

Scores (1–10):

| Dimension | Score | One-line reason |
|---|---|---|
| Architecture | 8 | Clean modules, good separation; two subscription systems drag it down |
| Security | 3 | Unauthenticated Python surface + claims-wipe + fail-open token |
| Performance | 6 | Fine for launch scale; some N+1 Firestore reads in Cloud Functions |
| AI / Knowledge | 7 | Solid RAG design; no eval harness, hallucination guard is prompt-only |
| Scalability | 6 | Weekly rebuild capped at 500 users; fan-out reads won't hold past ~5k |
| Maintainability | 5 | Duplicate function files + dead legacy code create real confusion |

**Overall: 5.5/10** — a well-designed system with a small number of severe, concentrated defects. None are hard to fix. The security and claims items are the difference between "beta today" and "do not ship."

---

## PHASE 0 — Do not ship until these are done

### 0.1 — Authenticate every Python router *(CRITICAL / security)*

**What's wrong.** The Python service holds the entire business surface: legality, rest, fatigue, trade recommendation, salary, ranking, parsers, AI chat. A grep for any auth dependency:

```
rest_engine/router.py       0
trade_engine/router.py      0
intelligence/router.py      0
ai/nlp_router.py            0
legality/engine.py          0
parser/*.py                 0   (all three)
ranking/scorer.py           0
salary/calculator.py        0
trade_intel/*.py            0
```

Only `knowledge_engine` and `layover` check a token, and only on some routes. The one cross-service guard, `utils/auth.verify_service_token`, does this:

```python
expected = os.getenv("INTERNAL_SERVICE_TOKEN")
if not expected:
    logger.warning("... skipping service auth")
    return True     # <-- fails OPEN
```

So if the env var is ever unset (misconfig, new environment, typo), **all auth silently disappears** and only a warning is logged. Combined with `.env.example` shipping `INTERNAL_SERVICE_TOKEN=change-me-in-production`, this is a real path to a fully open service holding Saudi crew roster data (names, crew IDs, full schedules, salary).

**Why it matters.** This is the single most important fix in the document. Roster + salary + identity is exactly the data PDPL protects, and the app's own `docs/legal.md` promises to protect it. An exposed Cloud Run URL — which ends up in client bundles, logs, and error traces — is enough to read it all.

**The fix.**
1. Change `verify_service_token` to **fail closed**: if `INTERNAL_SERVICE_TOKEN` is unset, raise 503, never return `True`. Refuse to start the app without it (validate in the `lifespan` startup).
2. Add a shared dependency to **every** router. Two tiers:
   - Endpoints called by Cloud Functions (parser, legality, auto-bid, expiry job) → `Depends(verify_service_token)`.
   - Endpoints called directly by Flutter (`rest_engine`, `trade_engine`, `ai`, `salary`, `intelligence`, `knowledge` retrieval) → `Depends(verify_firebase_auth)`, and derive `user_id` from the verified token **instead of trusting the `user_id` in the request body** (right now `ChatRequest.user_id` etc. are client-supplied and unverified — any user can pass another user's ID).
3. Mount the dependency at the router level (`APIRouter(dependencies=[...])`) so no individual endpoint can be forgotten.

**Files:** `python_services/utils/auth.py`, `python_services/main.py`, and every `*/router.py` + `legality/engine.py`, `ai/nlp_router.py`, `ranking/scorer.py`, `salary/calculator.py`, `parser/*.py`, `trade_intel/*.py`.

**Test:** integration test asserting every route returns 401/403 without a token, and that a valid Firebase token's UID overrides any body-supplied `user_id`.

---

### 0.2 — Stop the Stripe webhook from wiping custom claims *(CRITICAL / data integrity)*

**What's wrong.** In `firebase/functions/src/index.ts`, `stripeWebhook` does:

```ts
await admin.auth().setCustomUserClaims(userId, { tier });
```

`setCustomUserClaims` **replaces the entire claims object**. Every Firestore rule in the app depends on claims that this call destroys:

- `isApproved()` reads `accountStatus == 'approved'`
- `isSameRank()` reads `rank` — gates all flightLines/trades/bids
- `isAdmin()` / `isSuperAdmin()` read `admin` / `superAdmin`
- `hasPrivilege()` reads `privileges`

So the moment a user subscribes (or Stripe sends any `customer.subscription.updated`), their `accountStatus`, `rank`, and any admin rights vanish. They can no longer read their own rank's lines, trades, or bids. **Paying is the trigger that locks them out.**

**Why it matters.** This turns your best-case event (a user pays) into a full account lockout, and it's silent until the user complains. If it hits an admin, it revokes admin access.

**The fix.**
1. Read existing claims first, spread them, then set: `setCustomUserClaims(userId, { ...existing, tier })`. **But** — see 0.3: `tier` should not live in claims at all under the new model. Preferred fix is to **remove the `setCustomUserClaims` call entirely** and let entitlement come from the Firestore `userSubscriptions` doc the feature-gate already reads. Claims should carry only identity/authz (`accountStatus`, `rank`, `admin`, `superAdmin`, `privileges`), never billing state.
2. Audit every other `setCustomUserClaims` call for the same overwrite bug. `admin_setup.ts` sets claims on approve/admin-grant — confirm those spread rather than replace.

**Files:** `firebase/functions/src/index.ts`, `firebase/functions/src/admin_setup.ts`.

**Test:** unit test that after a simulated subscription event, a user's `accountStatus` and `rank` claims are unchanged.

---

### 0.3 — Collapse three subscription systems into one *(CRITICAL / correctness)*

**What's wrong.** There are three incompatible billing generations in the tree simultaneously:

| Generation | Where | Tiers |
|---|---|---|
| **New (intended)** | `python_services/subscription_engine/*`, Flutter `features/subscription/*` | `FREE`, `PRO` — Firestore-config-driven feature gate |
| **Legacy Stripe** | `functions/src/index.ts` (`stripeWebhook`, `aiAssistant`, `triggerAutoBidSuggestions`) | `free`, `pro`, `elite`, `enterprise` |
| **HyperPay stub** | `.env.example` | access token + entity ID, no code |

The Cloud Functions still gate AI usage and auto-bid on `subscriptionTier in ['pro','elite','enterprise']` read from the **user doc**, while the actual product model is FREE/PRO computed by the **feature-gate from `userSubscriptions`**. `pubspec.yaml` also pulls in `stripe_flutter`, implying client-side Stripe that the new server-side model doesn't use. And `utils/auth.py` even documents its own dead code: `require_tier()` is marked *"SUPERSEDED... not called anywhere."*

**Why it matters.** Two systems computing entitlement from two different data sources will disagree. A user could be PRO in the feature-gate and `free` in the user doc, getting AI access from one path and denied by the other. It's also impossible to reason about "who can use what."

**The fix.** Pick the new engine as the single source of truth (it's the better design — admin-configurable, RevenueCat-shaped, has trials/referrals/usage limits). Then:
1. Rewrite `aiAssistant` and `triggerAutoBidSuggestions` in `index.ts` to call the feature-gate (`/v1/subscription/...`) instead of reading `subscriptionTier` from the user doc. AI daily limit should come from `usageLimits` config, not the hardcoded `tier === "free" ? 50 : 99999`.
2. Delete the legacy `stripeWebhook` (or reduce it to a thin adapter that writes into `userSubscriptions` in the new shape — this is exactly what the models docstring says a future RevenueCat webhook should do).
3. Decide Stripe vs. HyperPay vs. RevenueCat and remove the other two. Given `subscription_engine/models.py` is explicitly built to map onto RevenueCat and the app is mobile-first (App Store / Play Store), **RevenueCat is the intended path** — remove `stripe_flutter` from pubspec and the HyperPay env vars unless there's a web-payment reason to keep Stripe.
4. Delete `require_tier()` from `utils/auth.py`.

**Files:** `functions/src/index.ts`, `flutter_app/pubspec.yaml`, `python_services/utils/auth.py`, `.env.example`.

---

### 0.4 — Fix hardcoded `localhost` service URLs *(CRITICAL / ship-blocker)*

**What's wrong.** Two Flutter services hardcode the dev URL:

```dart
// rest_legality_service.dart AND trade_recommendation_service.dart
final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
```

Meanwhile `constants.dart` has the right pattern (`String.fromEnvironment('AI_SERVICE_URL', ...)`). So Rest, Legality, and Trade Recommendation — three core features — will call `localhost` on a real device and fail entirely.

**The fix.** Route both through the same `ApiConstants.aiServiceUrl` from `constants.dart`. Grep for any other `localhost`/`127.0.0.1`/`run.app` literals and centralize them. Set the production URL via `--dart-define` in the build, never in source.

**Files:** `rest_legality_service.dart`, `trade_recommendation_service.dart`, `constants.dart`.

---

### 0.5 — Fix the `auth_provider.dart` compile error *(CRITICAL / ship-blocker)*

**What's wrong.** In `_userToFirestore(CIPUser user)`:

```dart
'rankCode': rank.name,   // 'rank' is not in scope — should be user.rank.name
```

`rank` is a parameter of `signUp`, not of this helper. This won't compile. Also note the same map hardcodes `'accountStatus': 'pending'`, so any code path that reuses this helper to *update* a user would silently reset them to pending — keep this helper create-only or parameterize the status.

**The fix.** `user.rank.name`. Audit the helper's two responsibilities (create vs. serialize) and split if needed.

**Files:** `flutter_app/lib/core/auth/auth_provider.dart`.

---

### 0.6 — Resolve duplicate Cloud Function definitions *(CRITICAL / deploy)*

**What's wrong.** `onBidCreated`, `checkLegality`, `stripeWebhook`, and `processAccountDeletion` are each **defined twice** — once in `index.ts` and once in `triggers.ts`. `index.ts` doesn't import `triggers.ts` and `admin_setup.ts` is the only re-exported module, so `triggers.ts` appears to be **dead legacy code** — but if the build ever picks it up, you get duplicate-export deploy failures, and right now nobody can tell which `checkLegality` is authoritative.

**The fix.** Confirm `triggers.ts` is unused (it is, per the import graph), then delete it. If any function in it is *newer* than its `index.ts` twin, port the delta first. One definition per function, all in `index.ts` (or split cleanly with explicit imports).

**Files:** `firebase/functions/src/triggers.ts` (delete), `index.ts` (verify).

---

## PHASE 1 — High priority (before public launch)

### 1.1 — Turn on Arabic / RTL *(high / UX, product-critical)*

**What's wrong.** This is a Saudi Airlines cabin-crew product. `app_ar.arb` exists (222 lines, fully translated), push notifications are sent in Arabic by default (`locale === "ar"`), the admin panel styles for it — but `app.dart` hard-forces English:

```dart
supportedLocales: const [ Locale('en') ],
localeResolutionCallback: (locale, supportedLocales) => const Locale('en'),
```

and `localeProvider` has a `// TODO: Load from Hive` that always returns English. So the Arabic translation ships but is unreachable, and there's no RTL.

**The fix.** Add `Locale('ar')` to `supportedLocales`, remove the forced-English resolution callback, wire `localeProvider` to the Hive settings box, and verify RTL layout (directionality, icon mirroring) on the core screens. This is arguably a Phase 0 item for *this specific audience* — I've put it at 1.1 only because it doesn't corrupt data.

**Files:** `flutter_app/lib/app/app.dart`, and an RTL pass over the main screens.

---

### 1.2 — Complete the account-deletion pipeline *(high / PDPL compliance)*

**What's wrong.** `processAccountDeletion` deletes `users`, `bids`, `trades`, `notifications`, `aiSessions` — but the app has grown many more per-user collections that it misses: `behaviorEvents`, `userSubscriptions`, `usageCounters`, `subscriptionEvents`, `userReferralStatus`, `tradeContacts`, `userLikes`/`userSaves`/`userRatings`, `uploads`, `monthly_lines`, `fcmTokens`, plus Storage roster files under `users/{uid}/rosters/`. Also: it uses a single `batch` (500-op limit) with no chunking, and it deletes the Firebase Auth user *after* the Firestore batch with no rollback if the batch fails.

**Why it matters.** `docs/legal.md` and the PDPL promise full erasure. Leaving behavioral events, roster PDFs, and subscription history behind is a compliance gap on the exact data category that's most sensitive.

**The fix.** Enumerate every per-user collection (a single source-of-truth list), delete in chunked batches (≤ 400 ops each), delete Storage objects under the user's prefix, and only delete the Auth user last after confirming data deletion succeeded. Consider a `deletionStatus` state machine so a partial failure is resumable.

**Files:** `firebase/functions/src/index.ts` (`processAccountDeletion`).

---

### 1.3 — Tighten fail-open feature-gate and wide Firestore rules *(high / security)*

**What's wrong.** Two smaller versions of the Phase-0 theme:

- `feature_gate.py` returns `allowed=True` for any **unconfigured** feature key ("fail open"). That's a reasonable launch choice, but it means a typo in a feature key silently grants PRO features to everyone. At minimum log-and-alert; better, fail open only while `subscriptions_enabled == false`.
- Several Firestore rules are wide: `tradeContacts/{docId}` is `read, write: if isApproved()` — **any approved user can read/write any trade contact record**, including others' PRN/phone data. `userLikes`/`userSaves`/`userRatings` are similarly `read, write: if isApproved()` with no owner scoping, so one user can overwrite another's saves.

**The fix.** Scope `tradeContacts` to the owning user (doc ID already encodes `{userId}_...` — enforce it in the rule via `docId.matches(request.auth.uid + '_.*')`, the same pattern already used correctly for `usageCounters`). Add owner checks to the like/save/rating collections. For the feature-gate, gate the fail-open branch behind the master switch.

**Files:** `firebase/firestore.rules`, `python_services/subscription_engine/feature_gate.py`.

---

### 1.4 — Add a real test suite *(high / quality)*

**What's wrong.** README claims "60+ unit tests" and `test/unit`, `test/widget` exist — but both Flutter test dirs are **empty**. The Python side does have real tests (`test_legality.py`, `test_subscription_engine.py`, `test_parser_ranking.py`, integration `test_api.py`) — those are good and should be the model.

**The fix.** Prioritize tests for the code that computes safety- and money-relevant outputs: legality/rest calculations (regulatory correctness), feature-gate decisions (billing correctness), and the auth dependencies from 0.1. Wire them into CI (see 1.5). Don't chase coverage numbers — chase the engines where a wrong answer misleads a crew member about legal rest or overcharges them.

**Files:** `flutter_app/test/**`, expand `python_services/tests/**`.

---

### 1.5 — Add the missing CI pipeline *(high / ops)*

**What's wrong.** README references `.github/workflows/deploy.yml`; it's not in the archive. There's no automated lint/test/deploy gate, so all six Phase-0 bugs could have shipped unnoticed.

**The fix.** A minimal pipeline: `flutter analyze` + `flutter test`; `pytest` for Python; `tsc --noEmit` + `eslint` for functions; firestore-rules unit tests via the emulator; block deploy on any failure. This is the safety net that keeps the rest of this plan from regressing.

**Files:** `.github/workflows/` (new).

---

## PHASE 2 — Medium priority

- **2.1 Missing declared assets** — `pubspec.yaml` declares `assets/icons/` and four `Inter-*.ttf` fonts, but `assets/images/` is empty and no fonts/icons dir exists. App will throw asset-not-found at runtime. Add the files or remove the declarations.
- **2.2 N+1 reads in notification fan-out** — `onChangeSummaryGenerated` loops admins and does one `fcmTokens` query per admin sequentially. Fine at 5 admins, not at 50. Batch the token lookups.
- **2.3 Weekly rebuild caps at 500 users** — `weeklyProfileRebuild` has `.limit(500)` and rebuilds sequentially with an `await` per user. Past 500 active crew, some profiles never rebuild. Paginate and parallelize (bounded), or move to a task queue.
- **2.4 AI hallucination guard is prompt-only** — the knowledge assistant relies on the system prompt to avoid inventing regulatory facts. For an app where a wrong FTL answer has safety weight, add retrieval-grounding checks (cite-or-refuse, confidence threshold, "not in knowledge base" path) and an eval set.
- **2.5 `stripe-signature` / rawBody** — if Stripe is kept at all (see 0.3), confirm `req.rawBody` is available in the Functions runtime; verify webhook idempotency (Stripe retries).
- **2.6 CORS `allow_origins` from env split** — `os.getenv("ALLOWED_ORIGINS","").split(",")` yields `['']` when unset, which is a subtle misconfig. Validate and default safely.

---

## PHASE 3 — Low priority / polish

- **3.1** `docs_url` gated on `ENV == "development"` — good; also gate `/openapi.json` and confirm it's off in prod.
- **3.2** Consolidate the two `behaviorEvents` rule blocks in `firestore.rules` (one uses `userId`, the other `user_id` — pick one field name to avoid a rule that silently never matches).
- **3.3** `main.dart` Hive adapters are all commented out (`_registerHiveAdapters` is empty) — confirm caching actually works or remove the offline-cache claims.
- **3.4** Super-admin email and setup token in `.env.example` (`NajmAssistance@gmail.com`, `ADMIN_SETUP_TOKEN`) — ensure the real values never land in a committed `.env` and rotate the setup token post-bootstrap.
- **3.5** Naming: repo/pubspec use `crew_intelligence_platform` / CIP, product is Najm — harmless but worth aligning for maintainer sanity.

---

## Suggested execution order for Opus 4.8

```
Phase 0 (in this exact order — they interact):
  0.5 compile fix        → makes the app build at all
  0.6 dedupe functions   → makes functions deployable
  0.1 auth all routers   → closes the data-exposure hole
  0.2 claims-wipe fix    → stops lockout-on-payment
  0.3 one subscription   → removes contradictory entitlement (depends on 0.2)
  0.4 service URLs       → makes core features reachable on device

Phase 1: 1.1 Arabic → 1.3 rules/gate → 1.2 deletion → 1.4 tests → 1.5 CI
Phase 2, then Phase 3.
```

**One instruction to carry throughout:** do not "fix" a finding by making the reviewer's assumption true silently — if an item is ambiguous (e.g. Stripe-vs-RevenueCat in 0.3), surface the decision rather than picking for the business. Each item is one change, one test, one review.

---

## What was NOT changed

Nothing. This is a review artifact. No production code, rules, or config was modified. Per the framework's operating rules, code changes happen only on an explicit `/execute-plan`.
