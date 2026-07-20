#!/usr/bin/env bash
# ============================================================================
# stop.sh — stop the NAJM local development stack
#
# Implements ADR-011 (Local Development). Gracefully stops every service that
# ./start.sh launched, using the pid files in ./.najm/. Process-tree aware
# (uvicorn --reload, firebase emulators/Java, flutter run all spawn children):
# sends SIGTERM to the whole tree, waits, then SIGKILL any survivors.
#
# Usage:
#   ./stop.sh                # stop everything
#   ./stop.sh emulators      # stop only the Firebase emulators
#   ./stop.sh python         # stop only the Python backend
#   ./stop.sh flutter        # stop only the Flutter app
#
# Re-run: safe — a service that is already stopped is reported, not errored.
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

pidfile(){ echo "$RUN_DIR/$1.pid"; }

# Recursively signal a process and all of its descendants (children first).
kill_tree(){  # $1 = pid, $2 = signal name (TERM/KILL)
  local pid="$1" sig="$2" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    kill_tree "$child" "$sig"
  done
  kill "-$sig" "$pid" 2>/dev/null || true
}

stop_service(){  # $1 = service name
  local name="$1" pf pid i
  pf="$(pidfile "$name")"
  if [[ ! -f "$pf" ]]; then
    info "$name — not tracked (no pid file)"
    return 0
  fi
  pid="$(cat "$pf" 2>/dev/null || true)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    info "$name — already stopped (removing stale pid file)"
    rm -f "$pf"
    return 0
  fi

  # Graceful: SIGTERM the whole tree, wait up to 10s.
  kill_tree "$pid" TERM
  for i in $(seq 1 10); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  # Force: SIGKILL any survivor.
  if kill -0 "$pid" 2>/dev/null; then
    warn "$name did not exit on SIGTERM — sending SIGKILL"
    kill_tree "$pid" KILL
    sleep 1
  fi

  if kill -0 "$pid" 2>/dev/null; then
    warn "$name (pid $pid) may still be running — inspect manually"
  else
    ok "Stopped $name (pid $pid)"
    rm -f "$pf"
  fi
}

COMPONENT="${1:-all}"
printf '%s%s NAJM — stopping local stack (%s)%s\n' "$BOLD" "$BLU" "$COMPONENT" "$RST"

if [[ ! -d "$RUN_DIR" ]]; then
  info "No .najm/ runtime dir — nothing to stop."
  exit 0
fi

step "Stopping services"
case "$COMPONENT" in
  # Stop in reverse start order: app → backend → emulators.
  all)        stop_service flutter; stop_service python; stop_service emulators ;;
  emulators)  stop_service emulators ;;
  python)     stop_service python ;;
  flutter)    stop_service flutter ;;
  *) printf '  %s✗%s Unknown component "%s" (use: all | emulators | python | flutter)\n' "$RED" "$RST" "$COMPONENT"; exit 2 ;;
esac

# If everything is down, note that logs remain for inspection.
remaining=$(find "$RUN_DIR" -name '*.pid' 2>/dev/null | wc -l | tr -d ' ')
echo
if [[ "$remaining" == "0" ]]; then
  printf '%s%s✓ Local stack stopped.%s Logs kept in %s (clear with ./clean.sh)\n' "$BOLD" "$GRN" "$RST" "$RUN_DIR"
else
  printf '%s%s✓ Requested services stopped.%s %s pid file(s) still tracked.\n' "$BOLD" "$GRN" "$RST" "$remaining"
fi
exit 0
