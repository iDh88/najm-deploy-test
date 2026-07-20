# Phase 3 — Secrets Management

**Status:** ✅ Complete · **Date:** 2026-07-15 · **ADRs:** 003, 004, 009, 000, 020
**Commits:** `2f9ce7f` (.env.example) · `a501263` (deploy.yml) · `866ab8c` (SECRETS.md) · `0866e54` (ci.yml)

Per ADR-020, the persisted completion report for Phase 3.

---

## Completed work

Established a coherent, portable secrets model: local `.env` ↔ cloud Secret
Manager ↔ ADC, with the app reading everything via `os.environ` (no code
change). Audited the codebase, closed the documentation and delivery gaps, and
added a CI invariant so client isolation can't silently regress.

**Read-only audit findings (verified):**
- No server secrets referenced in the Flutter/Admin clients.
- No hardcoded live secrets in tracked files.
- gitleaks + CodeQL already run in `security.yml`.
- `.env` / `.env.example` key parity was intact.
- Python config is read via `os.environ` throughout.

## Files added

| File | Purpose |
|---|---|
| `docs/SECRETS.md` | Secret inventory, per-env sourcing, manual create/grant/rotate commands, required GitHub vars, guarantees |
| `docs/phases/PHASE_3_secrets.md` | This report (ADR-020) |

## Files modified

| File | Change |
|---|---|
| `.env.example` | Completed (added `OPENAI_API_KEY`, `CAE_*`, `LEGALITY_RULES_TTL_SECONDS`, `ZK_*`), grouped by secret/config, labeled Secret Manager ids, removed dead `SENTRY_DSN` (ADR-009) |
| `.github/workflows/deploy.yml` | Cloud Run `--set-secrets` (4 secrets from Secret Manager) + `--set-env-vars`; documented `vars.ALLOWED_ORIGINS`, Secret Accessor role, prerequisite secrets |
| `.github/workflows/ci.yml` | New `client-secret-isolation` job (ADR-004 invariant) |

## Secret model (result)

| Secret | Env var | Secret Manager id |
|---|---|---|
| Service token | `INTERNAL_SERVICE_TOKEN` | `internal-service-token` |
| Anthropic key | `ANTHROPIC_API_KEY` | `anthropic-api-key` |
| OpenAI key | `OPENAI_API_KEY` | `openai-api-key` |
| Admin bootstrap | `ADMIN_SETUP_TOKEN` | `admin-setup-token` |

Local-only: `GOOGLE_APPLICATION_CREDENTIALS` (cloud uses ADC / runtime SA).

## Testing performed

| Test | Result |
|---|---|
| Consumed-var coverage in `.env.example` (16 server vars) | ✓ all present |
| No real secrets in `.env.example` / `SECRETS.md` | ✓ placeholders only |
| Secret-id consistency across `.env.example` ↔ `deploy.yml` ↔ `SECRETS.md` | ✓ all 4 aligned |
| `deploy.yml` + `ci.yml` valid YAML | ✓ |
| Client-secret CI check executed locally | ✓ passes (0 matches) |
| Client leak scan (Flutter/admin) | ✓ none |
| Hardcoded live-secret scan | ✓ none |

## Remaining issues

1. **Secrets must be created in each project** (`gcloud secrets create …`) and
   `vars.ALLOWED_ORIGINS` set before a deploy succeeds — intended fail-closed;
   commands are in `docs/SECRETS.md` (owner runs them).
2. Two further ADR-004/000 CI invariants (no router without an auth `Depends`;
   no `firestore.client()` outside `utils/firebase.py`) are **deferred to
   Phase 5 (Authentication)**, where they fit thematically.

## Risks

- Low. All changes are config/docs/CI; no application code or runtime behavior
  changed. No real secret ever entered the repo (gitleaks also guards this).

## Rollback

- Per change: `git revert <sha>` (or `git checkout <sha>~1 -- <file>`).
  - `.env.example` → `2f9ce7f`, `deploy.yml` → `a501263`, `SECRETS.md` → `866ab8c`, `ci.yml` → `0866e54`.
- The changes are additive/documentation and safely revertible in isolation.
