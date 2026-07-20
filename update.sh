#!/usr/bin/env bash
# ============================================================================
# update.sh — refresh NAJM project dependencies to match their manifests
#
# Implements ADR-011 (Local Development). Use after pulling new code: it
# re-syncs each component's dependencies to the versions declared in its
# manifest (requirements.txt / pubspec.yaml / package.json) and regenerates
# code. It does NOT upgrade past pinned versions and does NOT recreate the
# environment (that is reset.sh).
#
#   • git         : pull if an upstream is configured (skipped otherwise)
#   • Python      : pip install -r requirements.txt (into existing .venv)
#   • Flutter     : pub get + build_runner + gen-l10n
#   • Functions   : npm ci / install  + tsc --noEmit
#   • Admin panel : npm install
#
# Usage:  ./update.sh
# Re-run: safe (idempotent).
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$REPO_ROOT/python_services"
VENV_DIR="$PY_DIR/.venv"
FLUTTER_DIR="$REPO_ROOT/flutter_app"
FUNCTIONS_DIR="$REPO_ROOT/firebase/functions"
ADMIN_DIR="$REPO_ROOT/admin_panel"
NODE_MAJOR="20"

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RST="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[34m')"
else
  BOLD=""; DIM=""; RST=""; RED=""; GRN=""; YLW=""; BLU=""
fi
step(){ printf '\n%s%s▶ %s%s\n' "$BOLD" "$BLU" "$1" "$RST"; }
ok(){   printf '  %s✓%s %s\n' "$GRN" "$RST" "$1"; }
warn(){ printf '  %s!%s %s\n' "$YLW" "$RST" "$1"; }
errln(){ printf '  %s✗%s %s\n' "$RED" "$RST" "$1"; }
info(){ printf '  %s%s%s\n' "$DIM" "$1" "$RST"; }
have(){ command -v "$1" >/dev/null 2>&1; }

FAILED=0

# Resolve Homebrew (off-PATH safe) + node@20 keg so node/npm are usable.
find_brew(){
  command -v brew 2>/dev/null && return 0
  local b; for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { echo "$b"; return 0; }
  done
  return 1
}
if BREW_BIN="$(find_brew)"; then
  eval "$("$BREW_BIN" shellenv)" 2>/dev/null || export PATH="$(dirname "$BREW_BIN"):$PATH"
  KEG="$("$BREW_BIN" --prefix 2>/dev/null)/opt/node@$NODE_MAJOR/bin"
  [[ -d "$KEG" ]] && export PATH="$KEG:$PATH"
fi

printf '%s%s NAJM — updating project dependencies%s\n' "$BOLD" "$BLU" "$RST"

# ── git pull (only if an upstream is configured) ─────────────────────────────
step "Source"
if have git && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    if git -C "$REPO_ROOT" pull --ff-only; then ok "git pull (fast-forward)"; else warn "git pull failed (resolve manually)"; fi
  else
    info "No upstream configured — skipping git pull."
  fi
else
  info "Not a git work tree — skipping."
fi

# ── Python ───────────────────────────────────────────────────────────────────
step "Python dependencies"
if [[ -x "$VENV_DIR/bin/pip" ]]; then
  "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip
  if "$VENV_DIR/bin/pip" install --quiet -r "$PY_DIR/requirements.txt"; then
    ok "requirements.txt re-synced"
  else
    errln "pip install failed"; FAILED=1
  fi
else
  warn ".venv missing — run ./setup.sh first."; FAILED=1
fi

# ── Flutter ──────────────────────────────────────────────────────────────────
step "Flutter dependencies"
if have flutter; then
  ( cd "$FLUTTER_DIR" && flutter pub get ) && ok "pub get" || { errln "pub get failed"; FAILED=1; }
  ( cd "$FLUTTER_DIR" && dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1 ) \
    && ok "build_runner regenerated" || warn "build_runner reported issues"
  ( cd "$FLUTTER_DIR" && flutter gen-l10n >/dev/null 2>&1 ) && ok "gen-l10n" || warn "gen-l10n reported issues"
else
  warn "flutter not found — run ./setup.sh first."; FAILED=1
fi

# ── Cloud Functions ──────────────────────────────────────────────────────────
step "Cloud Functions dependencies"
if have npm && [[ -f "$FUNCTIONS_DIR/package.json" ]]; then
  if ( cd "$FUNCTIONS_DIR" && { [[ -f package-lock.json ]] && npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1; } ); then
    ( cd "$FUNCTIONS_DIR" && npx tsc --noEmit >/dev/null 2>&1 ) \
      && ok "deps re-synced; tsc --noEmit passed" || warn "deps re-synced; tsc reported issues"
  else
    errln "npm install failed"; FAILED=1
  fi
else
  warn "npm or functions/package.json unavailable — skipping."
fi

# ── Admin panel ──────────────────────────────────────────────────────────────
step "Admin panel dependencies"
if [[ -f "$ADMIN_DIR/package.json" ]] && have npm; then
  ( cd "$ADMIN_DIR" && npm install >/dev/null 2>&1 ) && ok "deps re-synced" || warn "npm install reported issues (static SPA)"
else
  info "Static SPA — no dependency step."
fi

echo
if (( FAILED )); then
  printf '%s%s✗ Update finished with errors — see messages above.%s\n' "$BOLD" "$RED" "$RST"
  exit 1
fi
printf '%s%s✓ Dependencies up to date.%s Restart the stack with %s./restart.sh%s\n' "$BOLD" "$GRN" "$RST" "$BOLD" "$RST"
exit 0
