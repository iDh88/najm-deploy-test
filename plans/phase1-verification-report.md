# Phase 1 — Verification Report (Security & Foundation)

**Scope:** T1–T9 of `prompt-phase1-security.md`.
**Environment caveat (unchanged from Phase 0):** Dart/TypeScript cannot be compiled and the Firebase emulator cannot run in this sandbox; **service Python deps (fastapi/pydantic/firebase_admin) and pytest are not installed and the network is off.** Python `py_compile` therefore verifies *syntax* only, not runtime imports. TS/rules are verified statically (brace/paren balance, caller tracing). **Your local `flutter analyze` / `tsc --noEmit` / `firebase deploy --only firestore:rules` / `pytest` is the real gate.**

---

## Status by task

| Task | Change | Verification |
|---|---|---|
| **T1** Token-derived identity | `resolve_user_id()` added to `utils/auth.py`; applied to 10 endpoints in `ai/nlp_router.py`, `auto_bid/engine.py`, `trade_engine/router.py`. User calls are pinned to the token uid; service calls trust the body. Legality endpoints untouched (they take schedules, not user ids). | **Executed** against the real function via stubbed imports: **5/5** assertions pass (service passthrough, user pin, empty-body pin, missing-uid→401, service:false→user). `py_compile` clean. |
| **T2** Approval enforcement | Approval gate added centrally inside `verify_firebase_auth` (`accountStatus == "approved"` else 403). Inherited by the 4 user routers **and** the user branch of `verify_service_or_user`; service calls bypass. | `py_compile` clean. Centralized so no endpoint can omit it. Note: claims propagate on ID-token refresh (same as Firestore rules). |
| **T3** AI rate limit on the real path | `_enforce_ai_daily_limit()` added to `ai/nlp_router.py` and called in `/chat` after identity resolution; limit from `AI_DAILY_FREE_LIMIT` (default 50) via Firestore `aiUsage/{uid}_{date}`; service calls exempt. | `py_compile` clean. Closes Finding F (client calls `/v1/ai/chat` directly, bypassing the Cloud Function limit). Soft limiter (read-then-increment) — acceptable for a per-day cap. |
| **T4** Firestore rules + feature gate | `firestore.rules`: `tradeContacts` scoped by `userId` field (aligns with its `.where('userId')` query); `userLikes`/`userSaves`/`userRatings` scoped by doc-id prefix `uid_*` (direct-doc access); duplicate `behaviorEvents` block removed. `feature_gate.py`: unconfigured-feature branch now **fails closed** once subscriptions are enabled (was fail-open). | Rules brace balance **92/92**. Doc-id/field formats confirmed against the actual writers before scoping (no query breakage). `feature_gate` `py_compile` clean. |
| **T5** Account-deletion pipeline | `processAccountDeletion` in `functions/src/index.ts` rewritten: chunked `deleteQuery` (400/batch); per-user collections by field / by doc-id / by id-prefix; open trades cancelled (counterparty preserved); Storage `users/{uid}/` deleted; `deletionStatus` state machine (processing→data_deleted→completed / failed); **Auth user deleted last**; idempotent with retry via `throw`. | Balance **{} 203/203, () 364/364**, exports **17**. Collection keys confirmed for most; **behaviorEvents/subscriptionEvents/uploads/flightLines field names inferred** — a wrong field only *under-deletes*, it does not error (flagged in-code). |
| **T6** Tests | `tests/unit/test_auth_identity.py` added for the repo CI; the highest-risk new logic (identity) is executable-proven above. | Broader suite (legality safety, feature-gate, Flutter auth/token) is **not yet expanded** — deps can't run here; CI (T7) runs the suite once deps are present. Honest gap. |
| **T7** CI/CD | `.github/workflows/ci.yml` added: python (pip + pytest + ruff), functions (`tsc --noEmit` + eslint), flutter (analyze + test), firestore rules (emulator exec if tests exist). | Make these **required status checks** in branch protection to block merge/deploy on red. |
| **T8** Infra hardening | `main.py`: CORS origins parsed safely (was `"".split(",")` → `['']`); `/openapi.json` gated to development; startup env validation (warns on missing `ANTHROPIC_API_KEY`/`ALLOWED_ORIGINS`; `INTERNAL_SERVICE_TOKEN` stays fail-closed). | `py_compile` clean. |
| **T9** English-only + Unicode | **No code change required.** App already hard-forces `Locale('en')` in `localeResolutionCallback` (`supportedLocales=[en]`), so the UI is English-only by construction. Python has no ASCII-forcing; Arabic data (`nameAr`, manual text, notifications) renders via Unicode `Text`. | Verified by scan. Flagged (not changed): a **dead** Arabic toggle in settings + an unreachable `app_ar.arb` — routed to Phase 2 T3 (UI consistency) as a product decision, and Arabic-glyph font coverage to Phase 2 T1 (assets). |

---

## Residual risks / must-verify locally
1. **Runtime imports** — none of the Python was import-executed here; run `pytest` and boot the service locally to confirm fastapi/pydantic/firebase wiring.
2. **T5 inferred collection keys** — reconcile `behaviorEvents/subscriptionEvents/uploads/flightLines` field names against the data model so deletion is complete (PDPL).
3. **T5 trade cancellation** — batches all of a user's trades in one commit; fine for normal volumes, revisit if any user can exceed ~500 trades.
4. **T2 token refresh** — a just-approved user may need a token refresh before the Python layer sees `approved` (same as rules). Confirm the client force-refreshes on approval if instant access is required.
5. **Rules** — deploy to a staging project and run the emulator/rules tests before production; confirm the `tradeContacts` query still works under the field-scoped rule.

## Recommendation
Phase 1 is code-complete and internally consistent. **Do not deploy until a green local `flutter analyze` + `tsc --noEmit` + `pytest` + a rules emulator pass**, then a staging smoke test of: login (approved vs pending), an AI chat past the daily limit, a trade search, and an account-deletion request end-to-end.
