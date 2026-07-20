# NAJM AI Provider Registry and Model Registry

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation, Milestone 2
**Document role:** Authoritative target-state registry contract
**Last reconciled:** 2026-07-16

## Purpose

This document defines the Provider Registry and Model Registry required by the
approved provider-independent NAJM AI Platform.

The registries replace provider names, native model names, capabilities, and
route constraints embedded in Product APIs or domain modules with governed,
versioned control-plane assets. They allow the AI Orchestrator to select an
approved route and the AI Gateway to validate and execute it without making
GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, or any future provider a product
dependency.

## Scope

This document defines:

- Provider Registry and Model Registry responsibilities.
- Provider-neutral keys, immutable revisions, lifecycle semantics, and
  activation requirements.
- Capability and constraint representation.
- Registry read and decision-snapshot contracts.
- Relationships with the Orchestrator, Gateway, Provider Adapters, Prompt
  Registry, feature flags, entitlements, budget policy, and safety policy.
- Failure, compatibility, migration, rollback, security, cost, and scale
  boundaries.

## Non-goals

This document does not:

- Select a default provider, model, route, or fallback order.
- Decide which capabilities enter internal alpha.
- Create registry data, Firestore collections, indexes, rules, endpoints, or
  administration UI.
- Add provider SDKs, adapters, secrets, environment variables, or pricing.
- Define prompt bodies or prompt promotion.
- Define NAJM AI Credit prices, burn rates, ledger events, or margin formulas.
- Define live provider health, incident response, or observability storage.
- Resolve provider data-residency or retention approvals.
- Change the current Anthropic/OpenAI implementation.

## Current legacy state

The current executable implementation directly names and invokes Anthropic for
assistant and knowledge generation and OpenAI for embeddings. Model identifiers
and provider-specific status, failure, monitoring, pricing, and secret language
also appear in runtime modules and existing documents.

There is no implemented Provider Registry or Model Registry. Existing model
constants and environment-driven provider configuration remain current legacy
behavior until a later, separately approved runtime migration.

The existing Architecture Lock wording that identifies Anthropic as primary
and OpenAI for embeddings is a legacy-current provider selection. The newer
owner-approved provider-independent AI Platform is the target architecture.
Milestone 2 documents that target without changing the older binding index;
formal index reconciliation remains Milestone 5 work.

## Approved target state

### Registry relationship

    Product API
      -> names NAJM feature and task only
      -> AI Orchestrator
          -> Provider Registry: which provider adapters are approved?
          -> Model Registry: which model revisions satisfy the task policy?
          -> Prompt Registry and policy sources
          -> selects an approved provider/model route
      -> AI Gateway
          -> revalidates registry state and capability
          -> resolves the registered AI Provider Adapter
          -> invokes the selected provider route

Product APIs, domain engines, Flutter, Cloud Functions, and tools never resolve
native provider names, native model names, provider endpoints, or provider
credentials.

### Terminology boundary

An **AI Provider** is an external model service such as GLM, Claude, OpenAI,
Gemini, DeepSeek, or Qwen. An **AI Provider Adapter** is the only NAJM
component allowed to invoke that service.

These terms are separate from roster providers and roster connectors. Nothing
in the AI registries weakens the permanent zero-knowledge roster credential
model.

## Component responsibilities

### Provider Registry owns

- Stable NAJM provider identity.
- Binding from a provider key to an approved AI Provider Adapter key.
- Administrative lifecycle and environment eligibility.
- Declared provider-level capabilities and constraints.
- Approved data-processing, regional, and retention policy references.
- Opaque credential-binding reference, never a secret value.
- Provider-level quota and concurrency policy references.
- Provider terms, review, and operational owner metadata.
- Registry revision, content hash, audit metadata, and change reason.

### Provider Registry does not own

- Provider secret values.
- Native model inventory.
- Product feature entitlement.
- Prompt bodies.
- Semantic model selection or fallback.
- Live provider health or circuit state.
- User-visible pricing or NAJM AI Credits.
- Provider invocation.

### Model Registry owns

- Stable NAJM model identity and immutable model revision.
- Relationship to one registered AI provider.
- Server-internal native model identifier.
- Supported task capabilities, modalities, and limits.
- Structured-output, tool, streaming, embedding, and vision support.
- Context and output limits.
- Compatibility constraints for prompt and tool contracts.
- Safety, data-processing, region, and retention approval references.
- Feature/task eligibility and lifecycle status.
- Provider pricing-fact reference and effective period, when applicable to a
  billable or budget-governed route, for later internal cost accounting.
- Evaluation and approval evidence references.
- Registry revision, content hash, audit metadata, and change reason.

### Model Registry does not own

- Product prompt bodies.
- Product feature flags or entitlements.
- User credit prices.
- Fallback ordering for a feature request.
- Deterministic aviation truth.
- Live health or incident state.
- Provider credentials.

### AI Orchestrator owns

- Combining feature, entitlement, safety, prompt, budget, and registry policy.
- Selecting an eligible provider/model route.
- Recording the exact registry revisions used.
- Choosing approved fallback attempts.

The Orchestrator must not accept an unrestricted provider or native model
override from a Product API, client, domain engine, or tool.

### AI Gateway owns

- Resolving the registered adapter binding.
- Revalidating provider/model lifecycle eligibility and declared capability at
  execution time.
- Passing only the selected native model identity to the adapter.
- Returning a normalized configuration failure when the route cannot execute.

The Gateway does not select an alternative route.

## Provider Registry proposed model

This is a conceptual information contract. Exact storage and serialization are
deferred to the approved data-model proposal.

| Field group | Required meaning |
|---|---|
| Identity | Stable provider key, human-readable name, provider family, registry revision |
| Adapter binding | Approved adapter key and adapter contract version |
| Lifecycle | Administrative state, effective time, optional sunset time, reason |
| Environment | Environments in which the provider may be eligible |
| Capabilities | Provider-level modalities and execution features |
| Data policy | Approved policy references for data classes, regions, retention, training use, and transfer |
| Credentials | Opaque credential-binding key only; never a key value or secret URI exposed to consumers |
| Operations | Quota, concurrency, timeout, and operational-owner policy references |
| Governance | Proposer, reviewer/approver, approval evidence, change reason, timestamps |
| Integrity | Immutable revision identifier and content hash |

The provider key is a NAJM identifier. Product contracts do not expose or
depend on a provider’s marketing name.

## Model Registry proposed model

| Field group | Required meaning |
|---|---|
| Identity | Stable NAJM model key, immutable model revision, provider key |
| Provider mapping | Server-internal native model identifier and adapter compatibility |
| Capability | Text, structured output, tools, embeddings, vision, streaming, or other approved capabilities |
| Limits | Context, output, input size, dimensional, modality, and concurrency constraints |
| Prompt compatibility | Supported Prompt Registry families/contract versions or required capabilities |
| Tool compatibility | Tool-call protocol capabilities and restrictions |
| Safety/data policy | Approved safety class, data-class, region, retention, and provider-policy references |
| Feature eligibility | Approved NAJM task/feature classes; no entitlement decision |
| Cost facts | When applicable, provider pricing reference, currency, effective time, and unit vocabulary for internal accounting; otherwise an explicit non-billable classification reference |
| Evaluation | Evaluation set/version, reviewer evidence, known limitations |
| Lifecycle | Administrative state, effective time, deprecation/sunset metadata, reason |
| Governance | Proposer, reviewer/approver, change reason, timestamps |
| Integrity | Immutable revision identifier and content hash |

A native model name is internal registry data. It must never become a constant
or request option in Flutter, a Product API, a domain engine, or a tool.

## Lifecycle semantics

Exact serialized enum names are deferred to the data-model proposal, but every
registry implementation must preserve these semantics.

### Provider lifecycle

| State | Executable? | Meaning |
|---|---:|---|
| Proposed | No | Metadata exists but review is incomplete |
| Approved-disabled | No | Policy review is complete but execution is not enabled |
| Enabled | Yes, subject to all other policy | Eligible for Orchestrator selection |
| Suspended | No | Temporarily disabled for security, provider, policy, or incident reasons |
| Retired | No | Permanently ineligible for new execution |

### Model lifecycle

| State | Executable? | Meaning |
|---|---:|---|
| Proposed | No | Model revision has been identified but not accepted |
| Evaluating | No | Capability, quality, safety, cost, and data-policy review is underway |
| Approved-disabled | No | Review passed but route is not active |
| Enabled | Yes, subject to all other policy | Eligible for approved tasks |
| Deprecated | Conditional | Existing compatibility use may continue until an approved sunset; no new feature dependency |
| Suspended | No | Temporarily disabled |
| Retired | No | Permanently ineligible for new execution |

Lifecycle state alone never grants feature access, entitlement, safety
approval, prompt compatibility, budget, or provider health.

## Activation and change requirements

A provider/model route can be eligible only when all applicable facts are
present:

- The provider revision is enabled.
- The model revision is enabled, or is deprecated and covered by an explicit,
  versioned compatibility authorization whose sunset has not passed.
- The registered adapter and contract versions exist.
- Required adapter configuration is present without exposing secret values.
- Required capability and normalized-contract support are declared.
- Prompt compatibility is approved.
- Data-processing, region, retention, security, and safety reviews are valid.
- Provider pricing units are represented when the request is billable or an
  applicable budget/cost policy requires them. Non-billable internal-alpha
  execution requires an explicit non-billable classification; exact
  classification and missing-price behavior remain Milestone 3 decisions.
- Feature policy allows the route.
- No applicable incident or kill switch disables the route.

Changing provider metadata, native model identity, capabilities, limits, data
policy, pricing reference, or approval evidence creates a new immutable
registry revision. Historical orchestration and usage records continue to
reference the prior revision.

Administrative enable/disable actions must be authorized, versioned, reasoned,
and auditable. Exact approval roles and whether paid launch requires dual
control remain open owner decisions.

## Required conceptual interfaces

### Registry lookup

The Orchestrator supplies:

- Environment.
- NAJM feature and task.
- Required capability and response contract.
- Safety and data-policy classification.
- Prompt contract requirements.
- Deadline and budget constraints.

The registries return eligible metadata and immutable revision identifiers.
They do not select a final route or decide entitlement.

### Registry decision snapshot

Every route decision records:

- Provider key and provider registry revision.
- Model key and model registry revision.
- Adapter key and adapter contract version.
- Capabilities and limits relied upon.
- Policy/evaluation references relied upon.
- Administrative lifecycle states at decision time.
- Pricing-fact reference used for estimation when applicable.

### Gateway validation

The Gateway receives the Orchestrator-selected registry keys and revisions. It
must fail before provider invocation when:

- A key or revision is missing.
- The route is not lifecycle-eligible.
- The adapter binding is absent.
- Required capability or limit is incompatible.
- The native model mapping is ambiguous.
- An execution-time kill switch applies.

The Gateway returns normalized facts. It does not pick another provider or
model.

## Capability taxonomy

The registries must support provider-neutral capability declarations, at
minimum for capabilities that NAJM actually admits:

- Text generation.
- Structured output.
- Tool-capable generation.
- Embeddings.
- Vision or document input.
- Streaming.
- Usage reporting granularity.
- Provider-side caching when its semantics are approved.

Listing a capability here does not approve it for internal alpha or any
feature. Exact alpha capabilities remain an owner decision.

Capabilities must be truthful and testable. Unsupported normalized semantics
must fail explicitly rather than being silently dropped or approximated.

## Registry caching and consistency

- Registry revisions are immutable and safe to cache.
- Active pointers and lifecycle state may be cached only for a bounded period.
- Cache entries must include environment and registry revision.
- Missing or unreadable registry state fails closed.
- Stale cache must not re-enable a suspended or retired route beyond the
  approved propagation window.
- Incident controls may require faster invalidation than ordinary metadata.
- Exact TTL, invalidation transport, and service-level objectives remain open
  questions and belong with later operational design.

## Failure and rollback semantics

- Missing, ambiguous, disabled, incompatible, or unapproved registry state
  produces a normalized configuration denial before provider execution.
- There is no implicit default provider or model.
- There is no fallback to a business-module constant for a migrated AI
  feature.
- The Orchestrator may choose another route only if that route is separately
  eligible and allowed by feature, safety, data, prompt, entitlement, and
  budget policy.
- Rollback activates a previously approved provider/model revision or route
  policy; it does not edit historical revisions.
- Registry rollback does not roll back Product API data or deterministic
  aviation sources.
- Historical usage, ledger, and audit records retain their original registry
  revision references.

## Architectural decisions

### AI-REG-001 — Separate Provider and Model Registries

- **Decision:** Provider identity/adapter policy and model
  identity/capability policy are separate governed registries.
- **Rationale:** Providers and models have different lifecycles, constraints,
  reviews, and change rates.
- **Alternatives considered:** One flat model table; provider/model constants
  in each feature; configuration entirely inside adapters.
- **Accepted trade-offs:** Route resolution joins two versioned control-plane
  assets.
- **Security impact:** Provider credentials and adapter bindings can be scoped
  without exposing native model data to product modules.
- **Cost impact:** Model price facts can change independently of provider
  governance.
- **Scalability impact:** Many models can share one provider/adapter definition.
- **Migration impact:** Existing Anthropic/OpenAI constants must later be
  inventoried and represented without changing current behavior.
- **Implementation priority:** Must implement before internal alpha for every
  admitted AI capability.

### AI-REG-002 — Stable keys and immutable revisions

- **Decision:** Provider/model keys are stable NAJM identifiers; material
  changes create immutable registry revisions.
- **Rationale:** Orchestration, incidents, evaluation, cost, and rollback must
  be reproducible after registry state changes.
- **Alternatives considered:** Mutable documents only; native provider names as
  keys; retain only the current value.
- **Accepted trade-offs:** More metadata and revision history.
- **Security impact:** Auditable revisions make unapproved route changes
  detectable.
- **Cost impact:** Small additional storage cost; materially better billing and
  incident evidence.
- **Scalability impact:** Immutable revisions cache safely and distribute well.
- **Migration impact:** Legacy names are mapped to stable keys only when a use
  case is later migrated.
- **Implementation priority:** Must implement before internal alpha.

### AI-REG-003 — Product features depend on capabilities, not providers

- **Decision:** Product APIs request a NAJM feature/task and response contract;
  they never select a provider or native model.
- **Rationale:** Provider independence is impossible if product contracts name
  external vendors.
- **Alternatives considered:** Provider/model request parameters; feature-owned
  route constants; client-selectable models.
- **Accepted trade-offs:** The Orchestrator and registries must resolve
  capability compatibility.
- **Security impact:** Prevents caller-controlled routing to an unapproved
  provider, model, or data policy.
- **Cost impact:** Central routing can later consider approved cost policy
  without changing product code.
- **Scalability impact:** Providers/models can be added without multiplying
  Product API integrations.
- **Migration impact:** Public API response compatibility is preserved while
  provider-specific internals are removed later.
- **Implementation priority:** Must implement before internal alpha.

### AI-REG-004 — Registry metadata contains no secret values

- **Decision:** Registries may contain opaque adapter and credential-binding
  keys but never provider secret values.
- **Rationale:** Registry readers need routing metadata, not credential access.
- **Alternatives considered:** API keys in provider records; a shared AI secret
  bundle; Product API secret resolution.
- **Accepted trade-offs:** Adapter configuration and secret storage require a
  separate secure resolution path.
- **Security impact:** Preserves adapter-scoped least privilege and prevents
  registry compromise from directly exposing provider keys.
- **Cost impact:** Minor secret-management overhead.
- **Scalability impact:** Credentials can rotate independently per provider and
  environment.
- **Migration impact:** Current secret guidance remains unchanged until
  Milestone 5 reconciliation and later runtime work.
- **Implementation priority:** Must implement before internal alpha.

### AI-REG-005 — Explicit capability and policy compatibility

- **Decision:** A route is eligible only when provider, model, adapter, prompt,
  feature, safety, and data-policy requirements are explicitly compatible.
- **Rationale:** Silent parameter dropping or assumed compatibility makes
  fallback unsafe and provider swaps unreliable.
- **Alternatives considered:** Lowest-common-denominator text-only routing;
  adapter best effort; runtime trial and error.
- **Accepted trade-offs:** New capabilities require deliberate registry and
  contract updates.
- **Security impact:** Reduces unintended data transfer and unsupported safety
  behavior.
- **Cost impact:** Avoids paid calls that cannot satisfy the requested
  contract.
- **Scalability impact:** Capability filtering reduces failed attempts as the
  model catalog grows.
- **Migration impact:** Legacy features require captured capability contracts
  before registry routing.
- **Implementation priority:** Must implement before internal alpha.

### AI-REG-006 — Lifecycle-gated, fail-closed activation

- **Decision:** Only a fully approved, enabled provider and a
  lifecycle-eligible model revision may execute. A deprecated model remains
  eligible only under an explicit, versioned compatibility authorization
  before its approved sunset; missing or inconsistent state denies execution.
- **Rationale:** Configuration failure must not select an unreviewed model or
  silently fall back to a hardcoded route.
- **Alternatives considered:** Default provider on error; enabled-by-presence;
  environment-only model configuration.
- **Accepted trade-offs:** Registry/control-plane availability becomes a
  dependency and requires bounded safe caching.
- **Security impact:** Prevents unapproved execution and provides emergency
  suspension.
- **Cost impact:** Stops spend when configuration or approval is uncertain.
- **Scalability impact:** Cached immutable revisions and small active-state
  records scale efficiently.
- **Migration impact:** Legacy direct paths remain explicitly outside this
  target until migrated; no Phase 1 runtime behavior changes.
- **Implementation priority:** Must implement before internal alpha.

## Security considerations

- Registry administration is server-side, least-privilege, and audited.
- Clients, Product APIs, domain engines, and tools cannot supply native model
  names, provider endpoints, adapter keys, or credential bindings.
- Provider and model activation must respect approved data classifications,
  regions, retention, and provider training-use policies.
- Registry diagnostics expose no provider secret, service token, Firebase
  credential, roster credential, or secret-bearing URL.
- Model output never becomes registry data automatically.
- Evaluation evidence is untrusted until reviewed and attached by an
  authorized actor.
- Deterministic legality and governed operational sources remain authoritative
  regardless of registry state.

## Cost considerations

- Model Registry pricing is an internal provider-cost fact or reference, not a
  user price and not a NAJM AI Credit burn rate. It is required for billable
  or otherwise budget-governed routes, while explicitly classified
  non-billable internal-alpha traffic may omit it until the applicable policy
  requires it.
- Pricing facts are effective-dated and versioned so later reconciliation can
  reproduce route estimates.
- Missing price facts may disqualify a billable route under later budget
  policy; exact behavior belongs to Milestone 3.
- Product modules cannot route directly to a cheaper or more expensive model.
- Registry reads should be bounded and cached; registry cost must not scale
  linearly with prompt tokens or streamed output.

## Scalability considerations

- Separate provider and model records avoid duplicating provider metadata for
  every model.
- Immutable revisions support local caching and later distribution.
- Eligibility queries must be bounded by provider, capability, task,
  environment, and lifecycle rather than full scans.
- High-cardinality live metrics do not belong in registry records.
- A future external registry service is unnecessary until scale or operational
  isolation demonstrates a measurable benefit.

## Migration considerations

- Current executable provider/model constants remain untouched.
- A later migration must inventory each direct call’s provider, native model,
  capability, prompt, limits, data classes, timeout, fallback, and usage facts.
- Legacy routes may be represented as disabled or compatibility registry
  revisions before any traffic uses them.
- Migration occurs behind stable Product APIs and never exposes provider
  selection to Flutter.
- A migrated feature can roll back to its prior application revision until
  compatibility acceptance, while historical registry revisions remain.
- No new direct provider integration is permitted during migration.

## Delivery classification

This classification states architecture requirements and is not a plan for
Phase 2 runtime work.

### Must implement before internal alpha

- Provider and Model Registries for every admitted AI capability.
- Stable keys, immutable revisions, lifecycle gating, adapter binding, and
  capability validation.
- Server-only native names and adapter-scoped credential bindings.
- Registry decision provenance and fail-closed missing-state behavior.
- No alpha-admitted feature with direct provider/model constants.

### Must implement before paid launch

- Audited administrative lifecycle, approval evidence, suspension, deprecation,
  and rollback.
- Effective-dated provider pricing facts and invoice reconciliation references.
- Approved data-region, retention, security, and provider policy metadata.
- Capacity/quota policy references and production cache invalidation controls.
- Tested registry corruption, stale-cache, suspension, and rollback scenarios.

### Deferred until scale justifies it

- A separately deployed registry service.
- Automated provider/model discovery.
- Automated benchmark-driven activation.
- Large-scale catalog synchronization from provider APIs.
- A generalized third-party model marketplace.

## Open questions

- First approved provider/model routes and fallback ordering.
- Which AI capabilities, if any, enter internal alpha.
- Exact registry storage, indexes, schema serialization, and migration markers.
- Exact provider/model key naming convention.
- Administrative roles, approval count, and emergency suspension authority.
- Registry cache TTL and invalidation mechanism.
- Provider-specific data regions, retention, and training-use approvals.
- Evaluation thresholds and responsible reviewers.
- Whether a separate route-policy record is needed or eligibility remains an
  Orchestrator decision over Provider and Model Registry records.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Orchestrator](AI_ORCHESTRATOR.md)
- [AI Gateway and Provider Adapters](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Secrets Management](../SECRETS.md)
- [Infrastructure Cost Model](../cost-model.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
- Planned Milestone 2 companions:
  [PROMPT_REGISTRY.md](PROMPT_REGISTRY.md) and
  [AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md](AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md).
