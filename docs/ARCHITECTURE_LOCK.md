# NAJM — Architecture Lock (ADRs)

> **Status:** ADR-000 through ADR-020 **APPROVED & BINDING** (owner sign-off
> 2026-07-15). The Phase 1 AI Platform Lock below is the approved target
> architecture and is binding, but is not yet implemented.
>
> This document is the **binding contract** for Phases 2–7. No script,
> pipeline, or infrastructure change may contradict an ADR here. Where a lower ADR
> conflicts with **ADR-000 / the Architecture Principle**, ADR-000 wins.

## Architecture Principle (owner-mandated, overrides everything)

> **Every architectural decision must remain reversible. Never introduce vendor
> lock-in unless there is a measurable production benefit. Prefer portable, open
> standards whenever practical.**

Environments: `local` → `dev` → `staging` → `prod`. Region locked to **`me-central1`**
(Doha — lowest latency to Saudi users, data-residency friendly).

---

## Decision log (owner sign-off)

| Date | Decision |
|---|---|
| 2026-07-15 | **Topology (ADR-001):** 3 projects — keep `cip-najm` as **prod** (no data migration), add `cip-najm-dev` + `cip-najm-staging`. |
| 2026-07-15 | **Backend edge (ADR-004):** Cloud Run stays `--allow-unauthenticated` + app-layer auth; add CI invariant (no router without auth `Depends`); fix `subscription_router` (S1). |
| 2026-07-15 | **Monitoring (ADR-009):** Cloud-native (Cloud Logging + Error Reporting); drop dead `SENTRY_DSN` (M1); keep JSON+PDPL-redaction logging. |
| 2026-07-15 | **Toolchain:** standardize on `.venv` / Python 3.11; `git init` before Phase 2. |
| 2026-07-15 | **ADR-014–018 approved & BINDING.** Added **ADR-019** (health/readiness verification), **ADR-020** (documentation & phase-reporting standard), and the **ADR-009 request/correlation-ID extension**. |
| 2026-07-16 | **Phase 1 AI Platform Lock:** approved the provider-independent AI target and the authoritative documents indexed by `NAJM_ARCHITECTURE.md`; documentation only, not yet implemented. |

---

## ADR-000 — Governing principles (supersedes all)

1. **Reversibility** — every decision has a documented exit path; no one-way doors without explicit sign-off.
2. **No vendor lock-in without measurable production benefit** — lock-in is allowed only when the managed alternative is materially cheaper to build/operate, and that benefit is named.
3. **Prefer portable, open standards** — OCI containers, stdout JSON logs, OpenAPI, env-var config, standard Docker registries.

---

## Phase 1 AI Platform Lock — approved target, not yet implemented

The specialized target contract is the ten approved documents under
`docs/architecture/`, indexed by `NAJM_ARCHITECTURE.md`. The following
rules are locked:

1. Every migrated AI request routes through an authenticated FastAPI Product
   API → AI Orchestrator → AI Gateway → exactly one approved Provider Adapter
   per execution attempt.
2. Provider Adapters are the only target layer authorized to call GLM, Claude,
   OpenAI, Gemini, DeepSeek, Qwen, or any future provider API or SDK. No future
   implementation may add a direct provider call from Flutter, a Product API,
   domain engine, Cloud Function, tool, parser, scheduler, or admin interface.
   Existing direct Anthropic/OpenAI call sites are frozen legacy debt and may
   only be migrated away or removed.
3. Provider/model routing is governed by the Provider Registry and Model
   Registry. Production prompt bodies and selection are governed by the Prompt
   Registry. They are not business-module constants or client choices.
4. Users consume provider-neutral NAJM AI Credits, never provider tokens or
   provider-specific quotas. The AI Orchestrator coordinates entitlement,
   Budget Controller, reservation, reconciliation, and immutable ledger
   obligations before and after execution as applicable.
5. Deterministic aviation engines and governed operational sources remain
   authoritative. Model output cannot override legality, authorization,
   entitlement, safety, incident controls, budget, credits, or governed facts.
6. Provider secrets remain server-side and adapter-scoped. Observability is
   correlated, redacted, and privacy-scoped; required safety, usage, incident,
   audit, and accounting facts are immutable.

Phase 1 changes documentation only. Until a separately approved migration,
current direct Anthropic/OpenAI behavior remains a legacy compatibility fact,
not an exception that authorizes new provider coupling. Later implementation
must enforce a frozen allowlist of legacy direct call sites that can only
shrink.

---

## Approved ADRs (001–013) — binding summaries

Full rationale is in the approval thread; each is reproduced here as the binding decision + exit path.

- **ADR-001 — Environment & Firebase project topology.** 3 Firebase/GCP projects (`cip-najm`=prod, `cip-najm-dev`, `cip-najm-staging`) as `.firebaserc` aliases; `local`=emulators. *Exit:* projects are standard GCP; data exportable (see ADR-017).
- **ADR-002 — Backend on Cloud Run.** One OCI image per git SHA, one service per project, promoted by digest dev→staging→prod; stateless/12-factor; fix Dockerfile system deps (`tesseract-ocr`, `poppler-utils`). *Exit:* OCI image runs on GKE/any host (ADR-012).
- **ADR-003 — Secret management.** GCP Secret Manager for cloud envs (injected to Cloud Run via `--set-secrets`), `.env` for local, WIF for CI, Firebase creds via runtime SA (ADC). No secrets in source/images. *Exit:* app reads `os.environ` only — injection is swappable (Vault/K8s Secrets) with zero code change.
- **ADR-004 — Auth model.** Firebase ID tokens (users) + `INTERNAL_SERVICE_TOKEN` (service plane, never in client). Public Cloud Run edge + mandatory app-layer auth; CI invariant forbids a router without an auth dependency. *Exit:* standard OIDC/bearer patterns.
- **ADR-005 — Flutter client config.** `--dart-define` env selection + per-environment `firebase_options` via FlutterFire; no hardcoded placeholders. *Exit:* config is build input, not code.
- **ADR-006 — Firebase Functions.** Node 20, TypeScript; **commit `package-lock.json`**, use `npm ci`. *Exit:* standard Node; logic portable to any FaaS/container.
- **ADR-007 — Admin Panel.** Static SPA on Hosting with **runtime config injection** (`config.js` per env); keep locked security headers; delete dead scaffolding. *Exit:* plain static files, host-agnostic.
- **ADR-008 — AI services (legacy/current-state baseline).** The original implementation uses Anthropic primary + OpenAI embeddings, Secret Manager keys, daily caps, and cite-or-refuse behavior. Its original “provider swap = config” assumption is historical and is superseded for target architecture by the Phase 1 AI Platform Lock. This line preserves current-state evidence only and does not authorize new direct provider calls.
- **ADR-009 — Logging & Monitoring.** Structured JSON to stdout (open standard) → Cloud Logging + Cloud Error Reporting; uptime checks on `/health`; drop dead Sentry DSN. **Correlation/Request IDs (extension):** middleware accepts or generates `X-Request-ID` per request, stores it in the existing `request-id` `ContextVar` (`utils/logging_config.py`) so every log line correlates, echoes it in the response header, and forwards it on service-to-service calls. *Exit:* pipe stdout to any sink; request-id is a standard header.
- **ADR-010 — CI/CD.** GitHub Actions, WIF only, promote-by-digest, protected `main`, gated per-env deploy + revision-recorded rollback. *Exit:* standard OCI registry; portable to any CI.
- **ADR-011 — Local development.** One-command stack: `.venv` (Py 3.11) + Firebase emulators + Flutter `--dart-define`; local secrets from `.env`. *Exit:* nothing cloud-required for the inner loop.
- **ADR-012 — Future Kubernetes path (open, not taken).** Keep the service a stateless 12-factor OCI container with no Cloud Run-proprietary calls. *Exit:* migration = Deployment + Service + HPA reusing the same image.
- **ADR-013 — Repository & Git strategy.** `git init`; strict root `.gitignore` (`.env*` except `.env.example`, `.venv/`, `**/build/`, `**/node_modules/`, generated Dart, credential JSONs); trunk-based; release tags. *Exit:* plain git.

**Two enforced CI invariants (from ADR-004 & ADR-000):**
1. No router mounted without an auth `Depends(...)`.
2. No new `firestore.client()` call outside `python_services/utils/firebase.py` (preserves the single 110-site Firestore seam; keeps the Firebase exit path cheap).

---

## ADR-014 — Database Versioning & Migrations

- **Current:** Firestore is schemaless. No migration framework — only `scripts/seed_legality_rules.py` (one-shot seeder). `firestore.indexes.json` is version-controlled; `rosterVersions` is app-level roster versioning, not schema migration.
- **Problems:** Field renames, backfills, and shape changes have no repeatable, idempotent, ordered, audited mechanism; risk of partial or double backfills; no record of which migrations ran in which environment.
- **Recommended:** A lightweight **forward-only migration runner**. Numbered idempotent scripts in `scripts/migrations/NNN_description.py`, each guarded by a marker doc `_migrations/{id}` (ran-at + checksum) so re-runs are no-ops. The runner applies pending migrations in order, per environment (dev→staging→prod), with a `--dry-run` mode and **batched writes** that respect Firestore limits. Store a `schemaVersion` on documents whose shape evolves. Indexes stay in `firestore.indexes.json` (git). Migrations run only through the **gated CI deploy job**, never ad-hoc against prod.
- **Why better:** Repeatable, ordered, idempotent, audited; staging proves a migration before prod; impossible to double-backfill.
- **Alternatives considered:** Console edits (rejected — unauditable/unrepeatable); heavyweight ORM/DDL migration tool (rejected — Firestore has no DDL; overkill); pure lazy/on-read migration (kept only for *additive* fields; destructive/backfill changes require the runner).
- **Trade-offs:** Migrations must be written as code + markers; forward-only (rollback = compensating migration, not a down-migration).
- **Production impact:** Safe evolution of live data; a bad migration is caught in staging.
- **Cost impact:** Negligible (script execution + a few marker writes).
- **Security impact:** Runs under the least-privilege deployer SA; every migration is audited by its marker.
- **Scalability impact:** Batched/chunked writes respect Firestore throughput; large backfills paginate.

## ADR-015 — API Versioning

- **Current:** All 19 routers already mounted under `/v1/*` (`python_services/main.py`); OpenAPI spec exists (`docs/openapi.yaml`). No formal deprecation policy or `/v2` path yet.
- **Problems:** No documented contract for breaking changes. Mobile clients have a long tail of installed app versions in the field and can break when the backend changes.
- **Recommended:** Lock **URI path versioning** (`/v1`, future `/v2`) — already in place. Rule: **breaking change → new version prefix; additive/back-compatible change stays in `/v1`.** `docs/openapi.yaml` is the source of truth, validated in CI. Deprecation policy: a version is supported for ≥ N months after its successor ships (mobile can't be force-updated); sunset is announced via `Deprecation`/`Sunset` response headers and gated on usage metrics before removal. The service hosts both `/v1` and `/v2` handlers during a transition window.
- **Why better:** Field clients never hard-break; explicit, testable, cache-friendly, industry-standard contract.
- **Alternatives considered:** Header/media-type versioning (rejected — harder to test/cache/debug for a mobile client); query-param version (rejected — caching/routing issues); no versioning (rejected — breaks old installs).
- **Trade-offs:** Two versions maintained during a deprecation window; OpenAPI discipline required.
- **Production impact:** Zero-downtime API evolution.
- **Cost impact:** Minor (temporary dual handlers).
- **Security impact:** Auth is version-scoped and unchanged; no new surface.
- **Scalability impact:** Routing is stateless; versions scale independently.

## ADR-016 — Feature Flags

- **Current:** Config-driven flags already exist and work: `SUBSCRIPTIONS_ENABLED` (env kill-switch), `subscriptionConfig/main` (Firestore, 30s cache), `AI_DAILY_FREE_LIMIT` (Firestore→env→default precedence), `legalityRules` (Firestore override, TTL-cached, **fail-safe**). `subscription_engine` is the in-repo reference for "config-driven done right."
- **Problems:** The pattern is proven but not generalized — flags are ad-hoc per feature; no single catalog, no documented per-environment/cohort targeting, no consistent fail-closed convention.
- **Recommended:** Standardize on a **Firestore-backed flag store** (`featureFlags/{key}`, or extend `subscriptionConfig`) following the subscription_engine pattern: TTL-cached (~30s–5min), **fail-closed to a safe default** (as `legalityRules` already does), typed accessors. Precedence: **Firestore flag → env var → hardcoded default** (identical to `AI_DAILY_FREE_LIMIT`). Support boolean kill-switches and per-environment values (separate flag docs per project = free cohorting via ADR-001). **No third-party flag SaaS** (ADR-000 — lock-in without measurable benefit at this scale).
- **Why better:** One consistent, testable, portable mechanism; instant kill-switch without a deploy; reuses a pattern already validated in-repo.
- **Alternatives considered:** LaunchDarkly/Flagsmith (rejected — vendor lock-in + cost, no measurable benefit); env-only flags (rejected — needs redeploy to flip); compile-time flags (rejected — can't react in prod).
- **Trade-offs:** A Firestore read per cache miss (bounded by TTL); flags are eventually consistent within the cache window.
- **Production impact:** Progressive rollout + instant feature rollback without shipping code.
- **Cost impact:** Negligible (cached Firestore reads).
- **Security impact:** Flag store gated by admin claims + rules; **fail-closed** prevents a missing/unreadable flag from opening a gated feature.
- **Scalability impact:** Cached reads scale flat regardless of traffic.

## ADR-017 — Backup & Disaster Recovery

- **Current:** Managed Firestore, but **no scheduled backups configured**. A manual `gcloud firestore export` sits in `docs/devops-runbook.md`; scheduled exports + DR scenarios are *planned but unimplemented* in `plans/phase2/rollback-runbook.md` and `plans/PHASE_3_operational_readiness_and_DR_certification.md`. Code rollback exists (`rollback.yml` + recorded Cloud Run revision). Storage object versioning unset.
- **Problems:** No automated data backup = risk of permanent data loss (accidental delete, bad migration, corruption); no proven restore; no defined RTO/RPO.
- **Recommended:** Four independent layers.
  1. **Firestore Point-in-Time Recovery (PITR)** — 7-day continuous recovery (single setting); covers accidental writes/deletes.
  2. **Scheduled daily Firestore export** to a dedicated **separate-project** cross-region GCS bucket (`gs://cip-najm-backups-*`) with lifecycle retention (e.g. 30 daily / 12 monthly).
  3. **Storage object versioning + retention** on user-content buckets.
  4. **Targets & drills:** **RPO ≤ 24h** (export) / near-zero within the PITR window; **RTO ≤ 4h**. Document the restore runbook (import into a fresh project) and **test-restore into staging quarterly** (the DR-cert plan already scaffolds this).
  Cloud Run/Functions are stateless → recovery = redeploy a known-good image/revision (already have `rollback.yml`).
- **Why better:** Converts "hope" into proven, time-bounded recovery; PITR + off-project export are two independent layers; exports are portable standard formats in GCS.
- **Alternatives considered:** PITR only (rejected — 7-day window, no long-term/off-project copy); manual exports only (rejected — human-dependent, no PITR granularity); third-party backup SaaS (rejected — lock-in; native suffices).
- **Trade-offs:** Export storage cost; restore is a whole-collection operation (selective restore needs custom tooling).
- **Production impact:** Survives data-loss incidents with bounded RTO/RPO.
- **Cost impact:** GCS export storage (small–moderate, lifecycle-capped) + PITR premium on Firestore; tracked under ADR-018.
- **Security impact:** Backup bucket in a **separate project**, least-privilege access, encrypted at rest by default.
- **Scalability impact:** Exports scale with dataset size; scheduled off-peak.

## ADR-018 — Cost Governance

- **Current:** Partial controls exist: **AI daily caps** (`AI_DAILY_FREE_LIMIT`, per-user `aiUsage/{uid}_{date}`), Phase-2 N+1 query parallelization/pagination, and scale-to-zero for dev/staging (ADR-002). `docs/cost-model.md` exists. No budgets/alerts wired; no per-environment cost attribution.
- **Problems:** No spend ceiling or alerting — a runaway loop, abuse, or misconfig (Cloud Run min-instances, Firestore hot reads, AI overuse) can produce a surprise bill; no per-env visibility.
- **Recommended:**
  1. **GCP Budgets + alert policies per project** (dev/staging/prod) at 50/80/100% → email/Slack.
  2. **Cloud Run guardrails:** dev/staging `min-instances=0`; prod `min-instances=1` + a `max-instances` cap + tuned concurrency.
  3. **Firestore:** keep N+1 fixes; lifecycle-cap backups/exports (ADR-017).
  4. **AI spend:** legacy daily caps remain compatibility controls. The target
     primary controls are Orchestrator-coordinated request budgets, provider
     caps, NAJM AI Credits, ProviderUsageFacts, reconciliation, and the
     immutable usage ledger defined by the Phase 1 AI Platform documents.
  5. **Artifact Registry** cleanup policy (delete untagged/old images).
  6. **Label every resource by `env`** for attribution; review `docs/cost-model.md` monthly.
  Prefer portable levers (scale-to-zero, caps) over provider-specific commitments unless usage proves the savings (ADR-000).
- **Why better:** Makes spend bounded and observable instead of reactive; per-env attribution; caps neutralize abuse-driven bills.
- **Alternatives considered:** No budgets (rejected — unbounded risk); committed-use discounts now (deferred — premature commitment = lock-in without proven steady-state usage); third-party cost tool (rejected — native budgets suffice).
- **Trade-offs:** prod `min-instances=1` carries a small always-on cost (the latency/UX trade); alerts need a human owner to action.
- **Production impact:** Predictable spend + early warning.
- **Cost impact:** The controls are free and net-reduce spend.
- **Security impact:** Abuse caps double as a DoS-cost mitigation; `max-instances` bounds blast radius.
- **Scalability impact:** `max-instances` bounds both cost and load; `env` labels enable data-driven scaling decisions.

## ADR-019 — Health & Startup Dependency Verification

- **Current:** `main.py` `lifespan` checks **only `INTERNAL_SERVICE_TOKEN`** (fail-closed). `/health` returns a **static** payload — liveness only; it verifies no dependency. A service can therefore boot with broken Firestore creds, a missing AI key, or invalid config and only fail at request time.
- **Problems:** Misconfiguration surfaces late (at first request, per user); load balancers / uptime checks can route traffic to an instance that is up but not ready; no single place that answers "is this instance actually able to serve?"
- **Recommended:** Split **liveness** from **readiness** (12-factor / K8s-standard, portable).
  1. Keep **`/health`** as a cheap **liveness** probe (process is up) — used by the Cloud Run/K8s liveness check and the Dockerfile `HEALTHCHECK`.
  2. Add **`/ready`** — a **readiness** probe that verifies each dependency: Firestore reachable, Firebase Admin/Auth initialized, Storage bucket accessible, and every enabled AI route/Provider Adapter **configured** with its server-side secret binding present (never a paid call). It also validates required secrets and configuration, returns provider-neutral booleans rather than provider/model identity, and returns **503** if any *critical* dependency is down. Results are **short-TTL cached** so probes do not hammer dependencies.
  3. **Startup gate** (in `lifespan`): validate the **critical** config/secret set and **refuse to start (raise)** if any is missing — extending today's token-only check. **Critical** (refuse start): `INTERNAL_SERVICE_TOKEN`, Firebase credentials/project, Firestore reachability. **Optional** (start *degraded*, report via `/ready`): enabled AI route/adapter configuration and the OCR stack. Current provider-key status behavior remains legacy compatibility until migrated.
- **Why better:** Fail-fast on misconfiguration; a bad deploy fails readiness and is never promoted; LBs never route to unready instances; matches the portable liveness/readiness split used by both Cloud Run and Kubernetes (ADR-012).
- **Alternatives considered:** One `/health` doing everything (rejected — conflates the two; a slow dependency check on the liveness path can kill a healthy process); no readiness probe (rejected — the current gap).
- **Trade-offs:** Readiness makes lightweight dependency calls — bounded by timeouts + short-TTL caching.
- **Production impact:** Safer rollouts and autoscaling; misconfig caught at boot/readiness, not by users.
- **Cost impact:** Negligible (cheap, cached checks).
- **Security impact:** Readiness reports **booleans only** — never secret values or connection strings.
- **Scalability impact:** Cached readiness results prevent probe traffic from loading dependencies as instances scale.

## ADR-020 — Documentation & phase-reporting standard

- **Current:** Rich but ad-hoc docs (`NAJM_ARCHITECTURE.md`, `plans/`, `REMEDIATION_CHANGELOG.md`, this ADR file). No enforced per-change/per-phase standard.
- **Problems:** Knowledge drift; inconsistent handoff; the Engineering Master Directive requires every phase to produce what/why/how/maintain/rollback docs plus a structured completion report.
- **Recommended:** Docs-as-code, four tiers:
  1. **Decision record** — significant architectural decisions are appended to `docs/ARCHITECTURE_LOCK.md` (this file).
  2. **Per-phase report** — each phase stop produces `docs/phases/PHASE_<N>_<name>.md` using the fixed template: **Completed work · Files modified · Files added · Testing performed · Remaining issues · Risks · Rollback instructions**.
  3. **Runbooks** — operational procedures (deploy, rollback, DR/restore, incident) in `docs/` (extends the existing `devops-runbook.md`).
  4. **Component READMEs** stay per-directory; `CLAUDE.md` remains the agent-facing map.
  A phase is **not "done" until its report exists** — documentation is part of the definition of done.
- **Why better:** Durable, reviewable, version-controlled alongside the code it describes; satisfies the WORKFLOW rules; makes every change's rationale and rollback discoverable.
- **Alternatives considered:** External wiki/Notion (rejected — off-repo lock-in, drifts from code); no standard (rejected — the current state).
- **Trade-offs:** Per-phase documentation discipline (small, deliberate overhead).
- **Production impact:** Faster incident response via runbooks; safer team handoff.
- **Cost impact:** None.
- **Security impact:** Docs follow the same redaction rule — **no secrets in documentation** (values referenced by name only).
- **Scalability impact:** Docs-as-code scales with the repository and its history.

---

## Lock-in & reversibility register

| Area | Lock-in | Measurable benefit? | Exit path |
|---|---|---|---|
| Firebase / Firestore / Auth / Storage | 🔴 Deep | **Yes** — managed auth, rules, realtime + offline sync; pre-existing system of record | Firestore export (ADR-017); backend funnels **110 sites through one `get_firestore()` seam**; client coupling only **8 sites** |
| Cloud Run | 🟢 Low | Autoscale-to-zero, managed TLS | OCI + 12-factor → GKE/any host (ADR-012) |
| Secret Manager | 🟡 Med | Central rotation, per-env IAM | App reads `os.environ` — injection swappable, zero code change |
| Cloud Logging + Error Reporting | 🟢 Low | Free, native, zero-code | App emits portable JSON to stdout — pipe anywhere |
| External AI providers | 🟡 Med | Approved models may provide measurable capability/cost benefits | Product-neutral Orchestrator/Gateway contracts + Provider Adapters + versioned registries; migrate routes without product-module changes |
| WIF / Cloud Build / Artifact Registry / GitHub Actions | 🟢 Low | Keyless CI, standard registry | Standard OCI registry; portable to any CI |

**Net:** the only deep, hard-to-reverse dependency is **Firebase**, which clears the ADR-000 bar (measurable managed benefit + pre-existing foundation). Everything else is low/medium lock-in with a documented exit path.
