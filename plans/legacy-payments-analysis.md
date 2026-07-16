# Legacy Payments — Dependency Analysis & Migration Plan

**Required by the payment architecture decision** (analyze → verify → document → migrate → only then remove). This documents the analysis performed before removing Stripe/HyperPay in item 0.3.

## Decision (fixed)
- Launch **FREE**. Subscriptions are built but **DISABLED** (`SUBSCRIPTIONS_ENABLED=false`).
- Future billing: **Apple In-App Purchase** (iOS) + **Google Play Billing** (Android).
- **RevenueCat** = subscription management/sync layer only (entitlements, status, webhooks) — **not** a payment gateway.
- **Stripe** and **HyperPay** are **not** in the roadmap → treated as legacy and removed.

## 1. Dependency analysis — what referenced the legacy systems

| Component | Location | Status | Verified |
|---|---|---|---|
| `stripeWebhook` (HTTP fn) | `functions/src/index.ts` | **Removed** | Was the only live Stripe code |
| `stripeWebhook` + handlers | `functions/src/triggers.ts` | **Deleted** (whole file was dead — never imported by the `lib/index.js` entry) | Confirmed via import graph |
| `stripe_flutter` dependency | `flutter_app/pubspec.yaml` | **Removed** | No Dart code imported it |
| `STRIPE_*` env vars | `.env.example` | **Removed** | Only read by the removed webhook |
| `HYPERPAY_*` env vars | `.env.example` | **Removed** | **No code referenced them at all** |

## 2. Verification — was anything *active* depending on Stripe?

**No.** Greps across the whole repo confirm:
- **Nothing sets `stripeCustomerId`** on user docs, and **there is no checkout / customer-creation flow anywhere** (Dart, TS, or Python). The webhook keyed off `stripeCustomerId`, which was never populated → the Stripe path could never have fired in production.
- The app was already built for RevenueCat: `subscription_engine/models.py` is explicitly RevenueCat-shaped, and `flutter_app/.../upgrade_screen.dart` already contains a disabled "RevenueCat integration point". Stripe was vestigial scaffolding, not a working integration.

Conclusion: **removal is safe** — no active feature depended on Stripe or HyperPay.

## 3. Orphaned data (no code change needed now)
These user-doc fields are no longer written by any code but may exist on old docs. They are harmless (ignored by the new feature-gate, which reads `userSubscriptions`). Clean up in a later data migration if desired — do **not** back-fill them.
- `subscriptionTier`, `subscriptionExpiry`, `stripeCustomerId`, `stripeSubscriptionId` (still referenced as display/model fields in `models.dart` / `profile_screen.dart`; safe to leave until the RevenueCat migration).

## 4. Migration plan — enabling subscriptions later (RevenueCat)
When the business is ready to turn subscriptions on:
1. Add `purchases_flutter` (RevenueCat SDK) to `pubspec.yaml`; wire the purchase buttons at the existing integration point in `upgrade_screen.dart`.
2. Create products in App Store Connect + Google Play; map them to RevenueCat entitlements.
3. Add a **RevenueCat webhook** Cloud Function that writes/updates the `userSubscriptions` Firestore doc in the shape `subscription_engine/models.py` already defines (the models docstring describes exactly this). Entitlement continues to be decided by `FeatureGate` — the webhook only feeds it.
4. Set `SUBSCRIPTIONS_ENABLED=true` and the master switch in subscription config.
5. Re-wire the two Cloud Functions that were guarded off in 0.3:
   - `aiAssistant` daily limit → read from the feature-gate/`usageLimits` instead of `AI_DAILY_FREE_LIMIT`.
   - `triggerAutoBidSuggestions` → replace the dormant legacy `subscriptionTier` query with an entitlement lookup against `userSubscriptions`.
6. **Never** write billing state into Firebase custom claims (see 0.2). Claims carry identity/authz only; entitlement lives in `userSubscriptions`.
