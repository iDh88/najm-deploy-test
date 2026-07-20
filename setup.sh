#!/usr/bin/env bash
# ============================================================================
# setup.sh — NAJM development environment bootstrap
#
# Implements ADR-011 (Local Development) of docs/ARCHITECTURE_LOCK.md.
# Idempotent · fail-fast · verified · colored. Target: macOS (Apple Silicon + Intel).
#
# BEHAVIOR CONTRACT (owner-approved, Phase 2):
#   • Auto-installs ONLY non-interactive, non-sudo tooling (Homebrew formulae,
#     npm globals, pub get). Everything is verified after install.
#   • NEVER performs interactive / sudo / login actions silently. The Homebrew
#     installer, Xcode Command Line Tools, Java (sudo cask), Firebase login and
#     FlutterFire configuration are SURFACED as manual commands (printed at the
#     end) — never run behind your back.
#   • Does NOT modify application source. It MAY generate gitignored Dart files
#     (build_runner / gen-l10n) that are required before `flutter analyze`/test.
#   • Exits NON-ZERO if any CRITICAL dependency is missing so that
#     `./setup.sh && ./start.sh` halts before starting a broken system.
#
# Usage:  ./setup.sh
# Re-run: safe — every step is idempotent.
# ============================================================================
set -uo pipefail

# ── Paths ───────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$REPO_ROOT/python_services"
VENV_DIR="$PY_DIR/.venv"
FLUTTER_DIR="$REPO_ROOT/flutter_app"
FUNCTIONS_DIR="$REPO_ROOT/firebase/functions"
ADMIN_DIR="$REPO_ROOT/admin_panel"

# ── Pinned versions (must match the toolchain in CLAUDE.md / ADRs) ───────────
PYTHON_SERIES="3.11"
NODE_MAJOR="20"
FLUTTER_MIN="3.10.0"

# ── Colors (only when stdout is a TTY) ───────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RST="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[34m')"
else
  BOLD=""; DIM=""; RST=""; RED=""; GRN=""; YLW=""; BLU=""
fi

# ── State collectors ─────────────────────────────────────────────────────────
declare -a MISSING_CRITICAL=()   # blocks: setup exits non-zero
declare -a MANUAL_STEPS=()       # commands the user must run themselves
declare -a WARNINGS=()           # non-blocking notes
declare -a SUMMARY=()            # "STATUS\tNAME\tDETAIL" for the final table

# ── Output helpers ───────────────────────────────────────────────────────────
step()  { printf '\n%s%s▶ %s%s\n' "$BOLD" "$BLU" "$1" "$RST"; }
ok()    { printf '  %s✓%s %s\n' "$GRN" "$RST" "$1"; }
warn()  { printf '  %s!%s %s\n' "$YLW" "$RST" "$1"; WARNINGS+=("$1"); }
errln() { printf '  %s✗%s %s\n' "$RED" "$RST" "$1"; }
info()  { printf '  %s%s%s\n' "$DIM" "$1" "$RST"; }
manual(){ printf '  %s→ manual:%s %s\n' "$YLW" "$RST" "$1"; MANUAL_STEPS+=("$1"); }
critical(){ errln "$1"; MISSING_CRITICAL+=("$1"); }
have()  { command -v "$1" >/dev/null 2>&1; }
add_row(){ SUMMARY+=("$1"$'\t'"$2"$'\t'"$3"); }   # status, name, detail

# Locate Homebrew even when its bin dir is not on PATH (e.g. non-login shells),
# then load its environment so `brew` and brew-installed tools resolve for the
# rest of this script. Avoids falsely reporting Homebrew as "missing".
find_brew(){
  command -v brew 2>/dev/null && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { echo "$b"; return 0; }
  done
  return 1
}
if BREW_BIN="$(find_brew)"; then
  eval "$("$BREW_BIN" shellenv)" 2>/dev/null || export PATH="$(dirname "$BREW_BIN"):$PATH"
fi

# ============================================================================
# 1. OS + architecture
# ============================================================================
step "1/19  Operating system & architecture"
OS="$(uname -s)"
ARCH="$(uname -m)"
if [[ "$OS" != "Darwin" ]]; then
  critical "This setup targets macOS (Darwin); detected '$OS'. See docs for Linux."
  add_row "FAIL" "OS" "$OS (expected Darwin)"
else
  ok "macOS ($OS) on $ARCH"
  add_row "OK" "OS" "macOS $ARCH"
fi
if [[ "$ARCH" == "arm64" ]]; then
  DEFAULT_BREW_PREFIX="/opt/homebrew"
else
  DEFAULT_BREW_PREFIX="/usr/local"
fi

# ============================================================================
# 2. Xcode Command Line Tools + Git  (git is required; CLT install is manual)
# ============================================================================
step "2/19  Xcode Command Line Tools & Git"
if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools present ($(xcode-select -p))"
  add_row "OK" "Xcode CLT" "installed"
else
  warn "Xcode Command Line Tools not detected."
  manual "xcode-select --install    # interactive GUI installer — run this yourself"
  add_row "MANUAL" "Xcode CLT" "run: xcode-select --install"
fi
if have git; then
  ok "git $(git --version | awk '{print $3}')"
  add_row "OK" "git" "$(git --version | awk '{print $3}')"
else
  critical "git not found (usually provided by Xcode CLT above)."
  add_row "FAIL" "git" "missing"
fi

# ============================================================================
# 3. Homebrew  (installer is interactive/sudo → surfaced as manual if missing)
# ============================================================================
step "3/19  Homebrew"
if have brew; then
  BREW_PREFIX="$(brew --prefix)"
  ok "Homebrew present at $BREW_PREFIX"
  add_row "OK" "Homebrew" "$BREW_PREFIX"
else
  BREW_PREFIX="$DEFAULT_BREW_PREFIX"
  critical "Homebrew not found."
  manual '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # interactive — run yourself, then re-run ./setup.sh'
  add_row "FAIL" "Homebrew" "run official installer, then re-run setup"
fi

# Helper: idempotent brew formula install (only if brew exists)
brew_ensure() {  # $1 = formula, $2 = human name
  local formula="$1" name="$2"
  have brew || { warn "Skipping $name — Homebrew unavailable"; return 1; }
  if brew list --formula "$formula" >/dev/null 2>&1; then
    return 0
  fi
  info "Installing $name via Homebrew ($formula)…"
  brew install "$formula"
}

# ============================================================================
# 4. Python 3.11
# ============================================================================
step "4/19  Python $PYTHON_SERIES"
PY311=""
if have "python$PYTHON_SERIES"; then
  PY311="$(command -v "python$PYTHON_SERIES")"
elif have brew && [[ -x "$(brew --prefix)/opt/python@$PYTHON_SERIES/bin/python$PYTHON_SERIES" ]]; then
  PY311="$(brew --prefix)/opt/python@$PYTHON_SERIES/bin/python$PYTHON_SERIES"
fi
if [[ -z "$PY311" ]]; then
  if brew_ensure "python@$PYTHON_SERIES" "Python $PYTHON_SERIES"; then
    PY311="$(brew --prefix)/opt/python@$PYTHON_SERIES/bin/python$PYTHON_SERIES"
  fi
fi
if [[ -n "$PY311" && -x "$PY311" ]]; then
  ok "Python $("$PY311" --version 2>&1 | awk '{print $2}')  ($PY311)"
  add_row "OK" "Python $PYTHON_SERIES" "$("$PY311" --version 2>&1 | awk '{print $2}')"
else
  critical "Python $PYTHON_SERIES not available."
  add_row "FAIL" "Python $PYTHON_SERIES" "missing"
fi

# ============================================================================
# 5. Python virtualenv (.venv) — reuse if valid, else (re)create
# ============================================================================
step "5/19  Python virtualenv ($VENV_DIR)"
if [[ -x "$VENV_DIR/bin/python" ]]; then
  VENV_VER="$("$VENV_DIR/bin/python" --version 2>&1 | awk '{print $2}')"
  if [[ "$VENV_VER" == $PYTHON_SERIES.* ]]; then
    ok "Reusing existing .venv (Python $VENV_VER)"
    add_row "OK" ".venv" "reused ($VENV_VER)"
  else
    warn "Existing .venv is Python $VENV_VER (want $PYTHON_SERIES.x) — recreating."
    rm -rf "$VENV_DIR"
  fi
fi
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  if [[ -n "$PY311" && -x "$PY311" ]]; then
    info "Creating virtualenv with $PY311…"
    if "$PY311" -m venv "$VENV_DIR"; then
      ok "Created .venv ($("$VENV_DIR/bin/python" --version 2>&1 | awk '{print $2}'))"
      add_row "OK" ".venv" "created"
    else
      critical "Failed to create virtualenv at $VENV_DIR"
      add_row "FAIL" ".venv" "creation failed"
    fi
  else
    critical "Cannot create .venv — Python $PYTHON_SERIES unavailable."
    add_row "FAIL" ".venv" "no interpreter"
  fi
fi

# ============================================================================
# 6. Python dependencies
# ============================================================================
step "6/19  Python dependencies (requirements.txt)"
if [[ -x "$VENV_DIR/bin/pip" ]]; then
  info "Upgrading pip…"
  "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip
  info "Installing requirements (this can take a minute)…"
  if "$VENV_DIR/bin/pip" install --quiet -r "$PY_DIR/requirements.txt"; then
    if "$VENV_DIR/bin/python" -c "import fastapi, uvicorn, firebase_admin" >/dev/null 2>&1; then
      ok "Requirements installed & import-verified (fastapi, uvicorn, firebase_admin)"
      add_row "OK" "Python deps" "installed + verified"
    else
      critical "Requirements installed but core imports failed."
      add_row "FAIL" "Python deps" "import check failed"
    fi
  else
    critical "pip install -r requirements.txt failed."
    add_row "FAIL" "Python deps" "pip install failed"
  fi
else
  critical "No .venv/bin/pip — cannot install Python deps."
  add_row "FAIL" "Python deps" "no venv pip"
fi

# ============================================================================
# 7. Node 20 LTS   (node@20 is keg-only → add its bin to PATH for this session)
# ============================================================================
step "7/19  Node.js $NODE_MAJOR LTS"
NODE_BIN=""
if have node && node -v 2>/dev/null | grep -q "^v${NODE_MAJOR}\."; then
  NODE_BIN="$(dirname "$(command -v node)")"
  ok "node $(node -v) already on PATH"
  add_row "OK" "Node" "$(node -v)"
else
  if brew_ensure "node@$NODE_MAJOR" "Node $NODE_MAJOR"; then
    NODE_BIN="$(brew --prefix)/opt/node@$NODE_MAJOR/bin"
    if [[ -x "$NODE_BIN/node" ]]; then
      ok "node $("$NODE_BIN/node" -v) installed (keg-only)"
      warn "node@$NODE_MAJOR is keg-only. To use it in new shells add to your profile:"
      manual "echo 'export PATH=\"$NODE_BIN:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
      add_row "OK" "Node" "$("$NODE_BIN/node" -v) (keg-only)"
    else
      critical "node@$NODE_MAJOR install did not produce a node binary."
      add_row "FAIL" "Node" "install failed"
    fi
  else
    if have node; then
      warn "Found node $(node -v) but not v${NODE_MAJOR}.x — functions target Node $NODE_MAJOR."
      NODE_BIN="$(dirname "$(command -v node)")"
      add_row "WARN" "Node" "$(node -v) (want ${NODE_MAJOR}.x)"
    else
      critical "Node $NODE_MAJOR unavailable."
      add_row "FAIL" "Node" "missing"
    fi
  fi
fi
# Make node/npm from this step visible to the rest of the script.
[[ -n "$NODE_BIN" ]] && export PATH="$NODE_BIN:$PATH"

# ============================================================================
# 8. Firebase CLI
# ============================================================================
step "8/19  Firebase CLI"
if have firebase; then
  ok "firebase-tools $(firebase --version 2>/dev/null)"
  add_row "OK" "Firebase CLI" "$(firebase --version 2>/dev/null)"
elif have npm; then
  info "Installing firebase-tools globally via npm…"
  if npm install -g firebase-tools >/dev/null 2>&1 && have firebase; then
    ok "firebase-tools $(firebase --version 2>/dev/null) installed"
    add_row "OK" "Firebase CLI" "$(firebase --version 2>/dev/null)"
  else
    warn "Global npm install of firebase-tools failed (permissions?)."
    manual "npm install -g firebase-tools    # may need a writable npm prefix; see 'npm config get prefix'"
    add_row "MANUAL" "Firebase CLI" "install firebase-tools"
  fi
else
  critical "npm unavailable — cannot install Firebase CLI."
  add_row "FAIL" "Firebase CLI" "no npm"
fi

# ============================================================================
# 9. Cloud Functions dependencies (Node 20, generates package-lock.json — ADR-006)
# ============================================================================
step "9/19  Cloud Functions dependencies"
if have npm && [[ -f "$FUNCTIONS_DIR/package.json" ]]; then
  if ( cd "$FUNCTIONS_DIR" && { [[ -f package-lock.json ]] && npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1; } ); then
    ( cd "$FUNCTIONS_DIR" && npx tsc --noEmit >/dev/null 2>&1 ) \
      && ok "Functions deps installed; tsc --noEmit passed" \
      || warn "Functions deps installed but 'tsc --noEmit' reported issues (inspect manually)."
    add_row "OK" "Functions deps" "installed"
  else
    critical "npm install for firebase/functions failed."
    add_row "FAIL" "Functions deps" "install failed"
  fi
else
  warn "Skipping Functions deps (npm or package.json unavailable)."
  add_row "WARN" "Functions deps" "skipped"
fi

# ============================================================================
# 10. Admin Panel dependencies (minimal scaffolding)
# ============================================================================
step "10/19  Admin Panel dependencies"
if [[ -f "$ADMIN_DIR/package.json" ]] && have npm; then
  ( cd "$ADMIN_DIR" && npm install >/dev/null 2>&1 ) \
    && ok "Admin panel deps installed" || warn "Admin panel npm install reported issues (non-blocking; it is a static SPA)."
  add_row "OK" "Admin deps" "installed"
else
  info "Admin panel is a static single-file SPA — no build step required."
  add_row "OK" "Admin deps" "static (n/a)"
fi

# ============================================================================
# 11. Flutter toolchain + project deps + codegen
# ============================================================================
step "11/19  Flutter"
if have flutter; then
  FLUTTER_VER="$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
  ok "Flutter $FLUTTER_VER"
  add_row "OK" "Flutter" "$FLUTTER_VER"
  info "flutter pub get…"
  ( cd "$FLUTTER_DIR" && flutter pub get >/dev/null 2>&1 ) && ok "pub get complete" || warn "flutter pub get reported issues."
  info "build_runner (generates gitignored *.freezed.dart / *.g.dart)…"
  ( cd "$FLUTTER_DIR" && dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1 ) \
    && ok "Codegen complete" || warn "build_runner reported issues (run manually to see output)."
  info "flutter gen-l10n…"
  ( cd "$FLUTTER_DIR" && flutter gen-l10n >/dev/null 2>&1 ) && ok "Localizations generated" || warn "gen-l10n reported issues."
else
  critical "Flutter not found."
  manual "brew install --cask flutter    # (large download) — or https://docs.flutter.dev/get-started/install/macos"
  add_row "FAIL" "Flutter" "missing"
fi

# ============================================================================
# 12. Java (Firebase emulators + Android) — sudo cask → manual if missing
# ============================================================================
step "12/19  Java (JDK)"
if have java && java -version >/dev/null 2>&1; then
  jver="$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')"
  if [[ "$jver" =~ ^[0-9]+$ ]] && [ "$jver" -ge 21 ]; then
    ok "Java $jver (>=21)"
    add_row "OK" "Java" "$jver"
  else
    warn "Java $jver found, but Firebase emulators require JDK 21+."
    manual "brew install --cask temurin@21    # then: export JAVA_HOME=\$(/usr/libexec/java_home -v 21)"
    add_row "MANUAL" "Java" "upgrade to JDK 21+"
  fi
else
  warn "Java not found — required by Firebase emulators (JDK 21+) and Android builds."
  manual "brew install --cask temurin@21    # installs JDK 21 (may prompt for your password)"
  add_row "MANUAL" "Java" "install JDK 21+"
fi

# ============================================================================
# 13. Google Chrome (Flutter web + emulator UI)
# ============================================================================
step "13/19  Google Chrome"
if [[ -d "/Applications/Google Chrome.app" ]] || have google-chrome || have chromium; then
  ok "Chrome/Chromium available"
  add_row "OK" "Chrome" "present"
else
  warn "Google Chrome not detected (needed for Flutter web + emulator UI)."
  manual "brew install --cask google-chrome"
  add_row "MANUAL" "Chrome" "install Google Chrome"
fi

# ============================================================================
# 14. .env bootstrap (never overwrite an existing one)
# ============================================================================
step "14/19  Environment file (.env)"
if [[ -f "$REPO_ROOT/.env" ]]; then
  ok ".env already present (left untouched)"
  add_row "OK" ".env" "present"
elif [[ -f "$REPO_ROOT/.env.example" ]]; then
  cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
  ok "Created .env from .env.example"
  warn "Fill in real values in .env before running against live services (it is git-ignored)."
  add_row "OK" ".env" "created from example"
else
  critical ".env.example missing — cannot bootstrap .env."
  add_row "FAIL" ".env" "no template"
fi

# ============================================================================
# 15. Firebase client config sanity (placeholder detection — B2/B3)
# ============================================================================
step "15/19  Firebase client configuration"
FOPTS="$FLUTTER_DIR/lib/firebase_options.dart"
if [[ -f "$FOPTS" ]] && grep -q "REPLACE_WITH" "$FOPTS" 2>/dev/null; then
  warn "flutter_app/lib/firebase_options.dart still contains placeholders — the client cannot reach Firebase."
  manual "cd flutter_app && flutterfire configure --project=<your-firebase-project>    # needs Firebase login"
  add_row "MANUAL" "Firebase config" "run flutterfire configure"
elif [[ -f "$FOPTS" ]]; then
  ok "firebase_options.dart has no placeholders"
  add_row "OK" "Firebase config" "configured"
else
  warn "firebase_options.dart not found."
  add_row "WARN" "Firebase config" "missing file"
fi

# ============================================================================
# 16. flutter doctor (diagnostics only)
# ============================================================================
step "16/19  flutter doctor"
if have flutter; then
  flutter doctor 2>/dev/null | sed 's/^/    /' || true
  add_row "OK" "flutter doctor" "ran (see above)"
else
  info "Skipped — Flutter not installed."
  add_row "WARN" "flutter doctor" "skipped"
fi

# ============================================================================
# 17. Firebase login status (never auto-login)
# ============================================================================
step "17/19  Firebase authentication"
if have firebase; then
  if firebase login:list 2>/dev/null | grep -qiE "logged in|@"; then
    ok "Firebase CLI is logged in"
    add_row "OK" "Firebase login" "authenticated"
  else
    warn "Firebase CLI is not logged in."
    manual "! firebase login        # interactive browser login — run this in your shell"
    add_row "MANUAL" "Firebase login" "run: firebase login"
  fi
else
  info "Skipped — Firebase CLI unavailable."
  add_row "WARN" "Firebase login" "skipped"
fi

# ============================================================================
# 18. Firebase emulator availability
# ============================================================================
step "18/19  Firebase emulators"
if [[ -d "$HOME/.cache/firebase/emulators" ]] && ls "$HOME/.cache/firebase/emulators"/*.jar >/dev/null 2>&1; then
  ok "Emulator jars cached"
  add_row "OK" "Emulators" "cached"
else
  info "Emulator jars not cached — they download on first 'firebase emulators:start' (needs Java)."
  manual "firebase setup:emulators:firestore && firebase setup:emulators:storage    # optional: pre-download emulator jars"
  add_row "WARN" "Emulators" "download on first run"
fi
# Optional OCR runtime deps (feature-flagged engines — ADR-016/019)
if ! have tesseract || ! have pdftoppm; then
  info "Optional OCR/PDF runtime deps not fully present (only needed for the OCR parser layer)."
  manual "brew install tesseract poppler    # optional: enables the OCR fallback + pdf2image"
fi

# ============================================================================
# 19. Summary (doctor-style table) + fail-fast exit
# ============================================================================
step "19/19  Summary"
printf '\n  %-18s %-8s %s\n' "COMPONENT" "STATUS" "DETAIL"
printf '  %-18s %-8s %s\n' "─────────" "──────" "──────"
for row in "${SUMMARY[@]}"; do
  IFS=$'\t' read -r st name detail <<<"$row"
  case "$st" in
    OK)     color="$GRN" ;;
    WARN)   color="$YLW" ;;
    MANUAL) color="$YLW" ;;
    *)      color="$RED" ;;
  esac
  printf '  %-18s %s%-8s%s %s\n' "$name" "$color" "$st" "$RST" "$detail"
done

if [[ ${#MANUAL_STEPS[@]} -gt 0 ]]; then
  printf '\n%s%s Manual steps for you to run:%s\n' "$BOLD" "$YLW" "$RST"
  for m in "${MANUAL_STEPS[@]}"; do printf '  • %s\n' "$m"; done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  printf '\n%s%s Warnings:%s\n' "$BOLD" "$YLW" "$RST"
  for w in "${WARNINGS[@]}"; do printf '  • %s\n' "$w"; done
fi

echo
if [[ ${#MISSING_CRITICAL[@]} -gt 0 ]]; then
  printf '%s%s✗ Setup incomplete — %d critical item(s) missing:%s\n' "$BOLD" "$RED" "${#MISSING_CRITICAL[@]}" "$RST"
  for c in "${MISSING_CRITICAL[@]}"; do printf '  • %s\n' "$c"; done
  printf '%sResolve the above (and any manual steps), then re-run ./setup.sh%s\n' "$DIM" "$RST"
  exit 1
fi

printf '%s%s✓ Environment ready.%s Next: %s./start.sh%s\n' "$BOLD" "$GRN" "$RST" "$BOLD" "$RST"
exit 0
