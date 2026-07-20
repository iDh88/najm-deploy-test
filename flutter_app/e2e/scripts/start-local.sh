#!/usr/bin/env bash
set -euo pipefail

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$(cd "$E2E_DIR/.." && pwd)"
REPO_DIR="$(cd "$FLUTTER_DIR/.." && pwd)"

cleanup() {
  if [[ -n "${HEALTH_PID:-}" ]]; then
    kill "$HEALTH_PID" 2>/dev/null || true
    wait "$HEALTH_PID" 2>/dev/null || true
  fi
  if [[ -n "${FLUTTER_PID:-}" ]]; then
    kill "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
  if [[ -n "${PYTHON_PID:-}" ]]; then
    kill "$PYTHON_PID" 2>/dev/null || true
    wait "$PYTHON_PID" 2>/dev/null || true
  fi
  if [[ -n "${FIREBASE_PID:-}" ]]; then
    kill "$FIREBASE_PID" 2>/dev/null || true
    wait "$FIREBASE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "$REPO_DIR/firebase"
# Prefer a Temurin 21 JDK if present (emulators need Java); otherwise rely on PATH.
JDK_BIN=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/bin
[[ -d "$JDK_BIN" ]] && PATH="$JDK_BIN:$PATH"
firebase emulators:start --only auth,firestore,storage --project demo-najm &
FIREBASE_PID=$!

for port in 9099 8080 9199; do
  for _ in $(seq 1 60); do
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1 && break
    sleep 1
  done
  nc -z 127.0.0.1 "$port"
done

cd "$REPO_DIR/python_services"
env \
  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
  GOOGLE_CLOUD_PROJECT=demo-najm \
  GCLOUD_PROJECT=demo-najm \
  INTERNAL_SERVICE_TOKEN=dev-local-token \
  ALLOWED_ORIGINS=http://127.0.0.1:3000 \
  "$REPO_DIR/python_services/.venv/bin/uvicorn" main:app \
    --host 127.0.0.1 --port 8000 &
PYTHON_PID=$!
for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS http://127.0.0.1:8000/health >/dev/null

cd "$FLUTTER_DIR"
flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 3000 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=AI_SERVICE_URL=http://127.0.0.1:8000 &
FLUTTER_PID=$!

for _ in $(seq 1 180); do
  if nc -z 127.0.0.1 3000 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
nc -z 127.0.0.1 3000
# The Flutter debug server opens its socket before the first Dart compilation
# finishes. Allow that initial compile to complete before releasing Playwright.
sleep 20
kill -0 "$FLUTTER_PID"

python3 -m http.server 3999 --bind 127.0.0.1 --directory "$E2E_DIR/scripts" &
HEALTH_PID=$!
wait "$FLUTTER_PID"
