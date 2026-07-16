# Najm CIP — Remediation Status (FINAL)

**Payment model:** Launch FREE. Subscriptions built but disabled (`SUBSCRIPTIONS_ENABLED=false`). Future billing = Apple IAP + Google Play via RevenueCat. Stripe/HyperPay removed.
**UI language:** English-only (enforced), full Unicode for Arabic/multilingual data.

## Phase 0 — Critical fixes (COMPLETE, gate passed) -> phase0-verification-report.md
Router auth + fail-closed service token; 3 subscription systems collapsed to 1; Stripe webhook + claims-wipe removed; localhost->AppConfig; auth_provider fix; dead triggers.ts removed.

## Phase 1 — Security & foundation (COMPLETE) -> phase1-verification-report.md
T1 token identity (10 endpoints, proven 5/5) · T2 approval enforced centrally · T3 AI limit on the real path · T4 rules scoped + feature-gate fails closed · T5 deletion pipeline (chunked/Storage/Auth-last/idempotent) · T6 identity tests + CI file · T7 CI workflow · T8 infra hardening · T9 Unicode verified, UI already English-only.

## Phase 2 — Production readiness (COMPLETE) -> phase2-verification-report.md
T1 assets reconciled (+ placeholder logo) · T2 performance (N+1 parallelised, weekly rebuild paginated) · T3 UI/accessibility GUIDANCE (not blind-edited) · T4 dead-code (empty dirs removed; tier fields verified live and kept) · T5 AI grounding (real FTL values + cite-or-refuse) + eval set · T6 structured logging + secret redaction (proven 4/4) · T7 architecture/deploy docs · T8 rollback runbook.
   -> plans/phase2/production-readiness.md, plans/phase2/rollback-runbook.md

## Environment caveats (ALL phases)
No Dart/TS compile, no Firebase emulator, no Python service deps/pytest, network off. Changes are code-complete + statically verified (Python compiled; some logic executed via stubs; TS brace-balanced). REAL GATE = your local flutter analyze / tsc --noEmit / pytest / rules emulator + the staging smoke test in the rollback runbook.

## Apply locally (intentionally NOT edited blind)
- Replace assets/images/najm_logo.png placeholder with the real logo.
- T3 UI token/accessibility pass + remove the dead Arabic toggle (trace localeProvider first).
- Remove stripeCustomerId Freezed field via build_runner; decide on Hive offline caching.
- Reconcile the T5-deletion inferred collection field names against the data model.
