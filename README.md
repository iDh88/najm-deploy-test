# ⭐ Crew Intelligence Platform (CIP) — Najm / نجم

> An unofficial, intelligent scheduling assistant for Saudi Airlines cabin crew.  
> Built with Flutter · Firebase · Python · Claude AI

---

## ⚠️ Disclaimer

**CIP is NOT affiliated with Saudi Arabian Airlines Corporation (Saudia) or any airline.**  
This is an independent tool. All data is user-supplied. Always verify schedules through official channels.

---

## 📦 Repository Structure

```
crew-intelligence-platform/
├── flutter_app/                 # iOS & Android app (Flutter 3.x)
│   ├── lib/
│   │   ├── app/                 # Router, theme, app root
│   │   ├── core/                # Auth, models, repositories, services
│   │   ├── features/            # Screens: home, lines, bids, trades, assistant...
│   │   └── shared/              # Widgets, l10n (AR+EN), constants
│   ├── test/                    # Unit and widget tests
│   └── pubspec.yaml
├── python_services/             # AI microservices (FastAPI on Cloud Run)
│   ├── parser/                  # Excel roster parser
│   ├── legality/                # GACA/ICAO FTL rules engine
│   ├── ai/                      # NLP router + Claude integration
│   ├── ranking/                 # Smart line scoring engine
│   ├── auto_bid/                # Preference learning + auto-bid
│   ├── utils/                   # Firebase admin, auth middleware
│   └── tests/                   # 60+ unit tests
├── firebase/
│   ├── firestore.rules          # Security rules
│   ├── firestore.indexes.json   # Composite indexes
│   └── functions/               # Node.js Cloud Functions (TypeScript)
├── docs/
│   ├── openapi.yaml             # Full API specification
│   ├── cost-model.md            # Infrastructure cost projections
│   ├── devops-runbook.md        # Operations and incident response
│   └── legal.md                 # Privacy policy + Terms of service
└── .github/workflows/
    └── deploy.yml               # CI/CD pipeline
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | 3.19+ |
| Dart | 3.3+ |
| Python | 3.11+ |
| Node.js | 18+ |
| Firebase CLI | 13+ |
| Google Cloud SDK | Latest |
| Docker | Latest |

### 1. Clone & Configure

```bash
git clone https://github.com/your-org/crew-intelligence-platform.git
cd crew-intelligence-platform
cp .env.example .env
# Fill in your values in .env
```

### 2. Firebase Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Create Firebase project
firebase projects:create cip-dev

# Enable services in Firebase Console:
# - Authentication (Email/Password + Google)
# - Firestore Database (me-central1 region)
# - Storage
# - Cloud Functions
# - App Check

# Deploy rules and indexes
cd firebase
firebase use cip-dev
firebase deploy --only firestore:rules,firestore:indexes
```

### 3. Flutter App Setup

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Generate code (Freezed models, Riverpod, l10n)
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Add your google-services.json (Android) to android/app/
# Add your GoogleService-Info.plist (iOS) to ios/Runner/

# Run on device/emulator
flutter run
```

### 4. Python Services Setup

```bash
cd python_services

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export ANTHROPIC_API_KEY="your-key-here"
export FIREBASE_CREDENTIALS="path/to/service-account.json"
export ENV="development"

# Run locally
uvicorn main:app --reload --port 8080

# Run tests
pytest tests/ -v
```

### 5. Firebase Functions Setup

```bash
cd firebase/functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Set function config
firebase functions:config:set \
  python.service_url="http://localhost:8080" \
  stripe.secret="sk_test_..." \
  stripe.webhook_secret="whsec_..."

# Run emulator locally
firebase emulators:start --only functions,firestore,auth
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│             Flutter App (iOS/Android)        │
│     Riverpod · GoRouter · Hive · Dio        │
└──────────────────┬──────────────────────────┘
                   │ REST + Firestore realtime
┌──────────────────▼──────────────────────────┐
│              Firebase Layer                  │
│  Auth · Firestore · Storage · Functions     │
└──────────────────┬──────────────────────────┘
                   │ Internal HTTPS
┌──────────────────▼──────────────────────────┐
│        Python AI Services (Cloud Run)        │
│  Parser · Legality · NLP · Ranking · Bids  │
└──────────────────┬──────────────────────────┘
                   │
       ┌───────────┼────────────┐
       ▼           ▼            ▼
  Claude API    BigQuery    Firestore
```

---

## ⚖️ FTL Rules — Single Source of Truth

Every legality verdict (schedule check, trade check, rest calculator, PDF-intelligence
pipeline, AI answers) derives its thresholds from **one place**:

- Defaults: `python_services/legality/rules_source.py` (`CANONICAL_DEFAULTS`,
  the project's GOM 7.5.3 Table (F) set).
- Runtime overrides: the Firestore **`legalityRules`** collection, edited from the
  Admin Panel (seed it with `scripts/seed_legality_rules.py`). Overrides apply
  within ~5 minutes (TTL cache) — **no deploy needed**.
- Inspect what's live: `GET /v1/legality/rules` (values + provenance + overrides).
- Regulatory sign-off tracker: `OWNER_DECISION_REQUEST.md`.

The Flutter constants in `shared/constants/constants.dart` are display-only mirrors.
Never branch logic on them.

## 🔑 Key Features

| Feature | Description |
|---|---|
| 📂 **Excel Parser** | Auto-parses monthly roster `.xlsx` — one sheet per line |
| ⚖️ **Legality Engine** | GACA FTL rules: 14h/15h rest, FDP limits, cumulative hours |
| 🏆 **Smart Ranking** | Scores lines by salary, rest quality, preferences, regularity |
| 🎯 **User Modes** | Money 💰 / Rest 😴 / Balanced ⚖️ — drives all AI recommendations |
| 🔄 **Trade Engine** | Post, find, and validate trades with backward+forward legality |
| ⭐ **Najm AI** | Arabic/English NLP assistant — filter, compare, calculate, recommend |
| 🤖 **Auto-Bid** | Learns from behavior to suggest and submit monthly bids |
| 💰 **Salary Optimizer** | Estimates gross pay per line including per-diem and overtime |

---

## 🧪 Testing

```bash
# Flutter tests
cd flutter_app
flutter test test/unit/        # Unit tests
flutter test test/widget/      # Widget tests

# Python tests
cd python_services
pytest tests/unit/test_legality.py -v        # 60+ legality tests
pytest tests/unit/test_parser_ranking.py -v  # Parser + ranking tests
pytest tests/ --cov=. --cov-report=html     # Full coverage report

# Firebase Functions tests (builds then runs node:test on lib/)
cd firebase/functions
npm test

# Firestore + Storage security-rules tests (needs the emulator)
cd firebase
firebase emulators:exec --only firestore,storage \
  "npm --prefix test install && npm --prefix test test"

# Network-isolated environments: an offline verification harness
# (mini-pytest + dependency shims + TS stubs) lives in tools/offline_harness/
# — see its README for what it can and cannot prove. CI remains the source
# of truth.
python3 tools/offline_harness/run_tests.py
```

---

## 📊 Subscription Tiers

| Feature | Free | Pro (SAR 39/mo) | Elite (SAR 79/mo) |
|---|---|---|---|
| Roster uploads | 1/month | Unlimited | Unlimited |
| Bids per month | 3 | Unlimited | Unlimited |
| Trade board | ❌ | ✅ | ✅ |
| AI assistant | 5/day | Unlimited | Unlimited |
| Auto-bid suggestions | ❌ | With review | Hands-off |
| Smart ranking | ❌ | ✅ | ✅ |
| Salary optimizer | ❌ | ✅ | ✅ |
| Voice input | ❌ | ✅ | ✅ |

---

## 🌍 Localization

The app is **Arabic-first** with full English support.

```bash
# Add new strings
# 1. Add to lib/shared/l10n/app_ar.arb
# 2. Add to lib/shared/l10n/app_en.arb
# 3. Regenerate
flutter gen-l10n
```

All UI layouts are designed RTL-first. English is the mirror.

---

## 🔒 Security

- Firebase App Check (prevents API abuse)
- Firestore security rules (users access only own data)
- JWT token rotation on every use
- Input sanitization before Claude API calls
- PDPL-compliant data residency (KSA region)
- Full audit trail for all bid/trade state changes

---

## 📋 Roadmap

| Phase | Timeline | Status |
|---|---|---|
| Phase 0 — Foundation | Weeks 1–3 | ✅ |
| Phase 1 — MVP Core | Weeks 4–10 | 🔄 In Progress |
| Phase 2 — AI Layer | Weeks 11–18 | 📋 Planned |
| Phase 3 — Monetization | Weeks 19–24 | 📋 Planned |
| Phase 4 — Expansion | Month 7–12 | 📋 Planned |

---

## 🤝 Contributing

1. Branch from `develop`: `git checkout -b feature/your-feature`
2. Write tests for new features
3. Ensure `flutter analyze` and `ruff check` pass
4. Submit PR to `develop`
5. All PRs require one reviewer approval

---

## 📄 License

Proprietary. All rights reserved. © 2026 Crew Intelligence Platform.

---

## 📞 Support

- **In-app:** Settings → Support → Contact Support  
- **Email:** support@cip.app  
- **Docs:** https://cip.app/help

---

## Phase Changelog

### Phase 2 — PDF Intelligence Engine
- Upload monthly schedule PDF (3-layer extraction: pdfplumber → PyMuPDF → OCR)
- Full pairing reconstruction with duty periods, FDP, rest windows
- FRMS-based fatigue scoring with 7 operational factors
- 10 line classifiers: High Fatigue, Recovery Friendly, Heavy Deadhead, etc.
- Monthly analytics: block hours, credit estimate, per diem, destinations
- Fatigue timeline chart, monthly heatmap, pairing Gantt
- Smart search: filter by fatigue level, international, deadhead, credit
- Line comparison with radar scoring
- New routes: `/intelligence`, `/intelligence/lines/:id`, `/intelligence/upload`, `/intelligence/search`, `/intelligence/compare`, `/intelligence/pairings/:id`

### Phase 3 — Layover Intelligence
- 20 layover cities (CAI, IST, KUL, DXB, LHR, CDG, JFK, SIN, BKK, FRA, AMS, NRT, SYD, LAX, MXP, BCN, DOH, MNL, DEL, KHI)
- 9 categories per city: Restaurants, Coffee, Gyms, Prayer, Transport, Shopping, Attractions, Essentials, Crew Favorites
- Crew recommendations with photos, maps, GPS, opening hours, notes
- Like / Save / Comment / Rate system
- Halal filter, Open Now filter, Sort by Trending / Top Rated / Newest
- Content filter: blocks bars, clubs, alcohol automatically
- Admin delete for any recommendation or comment
- Crew Verified / Trending / Highly Rated smart badges
- New routes: `/layover`, `/layover/:cityId`, `/layover/:cityId/add`, `/layover/rec/:recId`

### Trade Recommendation Engine
- Behavioral preference learning from the user's own trade history
- Route familiarity scoring based on current monthly line routes
- 7-factor compatibility scoring: legality, fatigue, route, schedule, preference, behavioral, collaborative
- Manual PRN workflow: copy → Outlook lookup → paste phone → WhatsApp
- PRN contact status tracking: Sent / Pending / Failed
- Preference insights screen: users see exactly what was learned from their history
- New routes: `/trades/recommend`, `/trades/preferences`
- New Python services: preference_engine, behavioral_learning, route_familiarity_engine, compatibility_scoring, recommendation_engine, trade_engine
- No demographic inference — all signals from operational schedule data only

### Rest Calculator & Legality Engine
- Built-in GACA/ICAO-aligned rules — works immediately with zero configuration
- 4 crew type profiles: Cabin Standard, Cabin Long Haul, Cockpit, Augmented
- REST calculation: actual vs minimum, margin, local time labels
- FDP calculation: limit by legs + report time + WOCL reduction
- Fatigue scoring: 7-factor FRMS model (WOCL, early sign-in, duty length, legs, rest quality, TZ shift, deadheads)
- Composite safety score: 0–100 (legality 35% + fatigue 25% + rest margins 40%)
- Trade legality: validates both sides, returns trade_is_safe flag
- Visual timeline: Duty Start → Release → Rest → Briefing → Next Duty
- Auto-warnings for WOCL penetration, early sign-in, carry-over
- New API: `/v1/rest/calculate`, `/v1/rest/validate`, `/v1/rest/fatigue`, `/v1/rest/safety`, `/v1/rest/trade`, `/v1/rest/rules`
- New Flutter screens: `RestCalculatorScreen`, `TradeLegalityScreen`
- New Flutter widgets: `LegalityCard`, `FatigueBar`, `RestCountdownWidget`, `FDPWidget`, `DutyTimelineWidget`
- 35 unit tests covering rules, calculator, legality, fatigue, scoring, and validators
