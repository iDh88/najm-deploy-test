# CIP DevOps Runbook
## Crew Intelligence Platform — Operations & Incident Response

---

## 1. Service Architecture Overview

```
Flutter App (iOS/Android)
    ↓ HTTPS
Firebase (Auth · Firestore · Storage · Functions · FCM)
    ↓ Internal HTTPS (service account JWT)
Cloud Run: cip-python-services (me-central1)
    ↓ REST
Anthropic Claude API
    ↓ Batch
BigQuery (analytics · ML training)
```

**Regions:** Primary `me-central1` (Dammam, KSA). Stripe webhooks on `us-central1`.

---

## 2. Environments

| Environment | Firebase Project | Cloud Run Service | Branch |
|---|---|---|---|
| Production | `cip-prod` | `cip-python-services` | `main` |
| Staging | `cip-staging` | `cip-python-staging` | `develop` |
| Development | `cip-dev` | Local Docker | feature branches |

---

## 3. Deployment Procedures

### 3.1 Standard Deployment (CI/CD)
All deployments to `main` are handled automatically by `.github/workflows/deploy.yml`.

**Deployment order:**
1. Tests pass (Flutter + Python + Functions)
2. Security scan passes
3. Python services → Cloud Run
4. Firebase rules + indexes
5. Firebase Cloud Functions
6. APK distributed to beta testers

**Expected deployment time:** 8–12 minutes end-to-end.

### 3.2 Manual Emergency Deployment

**Python Services:**
```bash
# Build and push image
cd python_services
gcloud builds submit \
  --tag gcr.io/cip-prod/cip-python-services:manual-$(date +%Y%m%d%H%M%S) \
  --project cip-prod

# Deploy with traffic split (canary 10%)
gcloud run deploy cip-python-services \
  --image gcr.io/cip-prod/cip-python-services:manual-TIMESTAMP \
  --region me-central1 \
  --no-traffic \
  --project cip-prod

gcloud run services update-traffic cip-python-services \
  --to-revisions LATEST=10,STABLE=90 \
  --region me-central1
```

**Firebase Functions:**
```bash
cd firebase
firebase deploy --only functions --project cip-prod
```

**Firestore Rules only (zero downtime):**
```bash
firebase deploy --only firestore:rules --project cip-prod
```

### 3.3 Rollback Procedures

**Python Services — Rollback to previous revision:**
```bash
# List revisions
gcloud run revisions list --service cip-python-services --region me-central1

# Route 100% traffic back to previous stable revision
gcloud run services update-traffic cip-python-services \
  --to-revisions PREVIOUS_REVISION_ID=100 \
  --region me-central1
```
**RTO target: < 3 minutes**

**Firebase Functions — Rollback:**
```bash
# Checkout previous commit
git checkout <previous-sha>
cd firebase && firebase deploy --only functions
```

**Firestore Rules — Rollback:**
```bash
git checkout <previous-sha> firebase/firestore.rules
firebase deploy --only firestore:rules
```

---

## 4. Environment Variables & Secrets

All secrets managed in **Google Cloud Secret Manager** (`cip-prod` project).

| Secret Name | Description | Rotation |
|---|---|---|
| `anthropic-api-key` | Anthropic Claude API key | 90 days |
| `firebase-service-account` | Firebase Admin SDK JSON | 180 days |
| `internal-service-token` | Cloud Run ↔ Functions auth | 90 days |
| `stripe-secret-key` | Stripe secret key | On compromise |
| `stripe-webhook-secret` | Stripe webhook signing secret | On compromise |
| `hyperpay-secret` | HyperPay API credentials | 90 days |

**Access secrets in Cloud Run:**
```bash
gcloud secrets versions access latest --secret anthropic-api-key --project cip-prod
```

**Rotate a secret:**
```bash
echo -n "NEW_SECRET_VALUE" | \
  gcloud secrets versions add anthropic-api-key --data-file=- --project cip-prod
# Old version auto-disabled after 24h grace period
```

---

## 5. Monitoring & Alerting

### 5.1 Key Metrics to Watch

| Metric | Warning Threshold | Critical Threshold | Alert Channel |
|---|---|---|---|
| Cloud Run error rate | > 1% | > 5% | Slack #cip-alerts |
| Cloud Run latency (p99) | > 3s | > 10s | Slack #cip-alerts |
| Claude API error rate | > 2% | > 10% | PagerDuty |
| Firestore read quota | > 70% | > 90% | Slack #cip-alerts |
| Active users drop | > 20% | > 40% vs prev day | PagerDuty |
| Failed bid submissions | > 5/min | > 20/min | PagerDuty |

### 5.2 Log Queries (Cloud Logging)

**Python service errors (last 1h):**
```
resource.type="cloud_run_revision"
resource.labels.service_name="cip-python-services"
severity>=ERROR
timestamp>="2026-01-01T00:00:00Z"
```

**Legality engine violations (anomaly detection):**
```
resource.type="cloud_run_revision"
jsonPayload.message=~"legality.*violation"
jsonPayload.userId!=""
```

**Claude API rate limit hits:**
```
resource.type="cloud_run_revision"
jsonPayload.message=~"rate_limit|RateLimitError"
```

**Firebase Function failures:**
```
resource.type="cloud_function"
severity=ERROR
```

### 5.3 Dashboards
- Cloud Monitoring: `https://console.cloud.google.com/monitoring/dashboards?project=cip-prod`
- Firebase Console: `https://console.firebase.google.com/project/cip-prod`
- Sentry (Python): `https://sentry.io/organizations/cip/`
- Firebase Crashlytics: Firebase Console → Crashlytics

---

## 6. Incident Response

### Severity Levels

| Level | Definition | Response Time | Examples |
|---|---|---|---|
| SEV-1 | Complete service outage | 15 minutes | Auth down, all bids failing |
| SEV-2 | Major feature broken | 1 hour | Legality engine down, parser failing |
| SEV-3 | Degraded performance | 4 hours | Slow AI responses, delayed notifications |
| SEV-4 | Minor issue | Next business day | UI bug, non-critical error spike |

### 6.1 SEV-1 Response Playbook

1. **Acknowledge** in Slack #cip-incidents within 5 minutes
2. **Assess** — run health checks:
   ```bash
   curl https://cip-python-services-xxxx.run.app/health
   firebase functions:log --project cip-prod --limit 50
   ```
3. **Communicate** — post status update to #cip-status every 15 minutes
4. **Mitigate** — most common mitigations:
   - Auth issues → check Firebase Auth console, Firebase status page
   - Cloud Run down → rollback to previous revision (see §3.3)
   - Firestore quota exceeded → check quotas, implement emergency rate limiting
   - Claude API down → switch to degraded mode (disable AI features, return cached responses)
5. **Resolve** and write incident report within 24 hours

### 6.2 Degraded Mode (Claude API Unavailable)

When Anthropic API is unreachable, Python service falls back to:
- NLP queries → return "AI assistant temporarily unavailable" message
- Auto-bid suggestions → return top-3 lines by composite score (no AI explanation)
- Legality checks → run local rule engine only (no Claude explanation generation)

**Enable degraded mode:**
```bash
gcloud run services update cip-python-services \
  --set-env-vars CLAUDE_DEGRADED_MODE=true \
  --region me-central1
```

### 6.3 Data Incident Response (PDPL Compliance)

If a data breach is suspected:
1. Immediately rotate all secrets (see §4)
2. Revoke all active Firebase sessions:
   ```bash
   # Revoke all refresh tokens for a specific user
   firebase auth:revoke-tokens USER_ID --project cip-prod
   ```
3. Notify Data Protection Officer within 2 hours
4. Under Saudi PDPL: notify affected users within 72 hours if PII was exposed
5. File incident report with SDAIA (Saudi Data and AI Authority) if required

---

## 7. Database Operations

### 7.1 Firestore Backup

Automatic daily exports to Cloud Storage:
```bash
# Manual export
gcloud firestore export gs://cip-prod-backups/$(date +%Y-%m-%d) \
  --project cip-prod

# Restore from backup
gcloud firestore import gs://cip-prod-backups/2026-01-15 \
  --project cip-prod
```

### 7.2 Data Deletion Pipeline (PDPL Right to Erasure)

Triggered automatically when a deletion request document is created.
Manual trigger for testing:
```bash
firebase functions:call processAccountDeletion \
  --data '{"userId":"USER_ID"}' \
  --project cip-prod
```

**Verify deletion completed:**
```bash
# Should return "NOT_FOUND"
firebase firestore:get users/USER_ID --project cip-prod
```

### 7.3 Firestore Index Management

```bash
# Deploy new indexes
firebase deploy --only firestore:indexes --project cip-prod

# Check index build status
firebase firestore:indexes --project cip-prod
```

---

## 8. Scaling Operations

### 8.1 Cloud Run Scaling

```bash
# Scale up for expected high load (bid window opening)
gcloud run services update cip-python-services \
  --min-instances 3 \
  --max-instances 50 \
  --region me-central1

# Scale back after peak
gcloud run services update cip-python-services \
  --min-instances 0 \
  --max-instances 20 \
  --region me-central1
```

### 8.2 Firestore Quota Increase

For events likely to spike reads (e.g., bid window open):
1. Go to Google Cloud Console → Quotas
2. Request increase for `Cloud Firestore API — Read requests per minute`
3. Allow 24h for approval

### 8.3 Claude API Rate Limit Management

Current limits (Anthropic Tier 3):
- 100K tokens/minute
- 4,000 requests/minute

At 25K users with 8 queries/day average: ~139 req/min peak. **Well within limits.**

If approaching limits:
```python
# Enable request queuing in nlp_router.py
ENABLE_QUEUE = True
MAX_CONCURRENT_CLAUDE_CALLS = 50
```

---

## 9. Release Checklist

Before every production release:
- [ ] All CI checks green
- [ ] Staging deployed and smoke-tested
- [ ] Legality engine test suite passes (60+ tests)
- [ ] No new Firestore security rule regressions
- [ ] PDPL compliance review for any new data fields
- [ ] Performance test: p99 latency < 3s for all endpoints
- [ ] App Store / Play Store release notes prepared
- [ ] Rollback procedure verified (tested in staging)
- [ ] On-call engineer assigned for 24h post-deploy

---

## 10. On-Call Contacts

| Role | Contact | Escalation |
|---|---|---|
| Primary On-Call | Rotate weekly | PagerDuty schedule |
| Firebase/GCP Issues | GCP Support (paid) | support.google.com |
| Anthropic API Issues | api-support@anthropic.com | Status: status.anthropic.com |
| Stripe Issues | Stripe Dashboard → Support | status.stripe.com |
| Security Incident | security@cip.app | DPO + legal team |
