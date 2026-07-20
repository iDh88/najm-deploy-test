# NAJM AI Feature Flags and Entitlement Integration

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation, Milestone 2
**Document role:** Authoritative target-state access-policy contract
**Last reconciled:** 2026-07-16

## Purpose

This document defines how AI feature flags and entitlements participate in the
approved NAJM AI Platform.

Feature flags answer whether an AI capability is operationally available for a
request scope. Entitlements answer whether an authenticated actor is allowed to
use that available NAJM capability. They are independent decisions and neither
can bypass authentication, aviation safety, budget, credits, registry state,
or incident controls.

The AI Orchestrator combines these decisions before any AI Gateway execution.
Product APIs, domain engines, clients, tools, Gateways, and Provider Adapters
cannot grant themselves access or call an AI provider directly.

## Scope

This document defines:

- Feature availability, rollout, and kill-switch boundaries.
- Entitlement and subscription integration.
- Decision precedence and fail-closed behavior.
- Current Free/Pro compatibility requirements.
- Server-side enforcement and client-display boundaries.
- Versioning, caching, provenance, rollback, security, cost, scalability, and
  migration considerations.
- Conceptual feature-flag and entitlement-decision models.

## Non-goals

This document does not:

- Create feature flags, entitlements, Firestore collections, rules, indexes,
  endpoints, claims, administration UI, or runtime evaluators.
- Change current subscription behavior, Free/Pro scaffolding, trials, limits,
  referrals, or launch configuration.
- Introduce a new subscription tier, price, feature matrix, or provider/model
  promise.
- Define RevenueCat SDK, webhook, receipt, renewal, refund, restore, or store
  behavior.
- Define NAJM AI Credits, burn rates, reservations, pools, ledger events,
  billing, cost, or margin formulas.
- Select internal-alpha capabilities, flag keys, cohorts, providers, models,
  prompts, or fallback routes.
- Define incident operations, observability storage, or Firestore data models
  assigned to later milestones.

## Current legacy state

Current repository documentation describes:

- A Firestore subscription configuration and feature-gate scaffold.
- A subscription master switch intended for a Free launch.
- Free/Pro-oriented user and subscription state.
- Daily AI usage counters and an AI daily limit.
- Firebase Auth, approval claims, and administrator claims.
- Feature checks distributed across Python, Cloud Functions, Flutter, and
  legacy user fields.

The completed Phase 0 audit found that current feature and subscription
scaffolding is not consistently enforced by real feature routes and that some
client gating can fail open. That is a pre-existing implementation issue.
Milestone 2 does not fix, re-audit, or change it.

Historical documents disagree about some current limit/configuration details.
They remain dated evidence of executable or intended legacy behavior, not the
approved target architecture.

The current launch directive remains:

- Subscription logic stays Free/Pro-oriented.
- Subscriptions remain disabled for the Free launch until later approval.
- Existing behavior remains backward-compatible.

No target feature-flag catalog or entitlement service is implemented today.

## Approved target state

### Separate policy concepts

| Concept | Question answered | Cannot answer |
|---|---|---|
| Authentication | Who is the caller and is the credential valid? | Whether an AI feature is available or purchased |
| Account approval/authorization | May this actor use this Product API and data? | Provider/model route or subscription value |
| Incident kill switch | Must execution stop or degrade now? | Whether a user owns an entitlement |
| Feature flag | Is this NAJM capability available for this environment/scope? | Whether the actor paid or has credits |
| Entitlement | May this actor use this available NAJM capability and service level? | Whether the provider route is safe/healthy |
| Budget/AI Credit decision | May this request consume the required spend/credits? | Feature availability or safety |
| Safety policy | May AI participate in this aviation-sensitive task and under what controls? | Commercial entitlement |
| Registry/prompt route | Is an approved compatible execution route available? | User access or payment status |

An allow result from one concept never overrides a deny from another.

### Target evaluation flow

    FastAPI Product API
      -> authenticates and authorizes the actor and product operation
      -> AI Orchestrator
          -> evaluates applicable incident kill switches
          -> evaluates versioned AI feature flags
          -> requests authoritative entitlement decision
          -> evaluates safety requirements
          -> requests budget/AI Credit decision when applicable
          -> resolves approved prompt/model/provider route
          -> AI Gateway only when every mandatory decision allows

This is a responsibility model, not a required runtime evaluation order.
Denials are compositional and fail closed.

### Deny-dominant rules

- Invalid authentication or authorization denies the Product API operation.
- An applicable global, feature, provider, model, prompt, or safety kill switch
  denies or explicitly degrades AI execution.
- A disabled or nonmatching feature flag denies AI execution.
- Missing required entitlement denies AI execution.
- Missing budget or AI Credit authorization denies billable AI execution.
- Missing safety grounding or deterministic authority denies or returns
  deterministic-only/UNKNOWN behavior as the approved feature requires.
- Missing registry, prompt, adapter, or route approval denies provider
  execution.
- A subscription, trial, grant, flag, or client state cannot override any of
  these denials.

Deterministic aviation engines and governed operational sources remain
authoritative and independently usable when product policy permits, even when
AI execution is disabled.

## Component responsibilities

### Feature Flag service owns

- Typed AI feature-availability and kill-switch policy.
- Environment-scoped configuration.
- Safe default and source precedence.
- Optional approved targeting/rollout rules.
- Version, effective time, expiry, owner, change reason, and evaluation ID.
- Bounded server-side cache semantics.

### Feature Flag service does not own

- Subscription products or payment lifecycle.
- Entitlement grants.
- Provider/model/prompt selection.
- Budget or AI Credit balance.
- Aviation safety or deterministic rules.
- Business transactions.

### Entitlement service owns

- Authoritative actor-to-NAJM-capability access decision.
- Service-level and usage-limit facts derived from an approved commercial,
  trial, grant, organization, or compatibility source.
- Effective period, status, source, version, and reason.
- Decision ID and provenance for orchestration/audit.

### Entitlement service does not own

- Feature operational availability.
- Incident kill switches.
- Provider/model selection or promises.
- Provider token accounting.
- Budget or AI Credit ledger.
- Aviation safety policy.
- Product business writes.

### Subscription system owns

- Current or future subscription product and lifecycle state.
- Mapping an approved subscription product to NAJM entitlements.

The AI Orchestrator consumes entitlement decisions. It does not read a
provider-specific tier promise or choose a model based directly on a
subscription label.

### AI Orchestrator owns

- Combining trusted actor context, flags, entitlement, safety, budget/credits,
  registry, prompt, and incident policy.
- Recording every decision version and reason.
- Denying, degrading, or continuing provider-neutral orchestration.

### Product APIs own

- Authentication boundary, product authorization, request validation, public
  compatibility, and business transaction.
- Calling the Orchestrator for AI work.

Product APIs must not infer provider access from a client flag, subscription
label, or cached UI state.

### Flutter and other clients own

- Displaying feature availability and upgrade/degraded states as user
  experience hints.
- Refreshing server-authoritative state when required.

Client state is never the enforcement authority. Hiding a screen is not an
entitlement check.

## Binding feature-flag architecture

ADR-016 remains the approved baseline:

- Firestore-backed configuration.
- Typed accessors.
- Bounded TTL caching.
- Fail-closed safe defaults.
- Source precedence of Firestore flag, then environment value, then hardcoded
  safe default.
- Environment isolation through separate Firebase/GCP projects.
- No third-party feature-flag SaaS at current scale.

This document does not select whether the eventual storage extends the current
subscription configuration or uses a dedicated feature-flag collection. That
is deferred to the data-model proposal.

### Flag categories

The architecture must be able to represent:

- Global AI provider-execution kill switch.
- NAJM AI feature availability.
- Environment rollout.
- Provider, model, prompt, tool, RAG, memory, or cache-specific disablement.
- Compatibility/deprecation control.
- Approved cohort or experiment assignment if later authorized.

This list defines policy categories, not actual flag keys or approved
capabilities.

### Feature-flag proposed model

| Field group | Required meaning |
|---|---|
| Identity | Stable flag key, policy category, immutable version |
| Environment | Environment/project scope |
| Value | Typed value and explicit fail-closed safe default |
| Targeting | Optional approved rule reference and stable-assignment version |
| Time | Effective time, optional expiry, evaluation time |
| Safety | Deny/degrade behavior and whether emergency propagation is required |
| Governance | Owner, author, reviewer/approver, change reason, timestamps |
| Audit | Content hash, change identifier, evaluation identifier |
| Cache | Maximum staleness classification, not a client authority |

Exact fields, storage, indexes, and serialized states remain data-model scope.

### Feature-flag lifecycle semantics

Every target implementation must distinguish:

| State | Evaluated for target traffic? | Meaning |
|---|---:|---|
| Proposed | No | Policy is being authored |
| Approved-disabled | No | Reviewed but not active |
| Active | Yes | Eligible for environment/scope evaluation |
| Suspended | Deny/degrade only | Emergency or temporary safe state |
| Expired | No | Effective period ended |
| Retired | No | Permanently removed from new evaluation |

Exact persisted enum names and approval roles remain open.

## Entitlement integration

### Provider-neutral entitlement

An entitlement grants a NAJM capability or service level. It never grants or
promises:

- Claude, OpenAI, Gemini, GLM, DeepSeek, Qwen, or another named provider.
- A specific native model.
- A provider token quantity.
- A right to bypass safety, budget, availability, or incident controls.

Provider changes therefore do not require subscription or Product API changes.

### Entitlement decision proposed model

The Orchestrator requires a provider-neutral decision containing:

| Field group | Required meaning |
|---|---|
| Decision | Allow/deny, stable reason code, decision identifier |
| Principal | Authenticated user and optional approved organization context |
| Capability | NAJM feature/task and service level |
| Validity | Effective start/end and status |
| Limits | Approved feature usage limits, not provider tokens |
| Source | Free-launch policy, current subscription, trial, grant, or future approved source |
| Version | Entitlement policy/catalog version used |
| Provenance | Source record reference and evaluation timestamp |
| Consumption | Whether later usage accounting is required; no credit semantics defined here |

Exact storage and commercial precedence remain open and are not implemented in
Phase 1.

### Firebase identity and claims

Firebase Auth and current approval/custom claims remain the identity and role
foundation. They are prerequisites for access, not a replacement for an
authoritative entitlement decision.

Claims may later carry a bounded cache or hint only if reconcilable to the
entitlement source. A client-provided claim, tier string, or user document
mirror cannot grant an AI entitlement by itself.

## Free/Pro compatibility boundary

The target must preserve current executable behavior while subscription
architecture is migrated later:

- Existing Free/Pro scaffolding remains unchanged.
- The current subscriptions-disabled Free-launch behavior is an explicit
  compatibility policy, not a missing-config fallback.
- That compatibility policy may map current users to the same NAJM capability
  access they receive today.
- It cannot bypass authentication, account approval, feature/incident kill
  switches, aviation safety, budget controls, or route approval.
- No new tier, price, quota, trial, referral, or purchase behavior is approved
  by this document.
- No current feature is represented as paid or restricted differently because
  this target architecture has been documented.

Historical README/cost-model references to Elite, unlimited AI, or provider
pricing are not approved commercial policy.

## Feature and entitlement evaluation snapshot

Every orchestration decision records, as applicable:

- Authenticated actor and authorization decision reference.
- Global and scoped kill-switch versions/results.
- Feature-flag key, version, source, targeting result, and evaluation ID.
- Entitlement decision ID, policy/catalog version, source, service level,
  limits, and reason.
- Safety-policy version/result.
- Budget/AI Credit decision reference when later implemented.
- Prompt, provider, model, and registry revisions.
- Final allow, deny, degrade, deterministic-only, or unavailable reason.

The snapshot contains identifiers and facts, not provider secrets, payment
credentials, raw subscription receipts, roster credentials, or prompt bodies.

## Caching and consistency

- Flags and entitlement decisions are evaluated server-side.
- Immutable policy versions are safe to cache.
- Active state and entitlement validity use bounded TTLs and effective times.
- Cache keys include environment, principal/scope, capability, and policy
  version.
- Emergency kill switches require a stricter maximum-staleness class than
  ordinary rollout settings.
- Missing/unreadable target AI policy resolves to the documented safe default.
- A cached allow cannot outlive entitlement expiry or an applicable suspension
  beyond the approved propagation window.
- Client caches are display hints only and cannot authorize a provider call.

Exact TTLs and invalidation mechanisms remain open.

## Rollout and cohort boundaries

- Separate projects provide the primary environment boundary.
- Any approved rollout assignment must be stable and reproducible from a
  versioned rule.
- Targeting uses the minimum approved attributes and must not use demographic
  inference.
- Rank, tenant, organization, geography, or other sensitive attributes cannot
  be introduced as targeting inputs without explicit policy and privacy
  approval.
- A cohort can choose between already approved policies/assets only.
- Cohort assignment cannot bypass entitlement, safety, or budget.

This document does not approve percentage rollout, experimentation, or a
specific targeting taxonomy.

## Failure and rollback semantics

- Missing or unreadable target flag state uses its explicit fail-closed safe
  default.
- Missing required entitlement denies the AI capability.
- An explicit subscriptions-disabled Free-launch policy is not treated as
  missing configuration.
- A flag allow with entitlement deny results in deny.
- An entitlement allow with feature/kill-switch deny results in deny or the
  explicitly configured deterministic-only/degraded outcome.
- Provider/model/prompt unavailability does not revoke an entitlement; it
  produces an execution-unavailable result.
- Rollback activates a prior approved immutable flag or entitlement-policy
  version.
- Rollback never edits historical evaluation, usage, or audit evidence.
- No failure path falls back to direct provider access or a client-side tier
  check.

## Architectural decisions

### AI-FE-001 — Feature availability and entitlement are separate

- **Decision:** Feature flags control operational availability; entitlements
  control actor access to an available NAJM capability.
- **Rationale:** Combining rollout and commercial access makes incidents,
  Free-launch compatibility, and subscription changes unsafe.
- **Alternatives considered:** Subscription tier as the feature flag; one
  boolean per user; client-only feature gating.
- **Accepted trade-offs:** The Orchestrator combines two versioned decisions.
- **Security impact:** A paid or granted user cannot bypass an emergency or
  safety disablement.
- **Cost impact:** Expensive features can be disabled independently of customer
  catalog changes.
- **Scalability impact:** Global feature policy and per-principal entitlement
  can cache and scale independently.
- **Migration impact:** Existing subscription/feature fields remain legacy
  inputs until later compatibility mapping.
- **Implementation priority:** Must implement before internal alpha.

### AI-FE-002 — Server-side Orchestrator enforcement

- **Decision:** The Orchestrator requires authoritative flag and entitlement
  decisions before Gateway execution; client/UI state is non-authoritative.
- **Rationale:** UI gating and Product API assumptions can be bypassed.
- **Alternatives considered:** Flutter-only gates; Product API tier checks;
  Gateway entitlement logic.
- **Accepted trade-offs:** Every AI request has a small policy-evaluation
  dependency.
- **Security impact:** Prevents direct API bypass and centralizes least
  privilege.
- **Cost impact:** Denied requests stop before provider spend.
- **Scalability impact:** Typed cached decisions avoid duplicating policy logic
  across features.
- **Migration impact:** Existing client gates remain current behavior but cannot
  be the target enforcement path.
- **Implementation priority:** Must implement before internal alpha.

### AI-FE-003 — Firestore-backed typed flags with safe precedence

- **Decision:** AI feature flags follow ADR-016: Firestore-backed,
  environment-scoped, typed, bounded-cache, and fail-closed, with Firestore →
  environment → hardcoded safe-default precedence.
- **Rationale:** This is the already approved portable configuration pattern in
  NAJM.
- **Alternatives considered:** Third-party flag SaaS; environment-only flags;
  compile-time flags; per-feature ad hoc reads.
- **Accepted trade-offs:** Cached policy is eventually consistent within its
  approved staleness window.
- **Security impact:** Missing configuration cannot silently enable AI.
- **Cost impact:** Cached Firestore reads are small and predictable.
- **Scalability impact:** Read volume remains bounded by cache misses rather
  than AI request volume.
- **Migration impact:** Exact collection versus existing-config extension is
  deferred; Phase 1 creates no records.
- **Implementation priority:** Must implement before internal alpha.

### AI-FE-004 — Deny-dominant policy composition

- **Decision:** Authentication, authorization, kill switch, feature,
  entitlement, safety, budget/credits, and route approval are mandatory;
  an allow from one cannot override a deny from another.
- **Rationale:** These controls protect different risks and must not collapse
  into one permissive boolean.
- **Alternatives considered:** First-match policy; subscription overrides;
  provider availability implies access.
- **Accepted trade-offs:** More explicit decision reasons and policy
  provenance.
- **Security impact:** Prevents commercial, client, or rollout state from
  bypassing safety or authorization.
- **Cost impact:** Stops requests before provider spend when any mandatory
  control denies.
- **Scalability impact:** Decisions can be evaluated independently and composed
  deterministically.
- **Migration impact:** Legacy fail-open behavior remains a documented issue
  until later runtime migration.
- **Implementation priority:** Must implement before internal alpha.

### AI-FE-005 — Preserve current Free/Pro behavior

- **Decision:** Current Free/Pro and subscriptions-disabled launch behavior is
  preserved through a compatibility entitlement policy; Milestone 2 creates no
  new commercial behavior.
- **Rationale:** Phase 1 is documentation-only and backward compatibility is
  binding.
- **Alternatives considered:** Redesign tiers now; infer paid access from the
  target credit architecture; disable current features.
- **Accepted trade-offs:** Legacy fields and target entitlement semantics
  coexist during a later controlled migration.
- **Security impact:** Compatibility cannot bypass authentication, safety, or
  kill switches.
- **Cost impact:** No pricing or revenue change; current daily limits remain
  legacy behavior.
- **Scalability impact:** A compatibility mapper can later isolate legacy
  sources from new features.
- **Migration impact:** No subscription, claim, or feature behavior changes in
  Phase 1.
- **Implementation priority:** Must preserve throughout migration.

### AI-FE-006 — Entitlements are provider-neutral

- **Decision:** Entitlements grant NAJM capabilities/service levels and never
  name an external provider, native model, or provider token amount.
- **Rationale:** Provider/model promises would reintroduce commercial and API
  lock-in.
- **Alternatives considered:** Claude plan, GPT plan, model-specific quota,
  client-selectable provider.
- **Accepted trade-offs:** NAJM retains responsibility for selecting an
  approved route that meets the capability.
- **Security impact:** Users cannot route around provider/data-policy controls.
- **Cost impact:** Provider price changes can be absorbed by approved routing
  and later credit policy without changing subscriptions.
- **Scalability impact:** New adapters do not multiply subscription products.
- **Migration impact:** Legacy tier names remain, but no new provider promise
  may be added.
- **Implementation priority:** Must implement before paid launch and applies to
  any alpha entitlement representation.

### AI-FE-007 — Versioned decision provenance

- **Decision:** Every feature and entitlement evaluation returns a stable
  decision ID, policy version, source, result, and reason for orchestration
  provenance.
- **Rationale:** Access disputes, incidents, rollout analysis, and future
  billing require the exact policy that applied.
- **Alternatives considered:** Store only final allow/deny; rely on current
  config; log raw subscription records.
- **Accepted trade-offs:** Additional compact metadata and audit writes.
- **Security impact:** Provides accountability while avoiding raw receipts,
  secrets, and unnecessary PII.
- **Cost impact:** Small storage cost; reduces support and dispute cost.
- **Scalability impact:** Immutable decision facts scale independently of
  mutable policy records.
- **Migration impact:** Legacy evaluations require compatibility identifiers
  when later routed through the Orchestrator.
- **Implementation priority:** Must implement before internal alpha.

## Security considerations

- Flag and entitlement administration requires least-privilege server
  authorization and audited changes.
- Clients cannot set evaluation attributes, entitlement sources, tier, service
  level, provider, model, or feature result.
- Targeting attributes are minimized and privacy-reviewed.
- Feature flags and entitlements contain no provider secret, payment
  credential, Firebase token, service token, roster credential, prompt body, or
  raw receipt.
- Account approval/authorization and entitlement remain separate checks.
- Provider output cannot modify a flag or grant an entitlement.
- Deterministic aviation rules and governed knowledge remain authoritative.

## Cost considerations

- Feature flags can prevent provider execution but are not the Budget
  Controller.
- Entitlements express NAJM service access/limits, not provider token economics.
- Provider pricing, credit burn, reservations, ledger, billing, and margin
  remain Milestone 3 scope.
- Server-side evaluation should occur before expensive context assembly and
  provider execution when consistent with safety and product behavior.
- Bounded caching controls Firestore evaluation cost.
- A flag cannot be used to conceal an unbounded cost path.

## Scalability considerations

- Environment separation is project-based.
- Global flags, scoped flags, and per-principal entitlements can cache at
  different bounded TTL classes.
- Stable rollout assignment avoids request-to-request flapping.
- Evaluation does not require scanning all flags or entitlements.
- Immutable policy versions and decision records scale separately from active
  pointers.
- A third-party flag platform is deferred until measurable scale demonstrates
  a benefit.

## Migration considerations

- No current flag, subscription, claim, or feature behavior changes in Phase 1.
- A later migration must inventory every AI feature check, client gate, tier
  field, daily limit, master switch, and bypass path.
- Current Free/Pro and subscriptions-disabled behavior is captured as an
  explicit compatibility decision before redirection.
- Product APIs remain backward-compatible.
- Clients may continue showing legacy state during a compatibility window, but
  server enforcement becomes authoritative when later implemented.
- Migration must not introduce direct provider access or provider-specific
  entitlements.
- Exact migration sequencing belongs to the dedicated Milestone 4 migration
  strategy and is not decided here.

## Delivery classification

This classification states architecture requirements and is not a plan for
Phase 2 runtime work.

### Must implement before internal alpha

- Server-authoritative feature and entitlement decisions for every
  alpha-admitted AI capability.
- Global and feature AI kill switches, fail-closed defaults, and bounded cache
  behavior.
- Deny-dominant composition with authentication, safety, budget, prompt, and
  registry policy.
- Versioned evaluation provenance.
- Explicit compatibility handling for current Free/Pro and
  subscriptions-disabled behavior.
- No alpha reliance on client-only gates or direct provider access.

### Must implement before paid launch

- Authoritative purchase/trial/grant-to-entitlement mapping after separately
  approved billing work.
- Transactional usage/credit integration and dispute-grade provenance.
- Audited entitlement administration, expiry, revocation, restore, refund, and
  support workflows.
- Production rollout/kill-switch administration and tested stale-cache
  handling.
- Approved retention, privacy, targeting, and organizational-access policies.

### Deferred until scale justifies it

- Third-party feature-flag SaaS.
- Complex multivariate experimentation.
- Fine-grained behavioral cohorts.
- Delegated enterprise entitlement administration.
- Provider/model-branded subscription products, which remain disallowed unless
  the owner explicitly changes the provider-independent strategy.

## Open questions

- Exact target feature keys and canonical AI capability taxonomy.
- Which AI capabilities, if any, enter internal alpha.
- Dedicated feature-flag collection versus extension of existing subscription
  configuration.
- Exact entitlement source, storage, schema, indexes, and API contract.
- Approved targeting attributes, percentage rollout, and assignment semantics.
- Flag and entitlement administrator/reviewer roles.
- Exact cache TTLs and emergency invalidation mechanism.
- Trial, referral, grant, restore, and entitlement-precedence rules.
- RevenueCat and store integration details.
- Family, corporate, or enterprise entitlement inheritance.
- Exact data retention for policy versions and evaluation records.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Orchestrator](AI_ORCHESTRATOR.md)
- [AI Gateway and Provider Adapters](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- [AI Registries](AI_REGISTRIES.md)
- [Prompt Registry](PROMPT_REGISTRY.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Current API contract](../api-contract.yaml)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
