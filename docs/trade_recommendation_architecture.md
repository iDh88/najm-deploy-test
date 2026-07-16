# Trade Recommendation Engine — Architecture

## Overview

The Trade Recommendation Engine ranks crew trade candidates using purely
operational schedule data. It learns from behavioral history to improve
suggestions over time.

**No demographic inference is performed at any stage.**

---

## Data Flow

```
User selects a trip from their line
            │
            ▼
POST /v1/trade/search
            │
            ▼
RecommendationEngine.recommend()
    │
    ├── 1. Load requester's UserPreferenceProfile (Firestore)
    │
    ├── 2. Fetch all candidates (same rank, same month) from flightLines
    │
    ├── 3. Filter: isLegal == true only
    │
    ├── 4. For each candidate:
    │       ├── Load candidate's UserPreferenceProfile
    │       └── CompatibilityScorer.score(candidate, target, profile)
    │               ├── legality_score      (GACA FTL margins)
    │               ├── fatigue_score       (combined duty + rest)
    │               ├── route_similarity    (RouteFamiliarityAnalyzer)
    │               ├── schedule_compat     (open days, carry-over, FDP)
    │               ├── preference_match    (user's own history)
    │               ├── behavioral_score    (route acceptance history)
    │               └── collaborative_score (top routes / destinations)
    │
    ├── 5. Sort by composite score (0–100)
    │
    └── 6. Return ranked TradeSearchResponse
```

---

## Scoring Weights

| Factor | Weight | Source |
|---|---|---|
| Legality | 25% | GACA FTL rules engine |
| Route familiarity | 20% | Candidate's current line route history |
| Fatigue impact | 15% | Combined duty/rest fatigue model |
| Schedule compatibility | 15% | Open days, carry-over, FDP match |
| Preference match | 15% | User's own accepted/rejected history |
| Behavioral score | 8% | Route acceptance rate from history |
| Collaborative | 2% | Anonymous pattern signal |

---

## Behavioral Learning Pipeline

```
User action (view / accept / reject / expire)
            │
POST /v1/trade/events
            │
TradeEventService.record_event()
            │
ProfileBuilder.apply_event()   ← incremental update (fast)
            │
Firestore: users/{uid}/preferenceProfile/main
            │
Weekly: profile_rebuild_job.py ← full rebuild from all events
```

### What is learned

All signals come from the user's **own trade history**:

| Signal | Used for |
|---|---|
| Routes accepted/rejected | `route_frequency` map |
| Destinations accepted/rejected | `destination_preferences` map |
| Sign-in hours of accepted trades | `preferred_signin_hour_*` |
| Layover hours of accepted trades | `preferred_layover_*` |
| Fatigue scores of accepted trades | `fatigue_tolerance` level |
| International vs domestic accepted | `prefers_international` |

### What is NOT learned

- Name, nationality, ethnicity, religion
- Demographic characteristics of any kind
- Any inference from crew member identity

---

## Route Familiarity Engine

Scores how much of a candidate's **current monthly line** overlaps with
the target route. Uses airport codes and operational region geography only.

```
Exact match    → 1.00   (same airports in same order)
Shared airport → 0.75+  (candidate flies the same destination)
Shared region  → 0.30+  (candidate flies the same operational region)
No overlap     → 0.00
```

Region labels used (operational geography only):
`south_asia`, `southeast_asia`, `east_asia`, `europe_west`, `europe_east`,
`africa_east`, `africa_south`, `africa_north`, `gulf`, `levant`, `saudi`,
`north_america`, `latin_america`, `oceania`

These are **flight network regions** — not cultural or demographic categories.

---

## PRN Workflow

The PRN contact system is fully manual. The system only tracks status.

```
Search result shown (PRN: 30048372)
        │
User copies PRN
        │
User searches Outlook for phone number
        │
User pastes phone into Najm
        │
Najm opens WhatsApp with pre-written trade message
        │
User edits and sends manually
        │
User marks status: ✅ Sent / ⏳ Pending / ❌ Failed
        │
Status stored: tradeContacts/{userId}_{tradeId}_{prn}
```

---

## Privacy Guarantees

1. **No hidden labels** — no `nationality`, `ethnicity`, `region_affinity`,
   or demographic tags exist anywhere in the codebase
2. **User-visible data** — the `/v1/trade/profile/{userId}` endpoint exposes
   exactly what was learned, so users can see their own profile
3. **Behavioral only** — every scoring factor traces back to an operational
   trade action, not an identity inference
4. **Auditable** — all `behaviorEvents` documents contain only trade
   operational fields; no identity fields
5. **Tests enforce it** — `test_no_demographic_data_in_reasons()` and
   `TestNoDemographicInference` run in CI

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `behaviorEvents/{eventId}` | Raw trade interaction log |
| `users/{uid}/preferenceProfile/main` | Learned preference profile |
| `tradeContacts/{uid}_{tradeId}_{prn}` | PRN contact status tracking |
| `flightLines/{lineId}` | Crew monthly lines (existing) |

---

## API Reference

| Method | Path | Description |
|---|---|---|
| POST | `/v1/trade/search` | Get ranked trade matches |
| POST | `/v1/trade/events` | Record a behavioral event |
| GET  | `/v1/trade/profile/{userId}` | Get preference summary |
| POST | `/v1/trade/profile/{userId}/rebuild` | Trigger full profile rebuild |
| PUT  | `/v1/trade/prn-status` | Update PRN contact status |
| GET  | `/v1/trade/prn-status/{userId}/{tradeId}` | Get all PRN statuses |
