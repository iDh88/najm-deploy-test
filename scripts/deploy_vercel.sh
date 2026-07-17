#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../flutter_app"

flutter build web --release --dart-define=AI_SERVICE_URL=https://najm-dev.vercel.app/api

mkdir -p build/web/api
cp -R ../vercel_api/api/* build/web/api/

cd build/web
vercel --prod
