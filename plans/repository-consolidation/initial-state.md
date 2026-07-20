# Repository Consolidation — Initial State

Date: 2026-07-20 03:23 (+0300, local)

## Repositories

| Role | Path | Notes |
|---|---|---|
| TARGET (authoritative) | `/Users/monti/Desktop/NAJM_DEPLOY_TEST` | Git repository, modified in this workflow |
| SOURCE (legacy, read-only) | `/Users/monti/Desktop/NAJM/extracted/najm_complete` | Git repository, never modified |

## TARGET Git state (verified before any modification)

- Git root: `/Users/monti/Desktop/NAJM_DEPLOY_TEST`
- Remote: `origin` → `https://github.com/iDh88/najm-deploy-test.git` (fetch/push)
- Branch at session start: `merge/repository-consolidation` at `d98162c`
- Working tree at session start: **clean**
- Backup branch: `backup/before-consolidation` → `67ca61730297ec195e8033051f9532cc13403151` ✓ exists
- Safety tag: `before-consolidation` → commit `d98162cb089899987aca3446e81df9c844f294b6` ✓ exists
  - Note: the tag points to `d98162c`, the *parent* of the checkpoint commit. Documented as found; not modified.
- Checkpoint commit: `67ca617` "Backup before repository consolidation" ✓ exists, ✓ reachable from `backup/before-consolidation` (it is its tip)
- Ancestry verified: `d98162c` is the parent of `67ca617`; `67ca617` adds only `AUDIT/product_recovery/*` files (29,853 insertions, no deletions).

### Action taken

`merge/repository-consolidation` existed but was at `d98162c` (one commit behind the checkpoint, an ancestor, no unrelated work). It was **fast-forwarded** (`git merge --ff-only 67ca617`) to the checkpoint commit. No history was rewritten; no branch/tag/commit was moved, deleted, or force-updated. No uncommitted changes existed, so no extra checkpoint branch was needed.

Working branch now: `merge/repository-consolidation` @ `67ca617`, clean tree.

## SOURCE Git state (read-only observation)

- SOURCE contains a `.git` directory. Latest commits (not modified):
  - `d50c94b` test: make unit suite pass under real pytest (0 failed)
  - `41f3724` fix(firebase): emulator-aware init for credential-free local dev (ADR-011)
  - `e96cc32` docs(phase-3): persist Phase 3 completion report (ADR-020)
- SOURCE working tree has **uncommitted modifications** (observed, untouched): `NAJM_ARCHITECTURE.md`, `docs/ARCHITECTURE_LOCK.md`, `docs/SECRETS.md`, `doctor.sh`, `flutter_app/lib/app/router.dart`, and possibly more.
- SOURCE contains a `.env` file (secrets — will NOT be read for values, will NOT be copied).

## Detected subprojects (both repos share the same overall layout)

- `flutter_app/` — Flutter application (Dart)
- `python_services/` — Python backend services
- `admin_panel/` — admin panel (Node)
- `firebase/` — Firebase config, rules, emulator setup
- `docs/`, `plans/`, `reports/`, `AUDIT/`, `scripts/`, `tools/`, `test_fixtures/`
- TARGET-only at top level: `vercel_api/`, `vercel.json`, `LOCAL_RUN.md`, `VERSION.md`, `VISION_GAP_ANALYSIS.md`, `.vercel/` (machine-local), `.env.local`
- SOURCE-only at top level (candidates): `CLAUDE.md`, `setup.sh`, `doctor.sh`, `start.sh`, `stop.sh`, `restart.sh`, `reset.sh`, `clean.sh`, `update.sh`, `.najm/`, `.claude/`, `.env` (secret — excluded), `.pytest_cache` (cache — excluded)

## Toolchain versions

- Flutter 3.24.5 (channel user-branch, revision `dec2ee5c1f`, 2024-11-13)
- Node v20.20.2, npm 10.8.2
- Python 3.9.6 (system)
- firebase-tools 15.23.0

No secrets are included in this report.
