# Phase 2 — Release & Rollback Runbook (T8)

Per-component rollback plans, go/no-go criteria, and the signals that should trigger a rollback. Each component can roll back **independently** because releases are kept backward-compatible.

---

## Go / no-go (all must be green before production)
- CI green: `flutter analyze` + `flutter test`, `pytest`, `tsc --noEmit` + eslint, Firestore rules emulator tests.
- Staging smoke test passes (see checklist below).
- A rehearsed rollback for each component (below).
- `SUBSCRIPTIONS_ENABLED=false` confirmed in the production environment.

## Staging smoke test (run end-to-end)
1. Login as an **approved** user → succeeds; as a **pending** user → blocked with 403 from the Python layer.
2. AI chat: send messages past `AI_DAILY_FREE_LIMIT` → 429 after the cap; ask a regulatory question → answer cites the grounded FTL value, and an off-book policy question → defers to the manual (no invented number).
3. Trade search + record an event + read your own profile → works; attempting another user's id → pinned to your own.
4. Toggle a like/save/rating → writes; confirm you cannot read/write another user's like/save doc.
5. Submit an account-deletion request → `deletionStatus` walks processing → data_deleted → completed; user data + Storage gone; Auth account removed last.

---

## Component rollback plans

### 1. Firestore rules
- **Deploy:** `firebase deploy --only firestore:rules`.
- **Rollback:** redeploy the previous `firestore.rules` from git (keep the last-known-good tagged). Rules changes take effect within seconds.
- **Trigger signals:** spike in `permission-denied` client errors; users unable to read their own bids/likes/trade contacts (would indicate the owner-scoping over-restricted a real query).
- **Pre-check:** the `tradeContacts` rule is **field-scoped** (`resource.data.userId`) specifically to keep its `.where('userId')` query working — verify that query in staging before prod.

### 2. Cloud Functions
- **Deploy:** `firebase deploy --only functions`.
- **Rollback:** redeploy the previous build from git, or in the console pin the prior version. Functions are independent of the app.
- **Trigger signals:** rising function error rate/latency; failed account deletions (`deletionStatus == failed`); missing admin push notifications; `weeklyProfileRebuild` timeouts.
- **Notes:** `weeklyProfileRebuild` now paginates all users with bounded concurrency and a 540 s timeout — if a very large user base still times out, fan it out to Cloud Tasks (documented in T2) before re-enabling.

### 3. Python service (Cloud Run)
- **Deploy:** deploy the new revision with **all** env vars (it fails closed without `INTERNAL_SERVICE_TOKEN`).
- **Rollback:** Cloud Run keeps revisions — shift 100% traffic back to the previous revision (instant, no rebuild). Consider a canary (e.g., 10%) before full cutover.
- **Trigger signals:** 5xx rate up, auth 401/403 spikes (mis-set token or approval rollout), 503 on boot (missing `INTERNAL_SERVICE_TOKEN`), AI latency/timeout.
- **Config rollback:** env-only changes (e.g., `ALLOWED_ORIGINS`, `AI_DAILY_FREE_LIMIT`) roll back by redeploying the prior revision's config — no code change.

### 4. Mobile app
- **Release:** staged rollout (e.g., 10% → 50% → 100%) on App Store / Play.
- **Rollback:** halt the staged rollout; if already live, ship a hotfix or roll back to the prior build (Play supports halting; iOS requires an expedited hotfix). Because the backend stays backward-compatible, an older app keeps working.
- **Trigger signals:** crash-free-sessions drop, auth failures, the placeholder logo appearing (means the real `assets/images/najm_logo.png` wasn't swapped in — see Phase 2 T1).

---

## Feature flags / kill-switches
- **`SUBSCRIPTIONS_ENABLED`** (env + Firestore config): the master switch. `false` = free launch (feature-gate opens everything); flipping to `true` activates gating and the fail-**closed** behaviour for unconfigured feature keys — so **all** paid features must be configured before flipping it.
- **`AI_DAILY_FREE_LIMIT`**: raise/lower to widen/narrow AI usage without a deploy (env change → Cloud Run revision).

## Backup / restore (verify before launch)
- Enable scheduled Firestore exports to a GCS bucket; confirm a test restore into a staging project works.
- Confirm Cloud Storage versioning/retention for user-uploaded roster PDFs (the deletion pipeline removes `users/{uid}/` — verify exports capture what you need for compliance retention vs. erasure).
