# Phase 2 — Development Environment

**Status:** ✅ Complete · **Date:** 2026-07-15 · **ADRs:** 011, 013, 006, 019, 020, 000
**Commits:** `144e0f3` (git init) → `9146517` (reset.sh)

Per ADR-020, this is the persisted completion report for Phase 2. Template:
Completed work · Files modified · Files added · Testing performed · Remaining
issues · Risks · Rollback.

---

## Completed work

Established version control and a one-command developer environment. The
primary objective — `git clone → ./setup.sh → ./start.sh` — is wired
end-to-end:

- **Git initialized** on `main` with a strict root `.gitignore` (secrets, envs,
  virtualenvs, build artifacts, generated Dart, `node_modules`, credentials,
  IDE/OS files, local Claude settings, `.najm/` runtime). Baseline commit
  tracked 390 files with **zero** secrets/credentials/build/generated content
  (verified by explicit pre-commit scans). Resolves audit blocker **B1**.
- **Eight lifecycle scripts** at repo root, all idempotent, fail-fast, colored,
  and conformant to the behavior contract (auto-install only non-interactive
  tooling; surface sudo/login/interactive steps as manual commands; never touch
  application source; exit non-zero on missing critical deps).

## Files added

| File | Purpose |
|---|---|
| `.gitignore` | Ignore secrets, venvs, build artifacts, generated code, runtime state |
| `setup.sh` | 19-step verified environment bootstrap (ADR-011) |
| `start.sh` | Local orchestrator: Firebase emulators + Python + Flutter, health-checked, prints URLs |
| `stop.sh` | Process-tree-aware graceful shutdown |
| `restart.sh` | `stop.sh` → `start.sh` delegator (no duplicated logic) |
| `clean.sh` | Light clean of build artifacts/caches/logs (repo-boundary `safe_rm`) |
| `doctor.sh` | Read-only environment diagnostics (ADR-011/019) |
| `update.sh` | Manifest-bound dependency refresh |
| `reset.sh` | Guarded deep wipe + re-setup (preserves `.env`) |
| `docs/phases/PHASE_2_dev_environment.md` | This report (ADR-020) |

## Files modified

| File | Change |
|---|---|
| `.gitignore` | Added `.najm/` runtime directory |
| `setup.sh` | Added `find_brew` + `brew shellenv` (robust Homebrew detection off-PATH) |

## Testing performed

| Test | Result |
|---|---|
| `bash -n` on all 8 scripts | ✓ all pass |
| `doctor.sh` executed (read-only) | ✓ exit 0 "healthy" — git, brew, Python 3.11, `.venv`+deps, Node 20, npm, Firebase CLI, Flutter, Java, Chrome present |
| `setup.sh` `find_brew` functional test (stripped PATH) | ✓ brew located off-PATH; `python3.11` resolved via keg |
| `reset.sh --help` executed | ✓ |
| Pre-commit secret/artifact scans | ✓ clean (no `.env`/`.venv`/build/creds/generated) |
| Self-bugs caught by running | 2 fixed (doctor brew-detection + venv-aware criticality; reset `--help`) |

Not executed (environment-changing, deferred by owner): full `setup.sh`,
`start.sh`, `update.sh`, `reset.sh` destructive path.

## Remaining issues

1. Full installers not proven end-to-end (owner opted to defer running
   `setup.sh`). Mitigated by syntax + isolated functional tests and the
   read-only `doctor.sh` confirming the real toolchain is healthy.
2. Client Firebase config still placeholder (**B2/B3**); `start.sh` detects and
   warns. Unblocking = `flutterfire configure` (a later phase, config not code).
3. Python↔emulator initialization (`utils/firebase`) unproven at runtime;
   `start.sh` sets standard emulator env vars and `/health` will surface a
   failure.

## Risks

- Low. Scripts are portable bash with repo-boundary delete guards, typed
  confirmation on the one destructive script, and `.env` preservation. The
  main unproven surface is first-run install on a clean machine.

## Rollback

- One script: `rm <script>.sh`.
- All Phase 2 commits, keep git: `git reset --hard 144e0f3` (returns to
  baseline; script files removed from the working tree).
- Remove version control entirely: `rm -rf .git` (all files remain on disk).
