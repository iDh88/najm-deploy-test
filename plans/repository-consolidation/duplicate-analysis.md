# Duplicate Analysis

## Cross-repository duplicates

344 of 457 SOURCE files are byte-identical duplicates of their TARGET counterparts
(same relative path). These need no action and are enumerated in
`file-classification.csv` with classification "present in both, byte-identical".

Hash-based rename detection (same content at a different path) found **0** probable
renames in either direction.

## Near-duplicates (same intent, diverged content)

These pairs implement the same thing twice with drift; in every case the TARGET copy
was kept (details in conflict-analysis.md and the CSV):

- `flutter_app/lib/app/theme.dart` — both repos independently added a semantic
  colour-alias layer (`primary`, `surface`, `textPrimary`, …) with slightly different
  values. Functional duplicates; TARGET kept.
- `flutter_app/lib/features/layover/widgets/recommendation_card.dart` +
  `recommendation_detail_screen.dart` — SOURCE made `_BadgesRow` public and re-used
  it; TARGET kept it private with its own detail-screen changes. Paired refactors,
  internally consistent per repo.
- `flutter_app/lib/core/services/ai_status_service.dart` + `profile_screen.dart` —
  SOURCE removed the `displayName` alias and updated its caller; TARGET kept both.
- `.env.example` — two templates for the same env surface; merged into one
  (SOURCE structure + TARGET-specific vars + TARGET GLM vars).
- `.gitignore` — two ignore policies; selectively merged (see applied-changes.md).

## Duplicates inside TARGET

- `AUDIT/product_recovery/product_audit_report_grep.md` (26k lines) substantially
  contains the output of `run_product_audit_grep.sh` and overlaps
  `product_audit_report.md`. Generated audit output committed by the checkpoint
  commit `67ca617`. Left untouched per rule 9; noted as an obsolete-candidate for
  the owner (could be regenerated on demand).

## Obsolete candidates (documented only — nothing moved or deleted, rule 9)

- TARGET `.github/workflows/deploy.yml` deploys to Cloud Run while TARGET's active
  deployment path is Vercel (`scripts/deploy_vercel.sh`, `vercel.json`). Both kept.
- TARGET `LOCAL_RUN.md` overlaps the newly added `start.sh`/`doctor.sh` workflow;
  kept, cross-referenced in AGENTS.md.
- SOURCE `tools/offline_harness/` (identical in both) is a fallback harness whose
  `pytest.run_async` shim is now mirrored in `python_services/tests/conftest.py`.
