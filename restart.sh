#!/usr/bin/env bash
# ============================================================================
# restart.sh — restart the NAJM local development stack
#
# Implements ADR-011 (Local Development). Thin orchestrator: delegates to
# ./stop.sh then ./start.sh so there is NO duplicated start/stop logic here
# (single-responsibility per the architecture rules).
#
# Usage:
#   ./restart.sh                # restart everything
#   ./restart.sh emulators      # restart only the Firebase emulators
#   ./restart.sh python         # restart only the Python backend
#   ./restart.sh flutter        # restart only the Flutter app
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT="${1:-all}"

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; RST="$(printf '\033[0m')"; BLU="$(printf '\033[34m')"
else
  BOLD=""; RST=""; BLU=""
fi

printf '%s%s NAJM — restarting local stack (%s)%s\n' "$BOLD" "$BLU" "$COMPONENT" "$RST"

# 1) Stop (never abort the restart if stop reports nothing to do).
"$REPO_ROOT/stop.sh" "$COMPONENT" || true

# 2) Brief pause so sockets/ports are released before re-binding.
sleep 2

# 3) Start — propagate its exit code (non-zero if a service is unhealthy).
exec "$REPO_ROOT/start.sh" "$COMPONENT"
