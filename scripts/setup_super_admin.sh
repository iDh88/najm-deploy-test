#!/bin/bash
echo "🚀 CIP Super Admin Setup"
echo "========================"
echo ""
echo "Step 1: Make sure you signed up in the app with: NajmAssistance@gmail.com"
read -p "Have you signed up? (y/n): " done
if [ "$done" != "y" ]; then echo "Sign up first then run again."; exit 1; fi

ADMIN_SETUP_TOKEN=$(grep ADMIN_SETUP_TOKEN ../.env 2>/dev/null | cut -d= -f2)
FIREBASE_PROJECT=$(grep FIREBASE_PROJECT_ID ../.env 2>/dev/null | cut -d= -f2)
REGION="us-central1"
URL="https://${REGION}-${FIREBASE_PROJECT}.cloudfunctions.net/initSuperAdmin"

echo "Calling: $URL"
RESPONSE=$(curl -s -X POST "$URL" -H "x-admin-setup-token: $ADMIN_SETUP_TOKEN")
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"success":true'; then
  echo ""
  echo "✅ Super admin activated for NajmAssistance@gmail.com"
  echo "   Sign in to your admin panel and start approving users."
else
  echo "❌ Failed. Check Firebase Functions logs."
fi
