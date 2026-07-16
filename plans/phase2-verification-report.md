# Phase 2 — Verification Report (Production Readiness)

**Scope:** T1–T8 of `prompt-phase2-production.md`.
**Environment caveat (unchanged):** no Dart/TS compile, no Firebase emulator, no Python service deps/pytest, network off. Python changes are syntax-checked (and, where possible, executed with stubs); TS is brace/paren-balanced; UI and multi-file Dart refactors are specified for local application, not edited blind. **Your local `flutter analyze` / `tsc --noEmit` / `pytest` / rules emulator + a staging smoke test is the gate.**

---

## Status by task

| Task | Change | Verification |
|---|---|---|
| **T1** Assets reconciliation | `pubspec.yaml`: removed the unused `assets/icons/` declaration and the **missing** Inter fonts block (build-blocking); app falls back to the platform font (which covers Arabic better than Inter). Generated an **obvious placeholder** `assets/images/najm_logo.png` so the referenced asset resolves without crashing. | Directory/reference now consistent. Font binaries genuinely can't be fabricated here — swap-in documented in `pubspec.yaml` and the runbook. |
| **T2** Performance | `index.ts`: `onChangeSummaryGenerated` per-admin `fcmTokens` reads parallelised with `Promise.all` (was N sequential round-trips; also fixed an `admin`-shadowing bug). `weeklyProfileRebuild` now **paginates all approved users** (the old `.limit(500)` silently skipped everyone past 500) with bounded concurrency (10) and a 540 s timeout. | Balanced **{} 204/204, () 384/384**, exports **17**. For very large user bases, fan out to Cloud Tasks (noted in-code + runbook). |
| **T3** UI / accessibility | **Guidance, not blind edits** (`plans/phase2/production-readiness.md`): route hard-coded `'Inter'` styles through the theme; contrast/tap-target/semantics/dynamic-type checklist; and the dead Arabic-toggle removal as a traced, local change. | Deliberately not executed blind (no compiler/preview) — high regression risk, low confidence. |
| **T4** Dead-code removal | **Removed:** four empty `functions/src` subdirs. **Kept (verified live):** `subscriptionTier`/`subscriptionExpiry` drive the PRO/free UI across 6 files — removing them would break the app. **Documented for local removal:** `stripeCustomerId` (Freezed field — needs `build_runner`); empty Hive adapters. | Verified against real usages before removing — the "orphaned Stripe fields" assumption was **false** for the tier fields; catching that prevented a break. |
| **T5** AI grounding + eval | `ai/nlp_router.py`: injects the app's **actual** FTL thresholds (from `legality.engine.DEFAULT_RULES`) into the system prompt and adds cite-or-refuse discipline ("use only the grounded thresholds; never invent a regulatory number; defer to the manual/Knowledge Center otherwise"). Added `tests/eval/test_ai_grounding.py` (prompt-content assertions + a behavioural eval set for an API-backed nightly job). | `py_compile` clean. Grounding closes the biggest AI safety gap (regulatory hallucination). |
| **T6** Observability | `utils/logging_config.py`: structured JSON logs with a `request_id` correlation field and a **secret-redaction** filter (bearer/JWT/long-hex); wired into service startup. PDPL stance documented: don't log names/roster/salary — redaction is a backstop for secrets. | **Executed:** redaction filter passes **4/4** runtime checks (scrubs secrets, preserves normal messages). `main.py` still compiles. |
| **T7** Docs + naming | `plans/phase2/production-readiness.md`: architecture, trust boundaries, required config, deployment order, observability, and the CIP↔Najm naming alignment (docs-level, not an identifier rename). | Written. |
| **T8** Release + rollback | `plans/phase2/rollback-runbook.md`: per-component rollback (rules / functions / Cloud Run / mobile), go/no-go, staging smoke test, feature flags (`SUBSCRIPTIONS_ENABLED`, `AI_DAILY_FREE_LIMIT`), backup/restore checks, and the trigger signals for each rollback. | Written. |

---

## Residual risks / must-do locally
1. **Compile/import** — run `flutter analyze`, `tsc --noEmit`, `pytest`, and boot the Python service; nothing Dart/TS was compiled here and Python deps weren't importable.
2. **Placeholder logo** — replace `assets/images/najm_logo.png` with the real logo before release.
3. **T3 UI + Arabic toggle + `stripeCustomerId` + Hive** — apply with a compiler/build-runner per `production-readiness.md`; these were intentionally not edited blind.
4. **`weeklyProfileRebuild` at very large scale** — move to Cloud Tasks if it approaches the 540 s timeout.
5. **Monitoring/alerting** — the logging utility is in place; Cloud Monitoring dashboards/alert policies are infra config to stand up in your project.

## Recommendation
Phase 2 is code-complete for the safely-automatable work; the remainder is precisely specified for local application. **Recommend production only after** a green local build/test across all stacks, a rules emulator pass, the staging smoke test in the runbook, and a rehearsed rollback per component.
