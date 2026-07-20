#!/usr/bin/env bash
# ============================================================================
# doctor.sh — diagnose the NAJM development environment (READ-ONLY)
#
# Implements ADR-011 (Local Development) + ADR-019 (health verification).
# Installs NOTHING and changes NOTHING — it only inspects and reports. Use it
# any time to check whether the machine is ready to run the stack.
#
# Checks: OS/arch · git · Homebrew · Python 3.11 · .venv + core imports ·
#         Node 20 · npm · Firebase CLI · Flutter · Java · Chrome · .env ·
#         Firebase client config · Firebase login · emulator jars ·
#         dev-stack port availability · running services.
#
# Exit: non-zero if any CRITICAL tool is missing (so CI / scripts can gate on it).
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$REPO_ROOT/python_services"
VENV_DIR="$PY_DIR/.venv"
FLUTTER_DIR="$REPO_ROOT/flutter_app"
RUN_DIR="$REPO_ROOT/.najm"
PYTHON_SERIES="3.11"
NODE_MAJOR="20"

# Ports the local stack uses (mirror start.sh defaults).
PYTHON_PORT="${NAJM_PYTHON_PORT:-8000}"
FLUTTER_PORT="${NAJM_FLUTTER_PORT:-3000}"
EMU_PORTS="4000 8080 9099 9199 5001"

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RST="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[34m')"
else
  BOLD=""; DIM=""; RST=""; RED=""; GRN=""; YLW=""; BLU=""
fi

declare -a SUMMARY=()          # "STATUS\tNAME\tDETAIL"
declare -a MISSING_CRITICAL=()
have(){ command -v "$1" >/dev/null 2>&1; }
row(){ SUMMARY+=("$1"$'\t'"$2"$'\t'"$3"); }        # status, name, detail
crit(){ MISSING_CRITICAL+=("$1"); }

# Locate Homebrew even when its bin dir is not on PATH (non-login shells).
find_brew(){
  command -v brew 2>/dev/null && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { echo "$b"; return 0; }
  done
  return 1
}
BREW="$(find_brew || true)"

# ── Toolchain ────────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] && row OK "OS" "macOS $(uname -m)" || { row FAIL "OS" "$(uname -s) (want Darwin)"; crit "macOS"; }

if have git; then row OK "git" "$(git --version | awk '{print $3}')"; else row FAIL "git" "missing"; crit "git"; fi

if [[ -n "$BREW" ]]; then row OK "Homebrew" "$("$BREW" --prefix)"; else row WARN "Homebrew" "not found"; fi

# .venv + core imports — checked first, because it is what the stack runs on.
VENV_OK=0
if [[ -x "$VENV_DIR/bin/python" ]]; then
  vver="$("$VENV_DIR/bin/python" --version 2>&1 | awk '{print $2}')"
  if "$VENV_DIR/bin/python" -c "import fastapi, uvicorn, firebase_admin" >/dev/null 2>&1; then
    row OK ".venv" "$vver + core deps"; VENV_OK=1
  else
    row FAIL ".venv" "$vver but core imports missing"; crit "Python deps (run ./setup.sh)"
  fi
else
  row FAIL ".venv" "not created"; crit ".venv (run ./setup.sh)"
fi

# Host Python 3.11 — needed only to (re)create .venv, so it is NOT critical
# when a healthy .venv already exists.
PY311=""
have "python$PYTHON_SERIES" && PY311="$(command -v "python$PYTHON_SERIES")"
if [[ -z "$PY311" && -n "$BREW" ]]; then
  keg="$("$BREW" --prefix 2>/dev/null)/opt/python@$PYTHON_SERIES/bin/python$PYTHON_SERIES"
  [[ -x "$keg" ]] && PY311="$keg"
fi
if [[ -n "$PY311" ]]; then
  row OK "Python $PYTHON_SERIES" "$("$PY311" --version 2>&1 | awk '{print $2}')"
elif (( VENV_OK )); then
  row WARN "Python $PYTHON_SERIES" "not on PATH (only needed to rebuild .venv)"
else
  row FAIL "Python $PYTHON_SERIES" "missing"; crit "Python $PYTHON_SERIES"
fi

# Node 20
if have node; then
  nv="$(node -v)"
  [[ "$nv" == v${NODE_MAJOR}.* ]] && row OK "Node" "$nv" || row WARN "Node" "$nv (want ${NODE_MAJOR}.x)"
else
  row FAIL "Node" "missing"; crit "Node $NODE_MAJOR"
fi
have npm && row OK "npm" "$(npm -v)" || row FAIL "npm" "missing"

have firebase && row OK "Firebase CLI" "$(firebase --version 2>/dev/null)" || { row FAIL "Firebase CLI" "missing"; crit "firebase-tools"; }

if have flutter; then row OK "Flutter" "$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"; else row FAIL "Flutter" "missing"; crit "Flutter"; fi

if have java; then
  jver="$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')"
  if [[ "$jver" =~ ^[0-9]+$ ]] && [ "$jver" -ge 21 ]; then
    row OK "Java" "$jver (>=21)"
  else
    row WARN "Java" "${jver:-?} — Firebase emulators need JDK 21+"
  fi
else
  row WARN "Java" "missing (emulators need JDK 21+)"
fi

{ [[ -d "/Applications/Google Chrome.app" ]] || have google-chrome || have chromium; } \
  && row OK "Chrome" "present" || row WARN "Chrome" "missing (web/emulator UI)"

# ── Configuration ────────────────────────────────────────────────────────────
[[ -f "$REPO_ROOT/.env" ]] && row OK ".env" "present" || row WARN ".env" "missing (run ./setup.sh)"

FOPTS="$FLUTTER_DIR/lib/firebase_options.dart"
if [[ -f "$FOPTS" ]] && grep -q "REPLACE_WITH" "$FOPTS" 2>/dev/null; then
  row WARN "Firebase config" "placeholders (run flutterfire configure)"
elif [[ -f "$FOPTS" ]]; then
  row OK "Firebase config" "configured"
else
  row WARN "Firebase config" "file missing"
fi

if have firebase; then
  firebase login:list 2>/dev/null | grep -qiE "logged in|@" \
    && row OK "Firebase login" "authenticated" || row WARN "Firebase login" "run: firebase login"
fi

if [[ -d "$HOME/.cache/firebase/emulators" ]] && ls "$HOME/.cache/firebase/emulators"/*.jar >/dev/null 2>&1; then
  row OK "Emulators" "jars cached"
else
  row WARN "Emulators" "download on first run"
fi

# ── Port availability for the dev stack ──────────────────────────────────────
port_status(){  # $1 = port
  if have lsof && lsof -iTCP:"$1" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
    local pid; pid="$(lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null | head -1)"
    echo "in use (pid ${pid:-?})"
  else
    echo "free"
  fi
}
for p in "$PYTHON_PORT" "$FLUTTER_PORT" $EMU_PORTS; do
  st="$(port_status "$p")"
  [[ "$st" == "free" ]] && row OK "port $p" "$st" || row WARN "port $p" "$st"
done

# ── Running services (from start.sh pid files) ───────────────────────────────
if [[ -d "$RUN_DIR" ]]; then
  for svc in emulators python flutter; do
    pf="$RUN_DIR/$svc.pid"
    [[ -f "$pf" ]] || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      row OK "svc:$svc" "running (pid $pid)"
    else
      row WARN "svc:$svc" "stale pid file"
    fi
  done
fi

# ── Render ───────────────────────────────────────────────────────────────────
printf '%s%s NAJM — environment doctor%s\n\n' "$BOLD" "$BLU" "$RST"
printf '  %-18s %-8s %s\n' "COMPONENT" "STATUS" "DETAIL"
printf '  %-18s %-8s %s\n' "─────────" "──────" "──────"
for r in "${SUMMARY[@]}"; do
  IFS=$'\t' read -r st name detail <<<"$r"
  case "$st" in OK) c="$GRN" ;; WARN) c="$YLW" ;; *) c="$RED" ;; esac
  printf '  %-18s %s%-8s%s %s\n' "$name" "$c" "$st" "$RST" "$detail"
done

echo
if [[ ${#MISSING_CRITICAL[@]} -gt 0 ]]; then
  printf '%s%s✗ %d critical item(s) missing:%s\n' "$BOLD" "$RED" "${#MISSING_CRITICAL[@]}" "$RST"
  for c in "${MISSING_CRITICAL[@]}"; do printf '  • %s\n' "$c"; done
  printf '%sRun ./setup.sh to resolve, then ./doctor.sh again.%s\n' "$DIM" "$RST"
  exit 1
fi
printf '%s%s✓ Environment looks healthy.%s\n' "$BOLD" "$GRN" "$RST"
exit 0
