# archive/repository_consolidation

Created 2026-07-20 during the SOURCE→TARGET repository consolidation
(`plans/repository-consolidation/`). Nothing in this directory is an active
implementation directive.

- `source_unmerged/` — reviewed SOURCE (`NAJM/extracted/najm_complete`) files
  that contain potentially valuable work but could NOT be merged safely into the
  authoritative TARGET code. Relative paths mirror the original repo layout.
  Rationale per file: `plans/repository-consolidation/conflict-analysis.md`.
- `historical_phases/` — completed legacy phase reports (Phase 2 dev
  environment, Phase 3 secrets, Phase 6 closure). They reference commit hashes
  from the legacy repository's own git history, which does not exist here.
