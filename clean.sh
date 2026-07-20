#!/usr/bin/env bash
# ============================================================================
# clean.sh — remove NAJM build artifacts, caches and runtime logs
#
# Implements ADR-011 (Local Development). A LIGHT clean: everything it removes
# is regenerable by a build step. It does NOT remove sources, .env, the Python
# .venv, node_modules, or installed dependencies — that deeper wipe is reset.sh.
#
# Removes:
#   • flutter_app/build, flutter_app/.dart_tool
#   • firebase/functions/lib            (compiled TS output)
#   • __pycache__, *.pyc, .pytest_cache, .ruff_cache, .coverage, htmlcov
#   • .najm/ runtime logs (+ stale pid files)
#   • .DS_Store
#
# Usage:  ./clean.sh
# Safety: every removal is guarded to stay strictly inside this repository.
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$REPO_ROOT/.najm"

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RST="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[34m')"
else
  BOLD=""; DIM=""; RST=""; RED=""; GRN=""; YLW=""; BLU=""
fi
step(){ printf '\n%s%s▶ %s%s\n' "$BOLD" "$BLU" "$1" "$RST"; }
ok(){   printf '  %s✓%s %s\n' "$GRN" "$RST" "$1"; }
warn(){ printf '  %s!%s %s\n' "$YLW" "$RST" "$1"; }
info(){ printf '  %s%s%s\n' "$DIM" "$1" "$RST"; }

# Remove a path only if it exists AND is strictly inside the repo.
safe_rm(){  # $1 = absolute path
  local p="$1"
  [[ -z "$p" ]] && return 0
  case "$p" in
    "$REPO_ROOT"/*) : ;;                                   # inside repo — allowed
    *) warn "refusing to remove path outside repo: $p"; return 1 ;;
  esac
  if [[ -e "$p" ]]; then
    rm -rf "$p" && ok "removed ${p#"$REPO_ROOT"/}"
  fi
}

printf '%s%s NAJM — cleaning build artifacts, caches & logs%s\n' "$BOLD" "$BLU" "$RST"

# ── Guard: warn if the local stack still appears to be running ────────────────
step "Runtime check"
running=0
if [[ -d "$RUN_DIR" ]]; then
  for pf in "$RUN_DIR"/*.pid; do
    [[ -e "$pf" ]] || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      warn "$(basename "${pf%.pid}") still running (pid $pid)"
      running=1
    fi
  done
fi
if (( running )); then
  warn "Live services detected — run ${BOLD}./stop.sh${RST} first. Keeping .najm/ pid files; cleaning the rest."
else
  ok "No live services detected"
fi

# ── Flutter build artifacts ──────────────────────────────────────────────────
step "Flutter"
safe_rm "$REPO_ROOT/flutter_app/build"
safe_rm "$REPO_ROOT/flutter_app/.dart_tool"

# ── Cloud Functions compiled output ──────────────────────────────────────────
step "Cloud Functions"
safe_rm "$REPO_ROOT/firebase/functions/lib"

# ── Python caches (never inside .venv or node_modules) ───────────────────────
step "Python caches"
find "$REPO_ROOT" -type d -name '__pycache__' \
  -not -path '*/.venv/*' -not -path '*/node_modules/*' \
  -exec rm -rf {} + 2>/dev/null && ok "removed __pycache__ dirs"
find "$REPO_ROOT" -type f -name '*.pyc' \
  -not -path '*/.venv/*' -delete 2>/dev/null && ok "removed *.pyc"
safe_rm "$REPO_ROOT/python_services/.pytest_cache"
safe_rm "$REPO_ROOT/python_services/.ruff_cache"
safe_rm "$REPO_ROOT/python_services/.coverage"
safe_rm "$REPO_ROOT/python_services/htmlcov"

# ── Runtime logs / stale pids ────────────────────────────────────────────────
step "Runtime logs"
if [[ -d "$RUN_DIR" ]]; then
  rm -f "$RUN_DIR"/*.log 2>/dev/null && ok "removed .najm/*.log"
  if (( ! running )); then
    rm -f "$RUN_DIR"/*.pid 2>/dev/null && ok "removed stale .najm/*.pid"
    rmdir "$RUN_DIR" 2>/dev/null && ok "removed empty .najm/"
  fi
else
  info "no .najm/ runtime dir"
fi

# ── OS cruft ─────────────────────────────────────────────────────────────────
step "OS files"
find "$REPO_ROOT" -type f -name '.DS_Store' -delete 2>/dev/null && ok "removed .DS_Store files"

echo
printf '%s%s✓ Clean complete.%s Rebuild with %s./setup.sh%s (deps kept). Deeper wipe: %s./reset.sh%s\n' \
  "$BOLD" "$GRN" "$RST" "$BOLD" "$RST" "$BOLD" "$RST"
exit 0
