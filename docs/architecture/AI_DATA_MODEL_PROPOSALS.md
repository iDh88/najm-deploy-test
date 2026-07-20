# NAJM AI Platform — Data Model and Storage Proposals

**Status:** Approved for Phase 1 documentation, not yet implemented

**Phase:** Phase 1 — Architecture Documentation, Milestone 4

**Document role:** Authoritative conceptual data and storage architecture

**Last reconciled:** 2026-07-16

## Purpose

This document defines conceptual records, ownership, lifecycle, and storage
boundaries for the future provider-independent NAJM AI Platform. It provides a
common vocabulary for later design without creating Firestore collections,
code models, indexes, migrations, security rules, or implementation approval.

Firestore remains the approved MVP control-plane and operational store. The
collection names and field groups below are proposals, not exact physical
schemas. A later owner-approved implementation must validate transaction,
security-rule, IAM, regional, indexing, retention, and load requirements before
creating them.

## Scope

This document defines:

- Source-of-truth ownership for AI Platform data.
- Conceptual Firestore collection groups and responsibilities.
- Required record field groups rather than exact classes or schemas.
- Immutable event and versioned control-plane rules.
- Conceptual query and indexing considerations.
- Migration-marker and data-lifecycle principles.
- Retention classes and sensitive-data exclusions.
- Boundaries for existing Firebase and domain data.
- Scale-triggered boundaries for PostgreSQL, BigQuery, a Vector DB, Redis,
  Pub/Sub, and Cloud Tasks.
- Internal-alpha, paid-launch, and deferred storage scope.

## Non-goals

This document does not:

- Create a collection, document, index, rule, migration, queue, database, or
  data model in code.
- Approve exact collection names, nesting, document IDs, fields, types, index
  definitions, security rules, IAM bindings, or retention periods.
- Move existing domain collections into the AI Platform.
- Design a final payment, invoice, enterprise chargeback, or commercial
  pricing schema.
- Select PostgreSQL, BigQuery, a Vector DB, Redis, Pub/Sub, or Cloud Tasks for
  immediate implementation.
- Authorize raw AI payload, prompt-variable, roster, credential, payment, or
  token storage.
- Change current Firestore, Firebase Auth, subscription, roster, legality,
  knowledge, or deployment behavior.
- Begin Milestone 5 or any runtime implementation phase.

## Current legacy state

Current Firebase and application data remain governed by existing services:

- Firebase Auth, custom claims, users, and admin-user data establish identity,
  approval, and roles.
- Current subscription records and subscriptions-disabled behavior remain the
  commercial compatibility state.
- The legality-rule source and legalityRules data remain deterministic
  aviation authorities.
- Knowledge Engine documents, document versions, source objects, chunks, and
  retrieval metadata remain governed operational knowledge.
- Roster synchronization and normalized roster data remain under the Roster
  Sync service and zero-knowledge credential policy.
- Legacy aiUsage, usageCounters, and rate-limit records are request counters,
  not an AI credit ledger, balance, or invoice source.
- Current AI session records and caller-supplied chat history are legacy
  transcript behavior, not the approved Memory Layer.
- Direct Anthropic/OpenAI calls and embedded prompts remain legacy executable
  behavior.

No proposed collection in this document currently exists merely because it is
named here. Pre-existing repository data-quality, rules, migration, regional,
administrative, or operational concerns remain pre-existing issues; this
Milestone does not remediate or re-audit them.

## Approved target state

The future AI Platform uses Firestore initially for:

- Versioned internal control-plane records and active pointers.
- Compact Orchestrator decisions, Gateway attempt facts, safety events,
  incidents, provider health, audit events, and idempotency state.
- Non-billable/advisory usage and budget facts for internal alpha.
- Credit, reservation, immutable ledger, reconciliation, and administrative
  accounting records before paid launch only after the Milestone 3 design is
  implemented and proven.

The AI Platform does not absorb deterministic domain authorities or user
business records. It stores exact references to the versions and facts relied
upon. It keeps mutable current-state projections separate from immutable
history.

The logical topology remains:

    Product API
      -> AI Orchestrator and governed control-plane records
      -> AI Gateway
      -> Provider Adapter
      -> external provider

Clients, domain engines, tools, parsers, schedulers, and admin UIs never obtain
provider access. Data placement cannot create an alternate provider path.

## Source-of-truth hierarchy for AI Platform data

| Fact category | Authoritative owner | Explicit non-authorities |
|---|---|---|
| Identity, approval, and roles | Firebase Auth, custom claims, and governed user/admin records | AI output, memory, cache, provider claims |
| Subscription lifecycle | Subscription service and its governed commercial records | Provider usage, AI counters, model output |
| AI capability entitlement | Future Entitlement service derived from approved subscription, trial, and grant policy | Client hints, caches, provider tiers |
| Feature availability | Future server-side typed Feature Flag service | Flutter configuration, model output |
| Aviation legality and fatigue | Deterministic engines and governed rule source | Prompts, RAG text, provider output |
| Operational knowledge | Knowledge Engine active documents, versions, objects, and provenance | Generated summaries, embeddings, caches |
| Roster facts | Roster Sync and roster domain stores | AI memory, prompts, audit events |
| Trades, bids, and product effects | Existing deterministic product/domain services | Tools or model output without product authorization |
| Provider/model/prompt/route policy | Versioned AI registries and active policy pointers | Business-module constants, provider response |
| Orchestration policy decision | Immutable Orchestrator decision record | Gateway or adapter |
| Provider execution and native usage | Gateway/Adapter normalized attempt and ProviderUsageFact | Client counters |
| Credits, reservations, and accounting effects | Future Credit service plus immutable AI usage ledger | aiUsage, analytics, provider invoice alone |
| Safety and incident history | Append-only safety, audit, and incident events | Mutable dashboard projection |
| Analytics and caches | Derived views only | Any authorization, registry, credit, ledger, or domain authority |

Where a retained immutable event references a versioned asset, that version
must remain resolvable for the applicable retention class.

## Component responsibilities

### AI Orchestrator

- Reads authoritative registry, prompt, flag, entitlement, safety, incident,
  budget, and context policy through governed interfaces.
- Persists or requests persistence of immutable policy decisions and
  correlations.
- Coordinates credit reservation and reconciliation without directly mutating
  arbitrary account data.
- Does not expose internal control-plane records to clients.

### AI Gateway and Provider Adapters

- Return normalized attempt, provider usage, latency, error, and safety facts.
- Never write entitlements, credit balances, prompt activation, feature flags,
  or product business state.
- Do not store provider secrets in Firestore records.
- Use the Orchestrator-supplied request, attempt, model, and prompt references.

### Registry, Prompt, Feature, Entitlement, Safety, and Credit services

- Each owns validation and writes for its declared record family.
- Versioned services create immutable revisions and move small active pointers
  through governed server APIs.
- The Credit service is the only authority for reservation and balance
  projections; immutable ledger semantics follow Milestone 3.
- Safety and incident administration produces append-only evidence.

### Product and domain services

- Keep authority for product contracts and deterministic domain data.
- Pass references or approved minimal facts to the Orchestrator.
- Never select provider/model records or write AI ledger records directly.

### Administrative interfaces

- Call authenticated, least-privilege server administration APIs.
- Never write internal AI collections directly from a client.
- Never receive provider secrets, prompt variables containing sensitive data,
  native provider cost details intended only for finance, or raw audit
  payloads.

## Required boundaries

### Record classes

The target distinguishes:

- **Immutable revision:** an approved point-in-time definition of a provider,
  model, prompt, flag, entitlement, route, safety, or retention policy.
- **Active pointer:** a small mutable projection identifying an approved
  revision for an environment and scope.
- **Immutable event or fact:** what was decided, attempted, observed, charged,
  adjusted, suspended, or approved.
- **Mutable operational projection:** current request status, account balance,
  incident state, health summary, or delivery state derived from immutable
  facts and controlled commands.
- **Transient coordination record:** idempotency, lock, circuit, cache, outbox,
  or task state with bounded correctness semantics.
- **Derived analytical view:** rebuildable reporting that is never an
  operational authority.

### Ownership and access

- All proposed AI Platform collections are server-only unless a separately
  approved projection is expressly designed for a user.
- Users may receive their provider-neutral capabilities, balances, transaction
  summaries, and product results. They do not receive provider tokens, native
  usage quotas, prompt bodies, provider routes, adapter bindings, internal
  price facts, or other users' data.
- Administrative writes require server authorization, reason, idempotency, and
  audit evidence.
- Internal service identities must be narrower than a single unrestricted
  Admin SDK identity where the platform risk warrants separation.
- Firestore rules alone cannot protect Admin SDK writes; IAM, service
  ownership, application validation, audit, and reconciliation are required.

### Sensitive-data exclusions

The following must not be stored in AI registries, prompts, flags,
entitlements, usage records, ledger records, safety events, incidents,
analytics, vector indexes, queues, caches, or ordinary observability:

- Provider API keys, raw secret-manager payloads, or reusable secret URLs.
- INTERNAL_SERVICE_TOKEN, Firebase ID/refresh tokens, authorization headers,
  cookies, service-account credentials, or deployment credentials.
- Roster-provider PRNs, passwords, tokens, session state, or secret-bearing
  ICS/feed URLs.
- Payment credentials, card data, billing secrets, or unredacted receipts.
- Raw provider requests and responses.
- Raw model output, prompt variables, retrieved documents, tool payloads, or
  memory contents by default.
- Raw roster schedules in accounting, audit, registry, or incident records.
- Unnecessary user or organization PII.

Prompt bodies are allowed only inside server-only immutable Prompt Registry
versions. Each variable contract must declare allowed data class, purpose,
provider-transmission policy, retention behavior, and size bounds. This does
not authorize a prohibited secret as a variable.

## Proposed models or records

The following logical collections and field groups are proposed records only.
They define ownership and meaning without approving exact Firestore schemas.

### Proposed Firestore collection groups

All names are conceptual. The later physical design may consolidate, nest, or
rename them while preserving ownership and semantics.

#### Registry and route control plane

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| aiProviderRevisions | Immutable provider identity, adapter binding, approved data-policy references, lifecycle eligibility, and integrity hash | Immutable revision |
| aiProviderPointers | Sole environment-scoped current selection and suspension projection; references an eligible provider revision | Active pointer |
| aiModelRevisions | Immutable model mapping, capabilities, constraints, safety/data approvals, lifecycle eligibility, and effective price reference | Immutable revision |
| aiModelPointers | Sole current selection and suspension/deprecation projection; cannot make an ineligible revision executable | Active pointer |
| aiRoutePolicyRevisions | Approved feature/task routing and ordered fallback references outside business modules | Immutable revision |
| aiRoutePolicyPointers | Active route policy for environment and scope | Active pointer |

Provider and model records contain internal identifiers and references, not
provider secrets. GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, and future
providers are adapter-backed execution options, never product dependencies.
Immutable revisions define what an asset is and the conditions under which it
may be eligible. The active pointer is the single runtime projection for
current selection or suspension. Pointer state cannot override revision
eligibility; exact lifecycle serialization remains an implementation decision.

#### Prompt control plane

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| aiPromptFamilies | Stable semantic identity, capability, variable contract, and output-contract family | Controlled identity |
| aiPromptVersions | Immutable prompt body, typed variables, output contract, hash, evaluation evidence, and approvals | Immutable revision |
| aiPromptPointers | Environment-scoped active, suspended, or rollback version | Active pointer |

Runtime requests record the exact prompt version. Activation or rollback moves
a pointer and appends an audit event; it never edits the prompt body.

#### Feature, entitlement, safety, and retention control plane

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| aiFeatureFlagRevisions | Versioned typed enablement, rollout, deny, or degradation policy | Immutable revision |
| aiFeatureFlags | Direct-key current flag pointer and server-safe projection | Active pointer |
| aiEntitlementPolicyRevisions | Provider-neutral capability and quota-policy definitions | Immutable revision |
| aiEntitlementPolicyPointers | Active entitlement policy/catalog revision by environment and scope | Active pointer |
| aiEntitlementGrants | Approved subscription-, trial-, organization-, or admin-derived capability facts when implemented | Governed fact/projection |
| aiSafetyPolicyRevisions | Versioned safety classes, required authorities, output modes, and context/tool constraints | Immutable revision |
| aiSafetyPolicyPointers | Active safety policy by environment and scope | Active pointer |
| aiKillSwitches | Current server-authoritative global or scoped stop/degrade state | Mutable projection |
| aiRetentionPolicyRevisions | Approved retention, de-identification, legal-hold, and deletion-class policy | Immutable revision |
| aiRetentionPolicyPointers | Active retention-policy revision by environment and data class | Active pointer |

Entitlement records never name provider tokens or provider-specific quotas.
Kill-switch history lives in append-only audit and safety events, not only in
the mutable current projection.
Every Orchestrator decision embeds or references the exact feature and
entitlement evaluation snapshot required by
AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md. A separate high-volume evaluation
collection is not approved here; it requires a later retention and query need.

#### Requests, decisions, attempts, and provenance

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| aiRequests | Compact current status and references for a logical request; not financial truth | Mutable projection |
| aiOrchestrationDecisions | Exact policy inputs, version references, outcome, and reason codes | Immutable fact |
| aiGatewayAttempts | Attempt lifecycle, normalized route reference, timing, validation, and failure facts | Immutable fact or append-only lifecycle events |
| aiProviderUsageFacts | Provider-native usage, certainty, provider request reference, and collection method without payload | Immutable fact |
| aiProviderHealthFacts | Durable adapter/provider/model health transitions or incident evidence and expiry; not every probe | Immutable fact |
| aiProviderHealth | Current derived health projection used only as input to Orchestrator policy | Mutable projection |
| aiIdempotencyRecords | Scoped semantic fingerprint, state, and canonical outcome references | Transient correctness record |
| aiOutbox | Durable delivery intent and recovery state for later asynchronous consumers | Mutable delivery projection backed by immutable facts |

The exact split between a single compact attempt document and append-only
attempt lifecycle events remains open. The design must preserve unknown
execution outcomes and prevent duplicate provider calls.

Ordinary high-volume request telemetry follows the binding structured-JSON
stdout and Cloud Logging boundary in Architecture Lock ADR-009. Firestore
retains only the compact decisions, durable transitions, safety/audit facts,
usage/accounting evidence, and incident provenance that require operational
reproduction. AIObservabilityEvent is a logical event contract, not a mandate
to duplicate every log entry in Firestore.

#### Safety, incidents, and audit

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| aiSafetyDecisions | Aviation classification, safety policy version, authority requirements, outcome, and reasons | Immutable fact |
| aiSafetyEvents | Injection, grounding, output, tool, memory, cache, or incident safety facts | Append-only event |
| aiIncidents | Current incident scope, response mode, status, and recovery projection | Mutable projection |
| aiIncidentEvents | Incident declaration, scope change, containment, review, recovery, and closure history | Append-only event |
| aiAuditEvents | Administrative approval, activation, suspension, rollback, break-glass, and correction evidence | Append-only event |

Raw leaked content must not be copied into incident records. Use a separately
approved, access-controlled evidence process if one is ever required.

#### Credits, ledger, budget, cost, and margin

Milestone 3 is authoritative. The conceptual logical collections that may be
needed before paid launch include:

| Proposed logical collection | Responsibility |
|---|---|
| aiCreditAccounts | Provider-neutral account identity and balance projection |
| aiCreditPools | User, family, corporate, or enterprise funding-pool projection when approved |
| aiCreditReservations | Reservation state, estimate, expiry, and final transaction references |
| aiCreditReservationEvents | Append-only request, authorization, amendment, release, expiry, reconciliation, and correction provenance |
| aiCreditTransactions | Immutable credit effects and linked correction chains |
| aiUsageLedgerEvents | Append-only billing and usage source of truth |
| aiBudgetDecisions | Immutable pre-execution policy result |
| aiCostEstimates | Effective-dated internal cost estimate and certainty |
| aiCostReconciliations | Estimate, actual ProviderUsageFact, variance, and completion status |
| aiMarginSnapshots | Derived versioned finance view, never a charging authority |
| aiRefundAdjustments | Append-only refund or dispute accounting effect |
| aiAdminCreditOverrides | Authorized grant, restriction, emergency credit, or correction command and evidence |
| aiEnterpriseAllocations | Future organization-to-member allocation facts |

These names do not approve exact schema, account hierarchy, burn rate,
reservation lifetime, pool precedence, pricing, or billing integration. Legacy
daily counters remain separate compatibility data and must never be converted
into opening balances or invoice-grade history without explicit owner policy.
The reservation document is a current projection only. Every material
reservation transition requires its own immutable event as specified by
Milestone 3.

#### Migration and experimentation

| Proposed logical collection | Responsibility | Record class |
|---|---|---|
| _migrations, AI-scoped entries | Global ADR-014 marker convention carrying forward-only AI migration identity, checksum, environment, revision, cursor/count summary, and result | Immutable completion evidence plus controlled progress projection |
| aiCompatibilityEvidence | Approved contract, prompt, route, output, safety, cost, and rollback comparison references | Immutable evidence |
| aiExperiments | Disabled placeholder for a future governed experiment identity if separately approved | Deferred; no runtime authority |

The experiment placeholder does not authorize experimentation, shadow traffic,
traffic allocation, or a collection in internal alpha.
AI migrations use the repository-wide _migrations/{id} convention from
Architecture Lock ADR-014. This document does not create a second
aiMigrationMarkers authority.

### Proposed document field groups

These groups describe meaning, not exact field names or types.

#### Common identity and lifecycle

- Stable logical key and immutable revision or event ID.
- Environment, tenant or organization scope where applicable.
- Schema version and record kind.
- Created, occurred, effective, expiry, suspended, deprecated, and retired
  time semantics as applicable.
- Actor or system identity reference and authorization basis.
- Status projection separate from immutable history.

#### Governance and integrity

- Owner, author, reviewer, approver, and reason references.
- Predecessor or superseded revision.
- Content or semantic hash and integrity metadata.
- Activation, suspension, rollback, and incident references.
- Data class, retention class, region-policy reference, and legal-hold state.
- Audit-event and idempotency references.

#### Request and execution correlation

- Logical request, Orchestrator decision, safety decision, Gateway attempt,
  provider usage, product transaction, and trace references.
- Feature, task, prompt, provider, model, route, flag, entitlement, safety,
  incident, budget, price, RAG, memory, cache, and tool version references.
- Normalized outcome, reason codes, timing, deadline, retry, certainty, and
  validation summaries.
- No raw prompt, response, credential, or unnecessary personal data.

#### Financial and accounting correlation

- Credit account, pool, reservation, transaction, ledger event, provider usage,
  cost estimate, reconciliation, refund, dispute, and billing-period
  references.
- Original estimate, reservation, actual usage, final burn, adjustment chain,
  currency for internal costs, and policy versions as defined in Milestone 3.
- Provider-native units remain internal facts and never become user-facing
  balances or quotas.

#### Provenance and safety

- Deterministic rule or engine version.
- Knowledge source, document version, chunk reference, activation state, and
  retrieval evidence.
- Safety classification, required authority, validation result, refusal or
  degradation mode, and linked incident.
- Tool contract and result provenance without storing sensitive payloads.

## Required semantics

### Immutability and versioning rules

- A material control-plane change creates a new immutable revision.
- Each revision carries its own identity, predecessor, hash, governance,
  effective semantics, and schema version.
- Activation is a small transactional pointer change accompanied by an
  append-only audit event.
- Rollback points to a prior approved revision; it does not rewrite or clone
  history to conceal the failed revision.
- Requests record exact revisions used, not merely current names.
- Safety, audit, incident, provider usage, budget, credit transaction, usage
  ledger, reconciliation, and refund facts are append-only.
- Corrections are compensating or superseding events linked to originals.
- Balances, request status, provider health, incident status, and active
  pointers are mutable projections and must be rebuildable or reconcilable.
- Referenced versions cannot be deleted while retained events require them.
- A schema evolution uses an explicit schema version and a governed migration;
  readers do not infer meaning from missing fields.

### Audit and event-record requirements

Each append-only event family must support:

- Globally unique event identity and stable correlation.
- Idempotent command or source-event reference.
- Actor or system origin and authorization basis.
- Occurred and recorded times.
- Environment, scope, record kind, schema version, and retention class.
- Exact asset and policy revisions in effect.
- Reason codes and redacted facts sufficient to reproduce the decision.
- Predecessor, correction, reversal, or compensating-event links.
- Integrity and delivery status where asynchronous export is later approved.

The event store is evidence, not a command channel. A replay cannot repeat a
provider call, credit effect, or administrative action without its own
idempotency and authorization checks.

### Conceptual indexes and query shapes

Exact index definitions require later measured workloads and owner approval.
The conceptual design must support:

- Direct lookup of active pointer by environment and stable key.
- Direct lookup of an immutable revision by stable identity.
- Revisions by asset identity and effective or created time.
- Entitlements by principal, capability, status, and validity window.
- Requests and decisions by logical request and created time.
- Attempts and provider usage facts by logical request or attempt.
- Provider health by environment, adapter/provider/model scope, and freshness.
- Safety and incident events by incident, scope, type, and occurred time.
- Ledger events by account and occurred time, logical request, reservation, or
  transaction reference.
- Cost facts by provider billing period and reconciliation status.
- Idempotency by scope and semantic key.
- Migration evidence by environment, migration identity, and result.

Prefer deterministic document IDs and explicit revision references over broad
capability-array scans. Exempt prompt bodies, large structured assets,
diagnostic blobs, embeddings, and other non-query content from unnecessary
indexing. Date or partition keys are introduced only when measured volume
requires them. Sensitive content is neither indexed nor stored.

### Data-retention classes

Every record carries an approved retention-class reference. Conceptual classes
are:

| Class | Examples | Principle |
|---|---|---|
| Control-plane history | Provider, model, prompt, route, flag, entitlement, safety, and retention revisions | Retain while active or referenced by retained evidence; preserve approval history |
| Financial and dispute evidence | Ledger, credit transaction, provider usage, reconciliation, refund, admin override | Governed by finance, tax, dispute, and legal-hold requirements |
| Safety, security, and incident evidence | Safety decisions, kill-switch events, admin audit, incident history | Audit-grade, access-controlled, redacted, and legal-hold aware |
| Operational telemetry | Compact request, attempt, latency, normalized error, health | Bounded operational lifetime; minimize and aggregate |
| Content-bearing evaluation | Separately approved evaluation samples | Prohibited by default; isolated, purpose-limited, and shorter-lived if approved |
| Transient correctness state | Idempotency, outbox delivery, locks, circuits, cache | Retain through the longest correctness/replay window, then expire safely |
| Migration evidence | Marker, checksum, validation and rollback-window reference | Retain long enough to prove and repair schema history |
| Derived analytics | Dashboards, aggregates, forecasts | Rebuildable; never longer or broader than source policy permits |

Exact durations, residency, legal bases, deletion/de-identification behavior,
legal holds, and archive mechanisms remain open. Account deletion must
de-identify personal references where legally permitted while preserving
required immutable accounting and security evidence.

### Data lifecycle

#### Control-plane asset

1. Draft outside active runtime use.
2. Validate and review through a governed server workflow.
3. Publish an immutable revision with an integrity hash.
4. Activate a pointer with authorization and an audit event.
5. Observe use by exact revision references.
6. Suspend, deprecate, retire, or roll back by pointer or lifecycle policy.
7. Retain referenced history under the applicable class.

#### Operational request

1. Create or derive a logical request ID and idempotency scope.
2. Record policy/safety/budget decisions and exact version references.
3. Record each Gateway attempt and ProviderUsageFact without payload.
4. Correlate usage, cost, ledger, and product outcome.
5. Finalize the current request projection.
6. Retain, minimize, de-identify, or expire by record class.

#### Migration marker

Future data migrations must be forward-only, numbered, checksummed,
idempotent, environment-scoped, dry-run capable, and resumable. A marker
records deployment revision, schema version, progress or completion, counts,
validation result, and rollback-window reference. Retries use deterministic
target identities and cannot duplicate records. Corrections use a new
compensating migration, not destructive history edits.

This describes required semantics only. It does not create a migration or
approve an exact marker schema.

### Future storage boundaries

#### Firestore — MVP authority

Firestore remains the MVP store for versioned AI control-plane configuration,
compact decisions and facts, incident/audit evidence, idempotency, and
internal-alpha advisory accounting. It may remain the paid-launch credit and
ledger store only if later implementation proves atomic reservation,
append/projection consistency, reconciliation recovery, contention, backup,
restore, and dispute requirements.

#### Cloud Storage — existing governed content boundary

Existing Knowledge Engine source objects remain in governed Cloud Storage,
with Firestore document/version metadata, hashes, provenance, and the current
small-corpus knowledge-chunk representation. Firestore may hold a prompt body
or an immutable object reference; exact Prompt Registry asset placement
remains open. Any later large prompt or evaluation asset uses governed object
storage only after data-class, integrity, access, retention, and deletion
approval. Object storage never contains AI Platform secrets or ordinary raw
telemetry.

#### PostgreSQL — deferred ledger boundary

Defer PostgreSQL until measured requirements such as hot shared pools,
relational double-entry constraints, split funding, contention, complex
reconciliation, or transactional reporting exceed a proven Firestore design.
If approved later, PostgreSQL becomes the single ledger authority and
Firestore may hold user-facing projections only. Dual authority is forbidden.

#### BigQuery — deferred analytical boundary

BigQuery is an analytical sink for compact, de-identified, retention-approved
events after volume and reporting needs justify it. It never authorizes users,
routes models, enforces safety, owns balances, or becomes the invoice-grade
ledger.

#### Vector DB — deferred retrieval boundary

A dedicated Vector DB is deferred until corpus size, filtering, recall,
latency, or tenancy needs demonstrably exceed the approved MVP retrieval
design. Knowledge documents and versions remain authoritative in the Knowledge
Engine and object storage. Vectors are derived data and must record embedding
model revision, dimension, source version, chunk identity, and deletion
provenance. Incompatible embedding spaces cannot be mixed.

#### Redis — deferred ephemeral boundary

Redis may later hold ephemeral cache, circuit, coordination, or distributed
rate state when measured multi-instance needs justify it. It never holds the
only copy of entitlements, registries, prompts, kill switches, balances,
ledger events, or aviation facts. Its loss is a miss or controlled
fail-closed condition, not a permission grant.

#### Cloud Tasks — deferred durable-work boundary

Cloud Tasks is deferred until a measured volume, reliability, or delayed-work
requirement justifies it and the owner separately approves it. Possible later
uses include reservation expiry, reconciliation, webhook replay, and
provider-success/accounting-failure recovery. Tasks are delivery mechanisms,
not source-of-truth records. Every task requires an authoritative record,
idempotency, authorization, deadline, and terminal outcome.

#### Pub/Sub — deferred fan-out boundary

Pub/Sub is deferred until multiple independent consumers or event throughput
justify fan-out. Publishing must originate from an authoritative transactional
outbox or equivalent approved mechanism. Consumers assume at-least-once
delivery and deduplicate. Pub/Sub never becomes operational policy or ledger
authority.

## Failure and fallback semantics

| Condition | Required data behavior |
|---|---|
| Firestore control configuration unavailable | Critical registry, prompt, flag, entitlement, safety, incident, or budget uncertainty denies provider execution |
| Active pointer missing or references invalid revision | Treat asset as unavailable or suspended; do not use a business-module constant |
| Safety policy unavailable | Record or recover the denial fact; no provider execution |
| RAG source or retrieval unavailable | Preserve source/retrieval failure provenance; do not record fabricated evidence |
| Memory unavailable | Continue only if optional policy permits; never substitute another user or tenant |
| Cache unavailable | Use authoritative store if permitted; otherwise controlled unavailable; cache never becomes truth |
| Tool denied or timed out | Record normalized outcome and unknown side-effect state where applicable; idempotency prevents blind replay |
| Provider outage, unsafe output, or malformed output | Append attempt and validation facts; product state and ledger handling follow Orchestrator and Milestone 3 policy |
| Model or prompt suspended | Pointer and audit history remain; requests cannot resolve to the suspended revision |
| Prompt injection detected | Store a redacted reason-coded event, not the injected content by default |
| Safety incident active | Kill-switch projection and immutable event determine deny/degrade behavior |
| Ordinary observability write failure | Do not fall back to raw logging; use approved recovery or controlled degradation |
| Mandatory audit write failure before execution | Fail closed |
| Mandatory audit or ledger write failure after provider success | Preserve a pending recovery/idempotency fact without repeating provider execution |
| Idempotency store unavailable | Do not execute a request whose duplicate financial or consequential effect cannot be ruled out |
| Outbox or task delivery duplicates | Consumer deduplicates by authoritative event/command ID |
| Fallback route unavailable or legacy fallback disabled | Return controlled unavailable, abstained, or deterministic-only; never use a direct provider path |
| Rollback requested | Move approved pointers or deployment routing; retain revisions, events, usage, and migration evidence |

Exact transactional recovery and index design remain implementation decisions.
They must not create dual authorities or mutate immutable evidence.

## Architectural decisions

### AI-DM-001 — Firestore remains the MVP AI Platform configuration and operational store

- **Decision:** Firestore is the initial authority for AI control-plane records,
  compact operational facts, audit, safety, incident, idempotency, and
  internal-alpha advisory accounting.
- **Rationale:** It aligns with current Firebase operations and minimizes new
  infrastructure before measured need.
- **Alternatives considered:** Immediate PostgreSQL control plane; BigQuery as
  event authority; a separate database per AI component.
- **Accepted trade-offs:** Physical design must respect document transactions,
  contention, query, cost, and backup limits.
- **Security impact:** Server-only access, narrow service identities, rules,
  IAM, validation, and audit are required; Admin SDK access cannot be assumed
  safe by default.
- **Cost impact:** Avoids premature infrastructure while Firestore reads,
  writes, indexes, retention, and exports must be monitored.
- **Scalability impact:** Event partitioning or later store separation occurs
  only at measured thresholds.
- **Migration impact:** New records are introduced through future approved,
  idempotent migrations; existing domain collections are not repurposed.
- **Implementation priority:** Conceptual design before internal alpha;
  paid-ledger suitability must be proven before paid launch.

### AI-DM-002 — Immutable events are append-only

- **Decision:** Usage, credit, provider usage, budget, safety, incident,
  administrative, and migration facts are never overwritten; correction is a
  linked compensating or superseding event.
- **Rationale:** Reproducible decisions, incident review, billing disputes, and
  rollback require historical truth.
- **Alternatives considered:** Mutable status documents as the only record;
  log-only history; destructive correction.
- **Accepted trade-offs:** Mutable projections and immutable facts must both be
  maintained and reconciled.
- **Security impact:** Enables tamper detection and accountability but requires
  restricted writers and integrity monitoring.
- **Cost impact:** Append-only growth requires retention classification and
  eventual archival or analytical strategies.
- **Scalability impact:** Stable event IDs, correlation, and later partitioning
  are required at volume.
- **Migration impact:** Legacy counters and logs cannot be relabeled as complete
  immutable history.
- **Implementation priority:** Must implement before internal alpha for
  target-generated facts; audit-grade controls before paid launch.

### AI-DM-003 — Runtime registries use versioned records and active pointers

- **Decision:** Material configuration is immutable by revision; a small
  governed pointer selects the active approved revision by environment and
  scope.
- **Rationale:** Exact reproduction, safe activation, suspension, and rollback
  require both stable history and efficient runtime resolution.
- **Alternatives considered:** Editing one current document; constants in
  business modules; embedding fallback configuration in code.
- **Accepted trade-offs:** Pointer/revision consistency, reference retention,
  and cache invalidation must be designed explicitly.
- **Security impact:** Activation is a privileged, audited action and prompt or
  route history cannot be silently altered.
- **Cost impact:** Adds small revision and audit write volume while avoiding
  broad scans.
- **Scalability impact:** Direct IDs and active pointers support predictable
  lookups across instances.
- **Migration impact:** Existing constants remain legacy until captured,
  validated, and activated through later approved migration.
- **Implementation priority:** Must implement before internal alpha for assets
  used by alpha capabilities.

### AI-DM-004 — Sensitive secrets and raw credentials are excluded from AI Platform records

- **Decision:** Provider, service, Firebase, payment, and roster credentials
  and raw sensitive content never enter AI Platform records, queues, vector
  stores, caches, or ordinary telemetry.
- **Rationale:** The AI Platform needs references and policy facts, not reusable
  secrets or unrestricted payload archives.
- **Alternatives considered:** Storing encrypted credentials in Firestore;
  full request/response logging; embedding credentials in prompt variables.
- **Accepted trade-offs:** Debugging relies on redacted facts and controlled
  reproduction; providers obtain secrets through adapter-scoped server secret
  access.
- **Security impact:** Preserves zero-knowledge roster boundaries and limits
  breach impact.
- **Cost impact:** Reduces storage and incident exposure; may require separate
  approved forensic handling.
- **Scalability impact:** Data minimization reduces index and event volume.
- **Migration impact:** Legacy content logs and transcripts require later
  classification and remediation, not automatic import.
- **Implementation priority:** Must implement before internal alpha.

### AI-DM-005 — Additional storage technologies are deferred by explicit scale triggers

- **Decision:** PostgreSQL, BigQuery, a dedicated Vector DB, Redis, Pub/Sub, and
  Cloud Tasks are introduced only after their stated measured-scale or
  operational trigger and separate owner approval.
- **Rationale:** Logical boundaries should be durable without imposing
  premature infrastructure or dual authorities.
- **Alternatives considered:** Adopt the complete enterprise stack before MVP;
  forbid future store specialization.
- **Accepted trade-offs:** Firestore and bounded in-process behavior must be
  measured carefully, and later migrations remain possible.
- **Security impact:** Each future store requires separate residency,
  encryption, IAM, retention, deletion, and incident approval.
- **Cost impact:** Deferral controls fixed cost; later adoption is justified by
  measured savings, correctness, or capacity.
- **Scalability impact:** Clear triggers preserve paths for transactional,
  analytical, retrieval, caching, queuing, and fan-out scale.
- **Migration impact:** A future move names one authority, validates parity,
  maintains rollback evidence, and never leaves indefinite dual truth.
- **Implementation priority:** Deferred until an explicit measured trigger
  justifies the relevant technology.

## Security considerations

- All control-plane and immutable records are server-only by default.
- Service ownership and IAM must prevent Gateway/adapters from changing
  policy, entitlements, balances, or prompts.
- User-visible projections remain provider-neutral and tenant-scoped.
- Encryption, residency, backup, restore, and deletion requirements apply to
  every approved store and export.
- Direct admin-client Firestore writes are not approved for AI control-plane or
  ledger administration.
- Immutable semantics require application validation, idempotency, narrow
  writers, reconciliation, and tamper monitoring in addition to Firestore
  rules.
- Prohibited secrets and raw content are excluded at collection, queue, cache,
  vector, export, and telemetry boundaries.

## Cost considerations

- Firestore read/write/index/storage cost must be measured per event family and
  not justified solely by old planning estimates.
- Active pointers and deterministic IDs avoid broad queries.
- High-volume telemetry may be sampled or aggregated only when it is not
  required audit, safety, usage, or ledger evidence.
- Prompt bodies, embeddings, and large non-query data should not be
  unnecessarily indexed.
- BigQuery, Redis, PostgreSQL, Pub/Sub, and a Vector DB require explicit total
  cost and operational ownership before adoption.
- Internal provider usage and cost remain separate from user-facing NAJM AI
  Credits.

## Scalability considerations

- Logical ownership remains stable if components later become separate
  services or stores.
- Hot shared credit pools, event volume, query latency, index limits, retry
  volume, and contention are measured triggers, not assumptions.
- Use direct identities, immutable revisions, bounded projections, and
  idempotent events.
- Analytical exports are downstream and recoverable from retained authorities.
- A Vector DB stores derived representations; source documents remain governed
  elsewhere.
- Multi-region active-active control and accounting are deferred because they
  require explicit consistency, residency, and incident semantics.

## Migration considerations

- Create no proposed collection during Phase 1.
- A later implementation must inventory ownership, approve exact names and
  rules, dry-run changes, write schema versions, and use idempotent markers.
- Existing aiUsage and usageCounters remain legacy counters and are not opening
  balances or ledger events.
- Existing prompts/models become immutable revisions only after captured
  compatibility evidence and approval.
- Existing transcript data does not automatically migrate into governed
  memory.
- Existing embeddings cannot be mixed with vectors from an incompatible model
  or dimension; a future migration requires a separately governed index and
  re-embedding/cutover strategy.
- Rollback retains new revisions, events, ledger facts, and migration evidence
  while restoring an approved active pointer or runtime route.
- Existing domain collections stay under their current service owners.
- The completed Phase 0 reports remain the authority for pre-existing
  implementation blockers. Before affected AI collections are implemented, a
  later approved phase must verify or explicitly accept the recorded rules,
  domain-ownership, schema-consistency, migration-runner, residency/retention,
  admin-governance, and backup/restore dependencies. Milestone 4 neither
  re-audits nor changes their status.

## Delivery classification

### Must implement before internal alpha

- Approved conceptual collection ownership and exact implementation design for
  only the alpha-enabled capabilities.
- Firestore control-plane revisions and active-pointer semantics.
- Server-only access and prohibited-data enforcement.
- Compact, redacted request, decision, attempt, usage, safety, audit, and
  idempotency record shapes.
- Server-authoritative kill-switch projection plus append-only history.
- Safety policy classification and deterministic-only behavior represented in
  the decision and event records.
- Non-billable or advisory budget and usage classification.
- Forward-only, idempotent migration markers for any introduced data.
- Clear separation from legacy Free/Pro counters and existing domain data.
- Wrapper-first migration correlation fields.

### Must implement before paid launch

- Proven Firestore transaction and recovery design for enforced reservations,
  credit projections, ledger append, reconciliation, and idempotency, or a
  separately approved single authoritative alternative.
- Audit-grade retention classes, access review, backup, restore, reconciliation,
  legal hold, and de-identification behavior.
- Governed prompt/model/provider suspension and incident records.
- Tested incident procedures and recovery evidence.
- Ledger, Budget Controller, credits, provider usage, cost, margin, safety, and
  observability correlation.
- Admin-reviewed control-plane and accounting writes with break-glass evidence.
- Technology-neutral durable recovery for provider-success/accounting-failure
  and reservation expiry.
- Migration away from direct provider paths for billable features.

### Deferred until scale justifies it

- Independent SIEM integration.
- Advanced experimentation platform and aiExperiments activation.
- Dedicated Vector DB.
- PostgreSQL ledger migration.
- BigQuery analytics export.
- Redis distributed cache and rate limiter.
- Pub/Sub event lake and multi-consumer fan-out.
- Cloud Tasks workflow infrastructure.
- Fully automated enterprise chargeback.
- Multi-region active-active AI Platform.
- Shared family, corporate, and enterprise pool optimization beyond approved
  commercial need.

## Open questions

- What exact physical collection names, nesting, document IDs, field types, and
  writer services will be approved?
- What first internal-alpha capabilities determine the minimum record set?
- Which registry, prompt, flag, entitlement, safety, route, and retention
  changes require dual control?
- What exact retention periods, legal bases, residency, archive, legal-hold,
  deletion, and de-identification rules apply?
- What Firestore regional configuration, backup, point-in-time recovery, and
  restore evidence is required?
- Which query volumes and transaction-contention thresholds trigger
  partitioning or PostgreSQL?
- What corpus, latency, recall, and tenancy thresholds trigger a Vector DB?
- What event volume and consumer count trigger BigQuery or Pub/Sub?
- What multi-instance latency and correctness need triggers Redis?
- Which delayed workflows justify Cloud Tasks before paid launch?
- What exact idempotency and outbox retention windows satisfy retries,
  reconciliation, refunds, and disputes?
- How will existing transcript data be classified, retained, deleted, or
  excluded from future memory?
- Which embedding model/dimension migration and re-index policy will be
  approved?
- What policy, if any, governs opening balances; legacy counters alone cannot
  decide them.

These questions are explicitly unresolved. The collection proposals do not
authorize an implementation team to choose exact schemas, indexes, retention,
routes, or migrations without the required approvals.

## References

- AI_PLATFORM_OVERVIEW.md
- AI_ORCHESTRATOR.md
- AI_GATEWAY_AND_PROVIDER_ADAPTERS.md
- AI_REGISTRIES.md
- PROMPT_REGISTRY.md
- AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md
- AI_CREDITS_LEDGER_AND_BILLING.md
- AI_SAFETY_OBSERVABILITY_AND_INCIDENTS.md
- AI_MIGRATION_STRATEGY.md
- NAJM_ARCHITECTURE.md
- docs/ARCHITECTURE_LOCK.md
- docs/SECRETS.md
- docs/devops-runbook.md
- docs/cost-model.md
- docs/ROSTER_SYNC.md
- docs/ZERO_KNOWLEDGE_CREDENTIALS.md
- docs/openapi.yaml, current compatibility evidence only
- docs/api-contract.yaml, current compatibility evidence only
- reports/SECURITY_REPORT.md
- reports/ARCHITECTURE_REPORT.md
- reports/RELEASE_READINESS.md
- firebase/functions/src/index.ts, current-state evidence only
- .env.example, current-state evidence only
