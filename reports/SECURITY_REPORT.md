# SECURITY REPORT — Najm CIP, Remediation v1.2.0 (2026-07-11)

Scope: authentication/authorization across the three tiers, Firestore/Storage
rules, upload surfaces, secrets handling, supply chain, and the security
posture of the new code added by this pass.

## 1. Verified-fixed this release

| # | Finding | Fix | Evidence |
|---|---|---|---|
| S1 | **Upload identity spoofing** — `POST /v1/intelligence/upload` trusted a `user_id` query param; any authenticated user could file uploads (and downstream `monthly_lines`) under another uid. | Identity pinned to token uid via `resolve_user_id`; query param honoured only for the trusted service token. | `intelligence/router.py` upload; harness suite `test_auth_identity.py` green. |
| S2 | **Unbounded upload body** — `await file.read()` buffered arbitrary bytes in RAM (DoS). | Chunked read with hard 20 MB cap → 413; temp file always unlinked. | Same endpoint; 413 path covered in OpenAPI. |
| S3 | **Silent status-write failure** — `except: pass` around the `uploads/{id}` tracking doc left clients polling forever. | Fail-loud 503 + `logger.exception`; temp file cleaned. | Same endpoint. |
| S4 | **Token-revocation bypass** — `subscription_engine` and `knowledge_engine` admin/user verifiers called `verify_id_token()` without `check_revoked`, undoing the pass-1 revocation hardening (a suspended admin's live ID token kept working for up to 1 h). | Both routers verify through `utils.firebase.verify_firebase_token` (`check_revoked=True`) and require `accountStatus == approved`. | Router headers document the contract; suites green. |
| S5 | **Privilege clobbering on re-approval** — `approveUser` replaced the whole custom-claims object, silently stripping `admin`/`superAdmin`/`privileges`/`rankScope`. | Claims merged over `getUser().customClaims`. | `admin_setup.ts`; mirrors the pass-1 A3 pattern. |
| S6 | **Signup abort pre-setup** — `onUserCreated` threw if the super-admin account didn't exist yet. | Notification path wrapped; signup proceeds. | `admin_setup.ts`. |
| S7 | **Storage deny-all broke a feature and invited rule-loosening** — layover photo uploads (`recommendations/*`) fell through to deny-all. | Dedicated rule: authenticated read; create image-only ≤ 5 MB, immutable; admin-only delete. | `storage.rules`; rules tests assert oversize/PDF/anon/delete paths. |
| S8 | **Unauthenticated Flutter client** — `intelligence_service.dart` sent no Authorization header (and to the wrong host/paths). | Bearer interceptor (Firebase ID token) + env-driven base URL + `/v1` paths. | Client file; matches `ai_service.dart` pattern. |
| S9 | **`userSaves` list access** — new owner-list rules clause is scoped: list provable only via `resource.data.userId == request.auth.uid`; writes still pinned to the `{uid}_{recId}` docId. | Rule + 2 rules tests (owner list allowed, cross-user denied). | `firestore.rules`, `firebase/test/rules.spec.mjs`. |

## 2. Standing posture (unchanged, reviewed OK)

* Service-to-service calls: `X-Service-Token` shared secret (`INTERNAL_SERVICE_TOKEN`), constant-time compare in `utils/auth.py`; rotate on any suspicion — documented in the runbook.
* Firestore rules: default-deny; self-signup forced to `accountStatus: pending` with required keys; owner updates cannot touch `accountStatus` (rules-tested); `legalityRules` writes are **superAdmin-only** (rules-tested) — important now that the collection drives live verdicts.
* Admin panel served with `X-Frame-Options: DENY`, `nosniff`, HSTS (firebase.json).
* Knowledge documents never public; signed URLs via admin-privileged endpoints only.
* No secrets in the repo: `.env.example` placeholders only; gitleaks workflow added for continuous assurance (run one manual full-history scan after import).

## 3. Supply chain & pipeline

* `stripe` dependency removed (dead billing path); Dependabot enabled for pip/npm/pub/actions; CodeQL (python, javascript-typescript) weekly + on PR.
* Deploy uses **Workload Identity Federation** — no long-lived deploy keys; production environment approval gate; rollback workflow cannot run concurrently with deploy.
* Residual: `firebase/functions/package-lock.json` still not committed → `npm install` (not `ci`) in CI; commit a lockfile for reproducible, tamper-evident installs. CODEOWNERS handles are placeholders until real GitHub users are set — until then required-owner review is **not enforced**.

## 4. Residual risks / accepted

| Risk | Severity | Disposition |
|---|---|---|
| Rules tests authored but first executed in CI (no emulator offline) | Med | Condition of release gate — see RELEASE_READINESS. |
| AI daily limiter is read-then-increment (racy under parallel calls) | Low | Bounded overshoot only; move to a transaction/`Increment` post-launch. |
| `behaviorEvents` dual schema (Functions camelCase bid events vs Python snake_case trade events in one collection) | Low | Coherent per-reader today; documented tech debt — split collections in a scheduled migration. |
| Firebase App Check enforced on client init but Python service accepts any valid ID token (no App Check verification server-side) | Low | Acceptable: authz is claims-based; revisit if abuse observed. |
