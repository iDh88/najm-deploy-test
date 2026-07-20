#!/usr/bin/env bash
# ============================================================================
# reset.sh — deep-reset the NAJM development environment
#
# Implements ADR-011 (Local Development). DESTRUCTIVE: removes installed
# dependencies and all regenerable state, then (by default) re-runs ./setup.sh
# to rebuild from scratch. Your secrets (.env) and source code are PRESERVED.
#
# Removes:
#   • python_services/.venv
#   • **/node_modules  (functions, admin)
#   • generated Dart (*.g.dart, *.freezed.dart), flutter build/.dart_tool
#   • firebase/functions/lib
#   • python caches (via clean.sh) and .najm/ runtime state
# Preserves:  .env, all source, git history.
#
# Usage:
#   ./reset.sh              # confirm, wipe, then re-run ./setup.sh
#   ./reset.sh --yes        # skip the confirmation prompt
#   ./reset.sh --no-setup   # wipe only; do NOT re-run setup afterwards
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$REPO_ROOT/python_services"
FLUTTER_DIR="$REPO_ROOT/flutter_app"
RUN_DIR="$REPO_ROOT/.najm"

ASSUME_YES=0
RUN_SETUP=1
for arg in "$@"; do
  case "$arg" in
    --yes|-y)   ASSUME_YES=1 ;;
    --no-setup) RUN_SETUP=0 ;;
    --help|-h)  grep '^#' "$0" | grep -v '^#!' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Unknown option: %s (use --yes, --no-setup, --help)\n' "$arg"; exit 2 ;;
  esac
done

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
    "$REPO_ROOT"/*) : ;;
    *) warn "refusing to remove path outside repo: $p"; return 1 ;;
  esac
  if [[ -e "$p" ]]; then rm -rf "$p" && ok "removed ${p#"$REPO_ROOT"/}"; fi
}

printf '%s%s NAJM — deep reset%s\n' "$BOLD" "$RED" "$RST"
warn "This DELETES .venv, node_modules, generated code, build artifacts and .najm/ state."
info "Your .env and source code are preserved."

# ── Confirmation guard ───────────────────────────────────────────────────────
if (( ! ASSUME_YES )); then
  printf '%sType %sreset%s to continue: ' "$YLW" "$BOLD" "$RST"
  read -r ans
  if [[ "$ans" != "reset" ]]; then
    printf '%sAborted — nothing was changed.%s\n' "$DIM" "$RST"
    exit 1
  fi
fi

# ── Stop any running stack first (avoid orphaned processes) ───────────────────
step "Stopping running services"
if [[ -x "$REPO_ROOT/stop.sh" ]]; then
  "$REPO_ROOT/stop.sh" all || true
else
  info "stop.sh not found — skipping."
fi

# ── Light clean (build artifacts, caches, logs) ──────────────────────────────
step "Cleaning build artifacts & caches"
if [[ -x "$REPO_ROOT/clean.sh" ]]; then
  "$REPO_ROOT/clean.sh" || true
else
  info "clean.sh not found — continuing with deep removals only."
fi

# ── Deep removals (installed deps + generated code + runtime) ─────────────────
step "Removing installed dependencies"
safe_rm "$PY_DIR/.venv"
find "$REPO_ROOT" -type d -name 'node_modules' -prune -exec rm -rf {} + 2>/dev/null && ok "removed node_modules"

step "Removing generated code & remaining state"
find "$FLUTTER_DIR" \( -name '*.g.dart' -o -name '*.freezed.dart' \) -delete 2>/dev/null && ok "removed generated Dart"
safe_rm "$FLUTTER_DIR/build"
safe_rm "$FLUTTER_DIR/.dart_tool"
safe_rm "$REPO_ROOT/firebase/functions/lib"
safe_rm "$RUN_DIR"

# ── Re-setup (unless suppressed) ─────────────────────────────────────────────
if (( RUN_SETUP )); then
  step "Rebuilding environment (./setup.sh)"
  if [[ -x "$REPO_ROOT/setup.sh" ]]; then
    exec "$REPO_ROOT/setup.sh"
  else
    warn "setup.sh not found — cannot rebuild automatically."
    exit 1
  fi
fi

echo
printf '%s%s✓ Reset complete (wipe only).%s Run %s./setup.sh%s to rebuild.\n' "$BOLD" "$GRN" "$RST" "$BOLD" "$RST"
exit 0
