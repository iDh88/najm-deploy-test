#!/usr/bin/env bash
# ============================================================================
# start.sh — NAJM local development orchestrator
#
# Implements ADR-011 (Local Development). Starts the local stack, health-checks
# every service, retries failures, and prints all URLs — colored.
#
#   Services (credential-free, emulator-backed):
#     • Firebase emulators : Firestore, Auth, Storage, Functions  (demo project)
#     • Python backend     : uvicorn (FastAPI) wired to the emulators
#     • Flutter app        : web-server, AI_SERVICE_URL → local Python
#
# Usage:
#   ./start.sh                 # start everything
#   ./start.sh emulators       # start only the Firebase emulators
#   ./start.sh python          # start only the Python backend
#   ./start.sh flutter         # start only the Flutter app
#
# State (pids + logs) lives in ./.najm/ (git-ignored). Stop with ./stop.sh
# Re-run: safe — a service already running is health-checked, not double-started.
# ============================================================================
set -uo pipefail

# ── Paths ───────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$REPO_ROOT/python_services"
VENV_DIR="$PY_DIR/.venv"
FLUTTER_DIR="$REPO_ROOT/flutter_app"
FIREBASE_DIR="$REPO_ROOT/firebase"
RUN_DIR="$REPO_ROOT/.najm"
mkdir -p "$RUN_DIR"

# ── Config (override via environment) ────────────────────────────────────────
PROJECT_ID="${NAJM_PROJECT_ID:-demo-najm}"   # 'demo-*' = offline emulator project, no real creds
PYTHON_PORT="${NAJM_PYTHON_PORT:-8000}"
FLUTTER_PORT="${NAJM_FLUTTER_PORT:-3000}"
EMU_UI_PORT="${NAJM_EMU_UI_PORT:-4000}"
EMU_FIRESTORE_PORT="${NAJM_EMU_FIRESTORE_PORT:-8080}"
EMU_AUTH_PORT="${NAJM_EMU_AUTH_PORT:-9099}"
EMU_STORAGE_PORT="${NAJM_EMU_STORAGE_PORT:-9199}"
EMU_FUNCTIONS_PORT="${NAJM_EMU_FUNCTIONS_PORT:-5001}"
HEALTH_RETRIES="${NAJM_HEALTH_RETRIES:-40}"

# ── Colors ───────────────────────────────────────────────────────────────────
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

# ── Process helpers (pid files in .najm/) ────────────────────────────────────
pidfile(){ echo "$RUN_DIR/$1.pid"; }
logfile(){ echo "$RUN_DIR/$1.log"; }

is_running(){  # $1 = service name
  local pf; pf="$(pidfile "$1")"
  [[ -f "$pf" ]] || return 1
  local pid; pid="$(cat "$pf" 2>/dev/null)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Health poll with retry; returns 0 when URL responds, 1 otherwise.
wait_health(){  # $1 = url, $2 = name, $3 = retries
  local url="$1" name="$2" retries="${3:-$HEALTH_RETRIES}" i=1
  while (( i <= retries )); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then
      ok "$name healthy  ($url)"; return 0
    fi
    sleep 1; (( i++ ))
  done
  errln "$name did not become healthy after ${retries}s  ($url)"
  info "last log lines ($(logfile "$name")):"
  tail -n 8 "$(logfile "$name")" 2>/dev/null | sed 's/^/      /'
  FAILED=1; return 1
}

# ── Preflight: did setup.sh run? ─────────────────────────────────────────────
preflight(){
  step "Preflight"
  local bad=0
  [[ -x "$VENV_DIR/bin/uvicorn" ]] || { errln "Python venv/uvicorn missing"; bad=1; }
  have flutter  || { errln "flutter not found on PATH"; bad=1; }
  have firebase || { errln "firebase CLI not found on PATH"; bad=1; }
  if (( bad )); then
    warn "Environment not ready — run ${BOLD}./setup.sh${RST} first."
    exit 1
  fi
  ok "Toolchain present (venv, flutter, firebase)"
  # Load local secrets/env for the backend (dev values only; .env is git-ignored).
  if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a; # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"; set +a
    ok "Loaded .env"
  else
    warn "No .env found — backend may refuse to start without INTERNAL_SERVICE_TOKEN (run ./setup.sh)."
  fi
}

# ── Start: Firebase emulators ────────────────────────────────────────────────
start_emulators(){
  step "Firebase emulators"
  if is_running emulators; then ok "Already running (pid $(cat "$(pidfile emulators)"))"; else
    info "Launching Firestore/Auth/Storage/Functions on project '$PROJECT_ID'…"
    ( cd "$FIREBASE_DIR" && exec firebase emulators:start \
        --only firestore,auth,storage,functions \
        --project "$PROJECT_ID" ) > "$(logfile emulators)" 2>&1 &
    echo $! > "$(pidfile emulators)"
  fi
  wait_health "http://localhost:${EMU_UI_PORT}/" "emulators" || \
    wait_health "http://localhost:${EMU_FIRESTORE_PORT}/" "emulators" 5
}

# ── Start: Python backend (wired to emulators) ───────────────────────────────
start_python(){
  step "Python backend (uvicorn)"
  if is_running python; then ok "Already running (pid $(cat "$(pidfile python)"))"; else
    # Point firebase-admin at the local emulators — no real credentials needed.
    export FIRESTORE_EMULATOR_HOST="localhost:${EMU_FIRESTORE_PORT}"
    export FIREBASE_AUTH_EMULATOR_HOST="localhost:${EMU_AUTH_PORT}"
    export FIREBASE_STORAGE_EMULATOR_HOST="localhost:${EMU_STORAGE_PORT}"
    export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
    export GCLOUD_PROJECT="$PROJECT_ID"
    export INTERNAL_SERVICE_TOKEN="${INTERNAL_SERVICE_TOKEN:-dev-local-token}"
    info "uvicorn main:app on :${PYTHON_PORT} (emulator-backed)…"
    ( cd "$PY_DIR" && exec "$VENV_DIR/bin/uvicorn" main:app \
        --host 0.0.0.0 --port "$PYTHON_PORT" --reload ) > "$(logfile python)" 2>&1 &
    echo $! > "$(pidfile python)"
  fi
  wait_health "http://localhost:${PYTHON_PORT}/health" "python"
}

# ── Start: Flutter app (web-server) ──────────────────────────────────────────
start_flutter(){
  step "Flutter app (web)"
  if is_running flutter; then ok "Already running (pid $(cat "$(pidfile flutter)"))"; else
    info "flutter run -d web-server on :${FLUTTER_PORT} (AI_SERVICE_URL → local Python)…"
    ( cd "$FLUTTER_DIR" && exec flutter run -d web-server \
        --web-hostname localhost --web-port "$FLUTTER_PORT" \
        --dart-define=AI_SERVICE_URL="http://localhost:${PYTHON_PORT}" \
      ) > "$(logfile flutter)" 2>&1 &
    echo $! > "$(pidfile flutter)"
  fi
  # Flutter web compile is slower — give it more attempts.
  wait_health "http://localhost:${FLUTTER_PORT}/" "flutter" $(( HEALTH_RETRIES * 3 ))
}

# ── URL summary ──────────────────────────────────────────────────────────────
summary(){
  step "URLs"
  printf '  %-22s %s\n' "Flutter app"        "http://localhost:${FLUTTER_PORT}/"
  printf '  %-22s %s\n' "Python API"          "http://localhost:${PYTHON_PORT}/  (health: /health, docs: /docs)"
  printf '  %-22s %s\n' "Emulator UI"         "http://localhost:${EMU_UI_PORT}/"
  printf '  %-22s %s\n' "Firestore emulator"  "localhost:${EMU_FIRESTORE_PORT}"
  printf '  %-22s %s\n' "Auth emulator"       "localhost:${EMU_AUTH_PORT}"
  printf '  %-22s %s\n' "Storage emulator"    "localhost:${EMU_STORAGE_PORT}"
  printf '  %-22s %s\n' "Functions emulator"  "localhost:${EMU_FUNCTIONS_PORT}"
  echo
  info "Logs: $RUN_DIR/<service>.log   ·   Stop everything: ./stop.sh"
  # Honest limitation notes (not failures):
  if grep -q "REPLACE_WITH" "$FLUTTER_DIR/lib/firebase_options.dart" 2>/dev/null; then
    warn "flutter_app firebase_options.dart has placeholders — the web app boots but Firebase Auth/Firestore"
    info "   from the client won't work until 'flutterfire configure' (or local emulator wiring) is done."
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
COMPONENT="${1:-all}"
printf '%s%s NAJM — starting local stack (%s)%s\n' "$BOLD" "$BLU" "$COMPONENT" "$RST"
preflight
case "$COMPONENT" in
  all)        start_emulators; start_python; start_flutter; summary ;;
  emulators)  start_emulators ;;
  python)     start_python ;;
  flutter)    start_flutter ;;
  *) errln "Unknown component '$COMPONENT' (use: all | emulators | python | flutter)"; exit 2 ;;
esac

echo
if (( FAILED )); then
  printf '%s%s✗ One or more services are unhealthy — see logs in %s%s\n' "$BOLD" "$RED" "$RUN_DIR" "$RST"
  exit 1
fi
printf '%s%s✓ Local stack is up.%s  Stop with %s./stop.sh%s\n' "$BOLD" "$GRN" "$RST" "$BOLD" "$RST"
exit 0
