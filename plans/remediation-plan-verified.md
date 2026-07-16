# Najm / CIP — Remediation Plan (VERIFIED)

**Original author:** attributed to "Najm Improve Framework (review pass)"
**Verification pass:** Claude Opus 4.8, cross-checked against the actual `najm_complete` source tree (239 files) on 2026-07-07
**Status of code:** nothing changed. This is a plan only. Code changes happen on an explicit `/execute-plan`.

---

## Verification summary (read this first)

I did not take the uploaded plan on trust. I re-checked each Phase 0 claim against the source. Verdict: **the plan is overwhelmingly accurate and its severity ordering is sound.** Two items were *understated in the unsafe direction* and are corrected below.

| Item | Claim | Verified? | Note |
|---|---|---|---|
| 0.1 | Most Python routers unauthenticated; token fails open | ✅ + **worse** | Only `subscription_engine` has router-level auth (3 refs). **`knowledge_engine` and `layover`, which the plan lists as protected, have ZERO** router-level auth. No router mounted with `dependencies=[...]`. 4 routers trust a client-supplied `user_id`. |
| 0.2 | Stripe webhook `setCustomUserClaims({tier})` wipes claims | ✅ | Confirmed. Rules depend on `accountStatus`/`rank`/`admin`/`superAdmin`/`privileges` — all destroyed by the replace. |
| 0.3 | Three subscription generations coexist | ✅ | New FREE/PRO gate + legacy `free/pro/elite/enterprise` in `index.ts` + HyperPay stub + `stripe_flutter` in pubspec + `require_tier()` self-marked "SUPERSEDED". |
| 0.4 | 2 Flutter services hardcode `localhost:8080` | ✅ + **broader** | **5 files** contain `localhost:8080`, not 2. Add `knowledge_center_service.dart`, `subscription_service.dart`, `trade_search_screen.dart` to the named `rest_legality_service.dart` and `trade_recommendation_service.dart`. |
| 0.5 | `auth_provider.dart` compile error (`rank.name` out of scope) | ✅ | Confirmed independently in the first pass. |
| 0.6 | 4 functions defined twice (`index.ts` + `triggers.ts`) | ✅ | Confirmed via export grep. `triggers.ts` is not imported → dead, but a deploy risk. |
| 1.1 | Arabic translated but forced to English, no RTL | ✅ | `supportedLocales: [Locale('en')]`, forced resolution callback, `localeProvider` TODO. `app_ar.arb` fully populated. |
| 1.3 | `tradeContacts` / likes / saves / ratings rules wide open | ✅ | `allow read, write: if isApproved()` with no owner scoping on all four. |
| 1.4 | Flutter `test/` dirs empty despite README "60+ tests" | ✅ | Both empty. Python tests are real. |

**One open decision the plan correctly refuses to make for you:** Stripe vs. HyperPay vs. RevenueCat (item 0.3). This is a business call, not an engineering one. It must be answered by a human before 0.3 executes.

---

## How to use this document

Ordered work plan, not a code dump. Each item: what's wrong / why it matters / the fix / files touched. Do them in phase order — Phase 0 makes the app unsafe or unshippable *today*. Do **not** batch-apply; each numbered item is one reviewable change with its own test. After each item, confirm it compiles / rules still pass the emulator before moving on. Several interact (subscription tiers, custom claims, auth). Order matters.

---

## Scores (1–10)

| Dimension | Score | Reason |
|---|---|---|
| Architecture | 8 | Clean modules, good separation; two subscription systems drag it down |
| Security | 3 | Unauthenticated Python surface + claims-wipe + fail-open token |
| Performance | 6 | Fine for launch scale; some N+1 Firestore reads in Cloud Functions |
| AI / Knowledge | 7 | Solid RAG design; no eval harness, hallucination guard is prompt-only |
| Scalability | 6 | Weekly rebuild capped at 500 users; fan-out reads won't hold past ~5k |
| Maintainability | 5 | Duplicate function files + dead legacy code create real confusion |

**Overall: 5.5/10** — well-designed system, small number of severe, concentrated defects. Security + claims items are the difference between "beta today" and "do not ship."

---

## PHASE 0 — Do not ship until these are done

### 0.1 — Authenticate every Python router *(CRITICAL / security)*
**What's wrong.** The Python service holds the entire business surface (legality, rest, fatigue, trade rec, salary, ranking, parsers, AI chat). **Verified breadth: only `subscription_engine/router.py` carries router-level auth. `knowledge_engine` and `layover` — described elsewhere as protected — have none at the router level. No router is mounted with `APIRouter(dependencies=[...])`.** The one cross-service guard, `utils/auth.verify_service_token`, returns `True` when `INTERNAL_SERVICE_TOKEN` is unset — it **fails OPEN**. Combined with `.env.example` shipping `INTERNAL_SERVICE_TOKEN=change-me-in-production`, an unset/typo'd env var silently removes all auth. Four routers (`intelligence`, `subscription_engine`, `trade_engine`, `ai`) also accept a **client-supplied `user_id`** in the body — any caller can act as any user.

**Why it matters.** Roster + salary + identity is exactly what PDPL protects and what `docs/legal.md` promises to protect. An exposed Cloud Run URL (they leak into bundles, logs, traces) reads it all.

**The fix.**
1. `verify_service_token` → **fail closed**: unset token raises 503. Validate presence in `lifespan` startup; refuse to boot without it.
2. Router-level dependency on **every** router. Two tiers: Cloud-Functions-called endpoints (parser, legality, auto-bid, expiry) → `Depends(verify_service_token)`; Flutter-called endpoints (`rest_engine`, `trade_engine`, `ai`, `salary`, `intelligence`, `knowledge` retrieval) → `Depends(verify_firebase_auth)`.
3. Derive `user_id` from the **verified token**, never from the request body.
4. Mount at router level (`APIRouter(dependencies=[...])`) so no endpoint can be forgotten.

**Files:** `utils/auth.py`, `main.py`, every `*/router.py`, `legality/engine.py`, `ai/nlp_router.py`, `ranking/scorer.py`, `salary/calculator.py`, `parser/*.py`, `trade_intel/*.py`.
**Test:** every route returns 401/403 without a token; a valid token's UID overrides any body `user_id`.

### 0.2 — Stop the Stripe webhook from wiping custom claims *(CRITICAL / data integrity)*
**What's wrong.** `stripeWebhook` calls `admin.auth().setCustomUserClaims(userId, { tier })`, which **replaces the entire claims object**, destroying `accountStatus`, `rank`, `admin`/`superAdmin`, `privileges` — every claim the Firestore rules read. Subscribing becomes the trigger that locks a user out of their own rank's lines/trades/bids; on an admin it revokes admin.
**The fix.** Preferred: **remove `setCustomUserClaims` from billing entirely** (see 0.3 — tier belongs in the `userSubscriptions` Firestore doc the feature-gate already reads, not in claims). Claims carry identity/authz only. Audit `admin_setup.ts` claim-setting to confirm it spreads (`{...existing, ...}`) rather than replaces.
**Files:** `functions/src/index.ts`, `functions/src/admin_setup.ts`.
**Test:** after a simulated subscription event, `accountStatus` and `rank` claims are unchanged.

### 0.3 — Collapse three subscription systems into one *(CRITICAL / correctness)*
**What's wrong.** New FREE/PRO feature-gate (Python + Flutter) vs. legacy `free/pro/elite/enterprise` Stripe in `index.ts` (`aiAssistant`, `triggerAutoBidSuggestions` read `subscriptionTier` from the **user doc**) vs. HyperPay stub in `.env`. Two systems compute entitlement from two data sources and will disagree. `require_tier()` is self-documented dead code.
**The fix.** New engine = single source of truth. (1) Rewrite `aiAssistant` + `triggerAutoBidSuggestions` to call the feature-gate; AI daily limit from `usageLimits` config, not hardcoded `50 : 99999`. (2) Delete legacy `stripeWebhook` or reduce to a thin adapter writing `userSubscriptions` in the new shape. (3) **DECISION REQUIRED (human):** Stripe vs HyperPay vs RevenueCat. Models are RevenueCat-shaped + app is mobile-first → RevenueCat is the likely intended path, but **confirm before removing `stripe_flutter` / HyperPay env**. (4) Delete `require_tier()`.
**Files:** `functions/src/index.ts`, `pubspec.yaml`, `utils/auth.py`, `.env.example`.
**⛔ Blocked on the payment-provider decision above.**

### 0.4 — Fix hardcoded `localhost` service URLs *(CRITICAL / ship-blocker)*
**What's wrong.** **Verified: 5 files** hardcode `http://localhost:8080` (not 2): `rest_legality_service.dart`, `trade_recommendation_service.dart`, `knowledge_center_service.dart`, `subscription_service.dart`, `trade_search_screen.dart`. `constants.dart` already has the right pattern (`String.fromEnvironment('AI_SERVICE_URL', ...)`). Core features call `localhost` on-device and fail.
**The fix.** Route all five through `ApiConstants.aiServiceUrl`. Grep for any remaining `localhost`/`127.0.0.1`/`run.app` literals and centralize. Production URL via `--dart-define`, never source.
**Files:** the 5 files above + `constants.dart`.

### 0.5 — Fix the `auth_provider.dart` compile error *(CRITICAL / ship-blocker)*
**What's wrong.** `_userToFirestore(CIPUser user)` references `rank.name` — `rank` is a `signUp` parameter, not in scope here. Won't compile. Same map hardcodes `'accountStatus': 'pending'`, so reusing this helper to *update* would silently reset a user to pending.
**The fix.** `user.rank.name`. Keep the helper create-only or parameterize `accountStatus`.
**Files:** `flutter_app/lib/core/auth/auth_provider.dart`.

### 0.6 — Resolve duplicate Cloud Function definitions *(CRITICAL / deploy)*
**What's wrong.** `onBidCreated`, `checkLegality`, `stripeWebhook`, `processAccountDeletion` are each defined in **both** `index.ts` and `triggers.ts`. `triggers.ts` is not imported (dead), but risks duplicate-export deploy failures and ambiguity over which is authoritative.
**The fix.** Confirm `triggers.ts` unused (it is), port any newer delta from it first, then delete. One definition per function.
**Files:** delete `functions/src/triggers.ts`; verify `index.ts`.

---

## PHASE 1 — High priority (before public launch)

**1.1 — Arabic / RTL.** Add `Locale('ar')` to `supportedLocales`, remove forced-English callback, wire `localeProvider` to Hive, RTL pass on core screens. (Arguably Phase 0 for *this* audience; placed here only because it doesn't corrupt data.) — `app.dart` + screens.

**1.2 — Complete deletion pipeline (PDPL).** `processAccountDeletion` misses `behaviorEvents`, `userSubscriptions`, `usageCounters`, `subscriptionEvents`, `userReferralStatus`, `tradeContacts`, `userLikes`/`Saves`/`Ratings`, `uploads`, `monthly_lines`, `fcmTokens`, and Storage roster files. Single `batch` (500-op cap, no chunking); Auth user deleted before batch confirmed. Fix: source-of-truth per-user collection list, chunked batches (≤400), Storage prefix delete, Auth-user last, resumable `deletionStatus`. — `index.ts`.

**1.3 — Tighten fail-open gate + wide rules.** `feature_gate.py` grants any *unconfigured* key (typo → free PRO); gate that branch behind `subscriptions_enabled == false` + alert. Scope `tradeContacts` to `docId.matches(request.auth.uid + '_.*')` (pattern already used for `usageCounters`); add owner checks to likes/saves/ratings. — `firestore.rules`, `feature_gate.py`.

**1.4 — Real test suite.** Flutter `test/` empty. Prioritize legality/rest (safety), feature-gate (billing), and the 0.1 auth deps. Model on the existing Python tests. — `flutter_app/test/**`, expand `python_services/tests/**`.

**1.5 — CI pipeline.** README references `.github/workflows/deploy.yml`; absent. Minimal: `flutter analyze`/`test`, `pytest`, `tsc --noEmit`+`eslint`, firestore-rules emulator tests; block deploy on failure. — `.github/workflows/`.

---

## PHASE 2 — Medium
- **2.1** Missing declared assets (`assets/icons/`, 4 `Inter-*.ttf`) — add or remove declarations (runtime asset-not-found otherwise).
- **2.2** N+1 token lookups in `onChangeSummaryGenerated` — batch.
- **2.3** `weeklyProfileRebuild` `.limit(500)` + sequential await — paginate + bounded-parallel or task queue.
- **2.4** AI hallucination guard is prompt-only — cite-or-refuse, confidence threshold, "not in KB" path, eval set.
- **2.5** If Stripe kept: confirm `req.rawBody` availability + webhook idempotency.
- **2.6** `ALLOWED_ORIGINS.split(",")` yields `['']` when unset — validate/default.

## PHASE 3 — Low / polish
- **3.1** Gate `/openapi.json` off in prod (like `docs_url`).
- **3.2** Two `behaviorEvents` rule blocks use `userId` vs `user_id` — unify (one silently never matches).
- **3.3** `_registerHiveAdapters` empty (adapters commented) — confirm caching works or drop the claim.
- **3.4** Super-admin email + `ADMIN_SETUP_TOKEN` in `.env.example` — never commit real values; rotate token post-bootstrap.
- **3.5** `crew_intelligence_platform`/CIP vs product name Najm — align for maintainer sanity.

---

## Execution order
```
Phase 0 (exact order — they interact):
  0.5 compile fix        → app builds
  0.6 dedupe functions   → functions deployable
  0.1 auth all routers   → close data-exposure hole
  0.2 claims-wipe fix    → stop lockout-on-payment
  0.3 one subscription   → BLOCKED on payment-provider decision (human)
  0.4 service URLs (x5)  → core features reachable on device
Phase 1: 1.1 → 1.3 → 1.2 → 1.4 → 1.5   Then Phase 2, Phase 3.
```

**Throughout:** never "fix" a finding by silently making an assumption true. Ambiguous items (0.3) surface the decision. One change, one test, one review.

## What was NOT changed
Nothing. Review artifact only. Code changes happen on explicit `/execute-plan`.
