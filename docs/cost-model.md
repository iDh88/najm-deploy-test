# Crew Intelligence Platform — Infrastructure Cost Model
## Version 1.0 | Prepared for: Technical Planning | Currency: USD

---

## ASSUMPTIONS

| Parameter | Value |
|---|---|
| Exchange rate | 1 USD = 3.75 SAR |
| Firebase region | me-central1 (KSA) |
| Python service | Google Cloud Run |
| AI model | Claude Sonnet 4 (claude-sonnet-4-20250514) |
| Billing cycle | Monthly |
| Free tier users convert to Pro at | 15% |

---

## PHASE 1 MVP — 1,000 USERS (Month 1–3)

### Firebase Costs

| Service | Usage | Unit Price | Monthly Cost |
|---|---|---|---|
| Firestore reads | 5M reads/month | $0.06/100K | $3.00 |
| Firestore writes | 500K writes/month | $0.18/100K | $0.90 |
| Firestore deletes | 100K/month | $0.02/100K | $0.02 |
| Firestore storage | 2 GB | $0.18/GB | $0.36 |
| Firebase Storage | 10 GB (Excel files) | $0.026/GB | $0.26 |
| Firebase Storage transfers | 20 GB/month | $0.12/GB | $2.40 |
| Cloud Functions invocations | 2M/month | $0.40/M | $0.80 |
| Cloud Functions compute | 200 GB-sec | $0.0000025/GB-sec | $0.50 |
| Firebase Auth | 1,000 MAU | Free (first 10K) | $0.00 |
| Firebase Messaging | 1M pushes | Free | $0.00 |
| **Firebase Subtotal** | | | **$8.24** |

### Google Cloud Run (Python Services)

| Service | Spec | Usage | Monthly Cost |
|---|---|---|---|
| Cloud Run — Parser | 1 vCPU / 2GB | 500 invocations/month | $2.50 |
| Cloud Run — Legality | 0.5 vCPU / 1GB | 5,000 checks/month | $3.00 |
| Cloud Run — AI Router | 1 vCPU / 2GB | 10,000 requests/month | $5.00 |
| Cloud Run — Ranking | 0.5 vCPU / 1GB | 2,000 requests/month | $1.50 |
| Cloud Run — Auto-Bid | 0.5 vCPU / 1GB | 1,000 requests/month | $0.80 |
| **Cloud Run Subtotal** | | | **$12.80** |

### Claude API Costs (Anthropic)

| Use Case | Volume | Input tokens | Output tokens | Monthly Cost |
|---|---|---|---|---|
| NLP filter (free tier) | 5K queries × 5/day = limited | 500 tokens avg | 200 tokens avg | $8.00 |
| NLP filter (pro users) | 150 users × 50 queries | 500 tokens avg | 200 tokens avg | $22.50 |
| Auto-bid explanation | 1,000 suggestions | 800 tokens avg | 400 tokens avg | $12.00 |
| Comparison queries | 500 queries | 1,500 tokens avg | 800 tokens avg | $14.00 |
| **Claude API Subtotal** | | | | **$56.50** |
> Pricing at $3/M input tokens, $15/M output tokens (Sonnet 4)

### Other Services

| Service | Monthly Cost |
|---|---|
| BigQuery storage (10 GB behavior data) | $0.20 |
| BigQuery queries (analytics) | $1.00 |
| Secret Manager | $0.06 |
| Cloud Monitoring + Logging | $2.00 |
| Sentry (error tracking, Team plan) | $26.00 |
| Domain + SSL | $2.00 |
| **Other Subtotal** | **$31.26** |

### Phase 1 Total

| Category | Monthly | Annual |
|---|---|---|
| Firebase | $8.24 | $98.88 |
| Cloud Run | $12.80 | $153.60 |
| Claude API | $56.50 | $678.00 |
| Other | $31.26 | $375.12 |
| **TOTAL** | **$108.80** | **$1,305.60** |

---

## PHASE 2 — 5,000 USERS (Month 4–6)

| Category | Monthly | Notes |
|---|---|---|
| Firebase | $32.00 | Linear scale with users |
| Cloud Run | $45.00 | Autoscaling kicks in |
| Claude API | $220.00 | ~2,500 pro users × 50 queries |
| BigQuery | $8.00 | Behavior data accumulation |
| Other | $35.00 | Sentry + monitoring |
| **TOTAL** | **$340.00** | **$4,080/year** |

---

## PHASE 3 — 20,000 USERS (Month 7–9)

| Category | Monthly | Notes |
|---|---|---|
| Firebase | $120.00 | Consider Firestore bundle caching |
| Cloud Run | $150.00 | Min instances enabled for latency |
| Claude API | $850.00 | ~8,000 pro/elite users |
| BigQuery + Vertex AI | $45.00 | ML training pipeline begins |
| CDN (Firebase Hosting) | $15.00 | |
| Support tooling (Intercom) | $74.00 | |
| Other | $40.00 | |
| **TOTAL** | **$1,294.00** | **$15,528/year** |

---

## PHASE 4 — 100,000 USERS (Month 12+)

| Category | Monthly | Notes |
|---|---|---|
| Firebase (multi-region) | $520.00 | Consider Datastore migration |
| Cloud Run (scaled) | $600.00 | Multiple regions |
| Claude API | $3,800.00 | ~40,000 pro/elite active users |
| Vertex AI (ML models) | $200.00 | Recommendation model hosting |
| BigQuery | $120.00 | Full analytics pipeline |
| Redis Cache (Memorystore) | $80.00 | API response caching |
| Load Balancer + CDN | $45.00 | |
| Support + Monitoring | $180.00 | |
| **TOTAL** | **$5,545.00** | **$66,540/year** |

---

## REVENUE PROJECTIONS

### Subscription Revenue Model

| Phase | Users | Free | Pro (SAR 39/mo) | Elite (SAR 79/mo) | Revenue/Month |
|---|---|---|---|---|---|
| Phase 1 (1K) | 1,000 | 850 | 130 | 20 | SAR 6,650 ($1,773) |
| Phase 2 (5K) | 5,000 | 4,000 | 800 | 200 | SAR 47,000 ($12,533) |
| Phase 3 (20K) | 20,000 | 15,000 | 4,000 | 1,000 | SAR 235,000 ($62,666) |
| Phase 4 (100K) | 100,000 | 70,000 | 22,000 | 8,000 | SAR 1,490,000 ($397,333) |

### Unit Economics (Phase 3 steady state)

| Metric | Value |
|---|---|
| ARPU (avg revenue per user) | SAR 11.75/month |
| CAC (customer acquisition cost) | SAR 25 (estimated) |
| LTV (12-month) | SAR 141 |
| LTV:CAC ratio | 5.6:1 ✅ healthy |
| Gross margin | ~88% (SaaS software) |
| Infrastructure cost per user | $0.065/month |
| Contribution margin per Pro user | SAR 36.51 (93.6%) |

---

## COST OPTIMISATION STRATEGIES

### Immediate (Phase 1)
- Enable Firestore offline persistence in Flutter to reduce read counts by ~40%
- Cache ranked line results in Hive for 1 hour (avoid redundant ranking calls)
- Bundle Claude API system prompts to minimise token overhead
- Use Firebase free tier credits aggressively in first 90 days

### Medium Term (Phase 2–3)
- Implement Redis caching for legality rule lookups (rules change monthly, not daily)
- Batch auto-bid suggestion generation at 02:00 KSA rather than on-demand
- Use Claude API prompt caching for system prompt (saves ~30% on input tokens)
- Move BigQuery to scheduled exports rather than real-time streaming

### Long Term (Phase 4)
- Evaluate fine-tuned smaller model for filter/calculation intents (cheaper than Sonnet)
- Implement Firestore bundle serving for static monthly line data
- Multi-region active-active deployment with traffic splitting
- Negotiate committed use discounts with GCP (30–55% savings at scale)

---

## BREAK-EVEN ANALYSIS

| Phase | Monthly Infra Cost | Monthly Revenue | Net |
|---|---|---|---|
| Phase 1 | $109 | $1,773 | **+$1,664 ✅** |
| Phase 2 | $340 | $12,533 | **+$12,193 ✅** |
| Phase 3 | $1,294 | $62,666 | **+$61,372 ✅** |
| Phase 4 | $5,545 | $397,333 | **+$391,788 ✅** |

> Note: Revenue figures exclude VAT (15% KSA), payment processing fees (~2.9% Stripe),
> app store commission (15–30% Apple/Google for in-app purchases), and team salaries.
> Adjust revenue by ~60% to account for these deductions for net margin calculation.

---

## RISK FACTORS

| Risk | Impact | Mitigation |
|---|---|---|
| Claude API price increase | Medium — $3,800/month at scale | Implement caching; evaluate alternatives |
| Firebase pricing change | Low — well-established pricing | Architecture abstraction layer |
| Low Pro conversion (<10%) | High — revenue halved | Improve onboarding; add trial nudges |
| High churn (>30%/month) | High | Focus on core value delivery; monthly re-engagement |
| Data residency regulation change | Medium | KSA region already selected |
