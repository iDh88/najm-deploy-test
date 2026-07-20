# NAJM AI Platform — Overview and Architectural Boundaries

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation
**Document role:** Authoritative target-state overview
**Last reconciled:** 2026-07-16

## Purpose

This document defines the approved provider-independent NAJM AI Platform and
the boundaries that every future AI-enabled NAJM feature must follow. It turns
the owner-approved topology into a durable source of truth without changing
current runtime behavior:

    Flutter
      -> FastAPI Product APIs
      -> AI Orchestrator
      -> AI Gateway
      -> Provider Adapters
      -> GLM / Claude / OpenAI / Gemini / DeepSeek / Qwen / future providers

The permanent strategic rule is:

> No business module may directly call an AI provider. All AI usage must
> eventually flow through the NAJM AI Platform.

## Scope

This overview defines:

- The platform topology and source-of-truth hierarchy.
- Allowed and forbidden component calls.
- The division between product APIs, domain engines, the AI Orchestrator, the
  AI Gateway, provider adapters, and external providers.
- The relationship to authentication, entitlements, feature flags, budgets,
  credits, safety, prompts, registries, RAG, tools, memory, cache, usage
  accounting, and observability.
- Target-state failure and rollback principles.
- The compatibility boundary around the legacy Anthropic and OpenAI calls.
- Provider-neutral support for GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen,
  and future providers.

## Non-goals

This document does not:

- Claim that the AI Platform is implemented.
- Change or replace current FastAPI, Flutter, Firebase, Cloud Functions, or
  deployment behavior.
- Select a default provider or model.
- Define provider pricing, credit burn rates, subscription tiers, Firestore
  rules, runtime environment variables, or concrete SDK dependencies.
- Replace the legality rule source, Knowledge Engine, zero-knowledge roster
  credential model, Firebase authorization model, or service-token boundary.
- Authorize a business module to call an AI provider during migration.
- Define an implementation sequence beyond the delivery classifications in
  this document.

## Current legacy state

The repository currently contains direct Anthropic usage in the AI assistant
and knowledge assistant, and direct OpenAI usage for embeddings. Provider names,
model names, prompt bodies, and provider-specific behavior also appear in
runtime modules and existing operational documents.

That implementation is pre-existing legacy debt. Phase 1 preserves it exactly.
It remains the description of current behavior until a separately approved
runtime migration occurs.

Other existing foundations remain valid:

- Flutter calls authenticated FastAPI product endpoints and Firebase services.
- Firebase Auth and custom claims remain the user identity foundation.
- Cloud Functions and FastAPI retain the existing internal service-token
  boundary.
- The current Free/Pro subscription scaffolding remains unchanged.
- The configured legality-rule source remains authoritative for deterministic
  aviation legality.
- The Knowledge Engine remains the source for governed operational documents.
- Roster provider credentials remain governed by the zero-knowledge credential
  model.
- Existing deployment and rollback workflows remain the current operational
  mechanism.

Nothing in this document should be read as evidence that the target AI
Platform, its registries, credit ledger, provider adapters, or kill switches
already exist.

## Approved target state

### Logical topology

    Client and service callers
      -> authenticated FastAPI Product API
          -> deterministic domain services when AI is not required
          -> AI Orchestrator when AI is required
              -> policy and control-plane sources
              -> governed RAG, memory, cache, and tool boundaries
              -> AI Gateway
                  -> exactly one selected Provider Adapter per attempt
                      -> external AI provider

The Product API remains responsible for the product contract and business
transaction. The AI Platform is a shared internal capability; it does not
replace FastAPI product modules or deterministic domain engines.

### Control plane and execution plane

The target separates two concerns:

- **Control plane:** the AI Orchestrator evaluates feature policy, identity,
  entitlement, budget, credits, safety, prompt version, model route, RAG,
  memory, cache, tools, fallback, and accounting obligations.
- **Execution plane:** the AI Gateway validates and executes a normalized
  request through one provider adapter, then normalizes the provider result or
  failure.

The Gateway never decides which user is entitled, what a feature means, which
prompt is approved, whether a safety-sensitive fallback is allowed, or how
many NAJM AI Credits the user should consume.

### Provider independence

GLM, Claude, OpenAI, Gemini, DeepSeek, and Qwen are external execution options
behind provider adapters. They are not product dependencies and are not
implicitly enabled. Future providers enter through the same adapter boundary.
A product feature names its NAJM capability and task; it does not name an
external provider or model.

## Source-of-truth hierarchy

The hierarchy has three separate dimensions. Evidence of what currently runs
must never override a normative architecture decision or an authoritative
aviation/domain fact.

### Normative architecture authority

When architecture sources conflict, the higher source wins:

1. **Latest explicit owner decision:** a later, scoped owner approval may
   specialize or supersede an older decision. The Phase 1 provider-independent
   AI Platform direction supersedes older AI-specific provider-selection
   wording and leaves unrelated architecture decisions intact.
2. **NAJM Master Project Directive:** the general governing product and
   engineering authority unless the owner explicitly changes it.
3. **Architecture Lock:** the binding architecture decision register beneath
   the owner directive and Master Project Directive. ADR-000 governs conflicts
   within that register.
4. **Approved Phase 1 AI architecture documents:** this document and its
   approved companions define the specialized target AI Platform. Each remains
   explicitly target state until implemented.

### Runtime fact authority

Each source below is authoritative only for its declared fact category:

1. **Deterministic domain authorities:** configured legality rules,
   authoritative operational knowledge, authenticated user/product data, and
   other domain-owned sources remain authoritative for their facts. An AI
   model is never a source of regulatory truth.
2. **Governed AI control-plane assets:** Provider Registry, Model Registry,
   Prompt Registry, feature flags, entitlements, budget policy, safety policy,
   tool catalog, and retention policy become the runtime policy sources when
   implemented.
3. **Immutable operational records:** AI usage ledger events, provider usage
   facts, audit events, and incident records document what occurred. They do
   not retroactively change the policy that applied.
4. **Caches and derived views:** caches, summaries, analytics, and token claims
   may accelerate reads but must be traceable and reconcilable to their
   authoritative source.
5. **Model output:** a provider response is untrusted generated material. It
   never overrides deterministic rules, governed knowledge, authorization,
   policy, or immutable accounting facts.

### Current-behavior evidence

Deployed configuration, executable implementation, and the supported
versioned API contract are the strongest evidence of what currently runs
during migration. They do not define the approved target and do not outrank
the domain authorities above. Existing provider constants, prompts, and direct
SDK calls describe current compatibility behavior only. README wording and
historical reports are orientation or evidence, not target authority.

## Component call rules

| Caller | Target | Target-state rule |
|---|---|---|
| Flutter | FastAPI Product APIs | Allowed and required for AI product features |
| Flutter | AI Orchestrator, AI Gateway, adapter, or provider | Forbidden |
| Admin client | Governed FastAPI administration APIs | Allowed when authenticated and authorized |
| Admin client | Provider or provider secret | Forbidden |
| Cloud Functions | Existing authenticated FastAPI service/product boundary | Allowed; preserve the service-token boundary |
| Cloud Functions | Provider API or SDK | Forbidden in the target state |
| FastAPI Product API | Deterministic domain engine | Allowed |
| FastAPI Product API | AI Orchestrator | Allowed when the product capability requires AI |
| FastAPI Product API or business module | AI Gateway, adapter, or provider | Forbidden |
| Domain engine | AI Orchestrator | Forbidden as an implicit dependency; the Product API owns the AI request, while the Orchestrator may invoke the engine through an approved tool boundary |
| Domain engine | AI Gateway, adapter, or provider | Forbidden |
| AI Orchestrator | Registries, flags, entitlements, budget, credits, safety, RAG, memory, cache, tools | Allowed through governed interfaces |
| AI Orchestrator | AI Gateway | Allowed after policy resolution |
| AI Orchestrator | External provider | Forbidden |
| AI Gateway | Provider Adapter | Allowed for the route selected by the Orchestrator |
| AI Gateway | Business persistence or subscription state | Forbidden |
| Provider Adapter | Its external provider API or SDK | Allowed; this is the only permitted provider call site |
| Provider Adapter | Another provider adapter or product module | Forbidden |
| RAG embedding path | AI Orchestrator and AI Gateway | Required in the target state; current direct OpenAI embeddings are legacy |
| Tool implementation | Deterministic domain services and governed data | Allowed within its declared authorization and data scope |
| Tool implementation | Provider API | Forbidden |

## Component responsibilities

| Component | Owns | Must not own |
|---|---|---|
| Flutter | User experience, authenticated product requests, display of provenance and safe failures | Provider selection, provider credentials, prompt bodies, credit calculation |
| FastAPI Product API | Product contract, authorization context, validation, business transaction, response contract | Provider SDKs, model constants, provider fallback |
| Deterministic domain engine | Domain calculation and authoritative rules | AI routing or provider execution |
| AI Orchestrator | Policy resolution and end-to-end AI work coordination | Provider SDK calls, provider secrets, authoritative aviation calculations |
| AI Gateway | Normalized execution, transport controls, response normalization, usage facts | Entitlements, prompt governance, business state, semantic fallback policy |
| Provider Adapter | Provider-specific translation and provider invocation | Product policy, user billing, cross-provider routing |
| Registries | Governed provider, model, prompt, capability, and version metadata | Business transactions or provider invocation |
| Safety boundary | Classification, deterministic-first rules, grounded-source requirements, output validation policy | Inventing operational facts |
| Budget/Credit boundary | Reservation, limits, reconciliation, immutable accounting obligations | Provider selection based on hidden business logic |
| RAG/Tool/Memory/Cache boundaries | Governed context and deterministic capabilities | Becoming alternate provider call paths |
| Observability/incident controls | Correlation, audit facts, metrics, health, kill-switch evidence | Logging secrets, raw credentials, or unnecessary roster/PII |

## Required conceptual interfaces

These are logical contracts, not code or a transport decision.

### Product AI work request

A product module supplies:

- Request and idempotency identifiers.
- Verified actor and authorization context by reference or trusted server
  context.
- NAJM feature key and task type.
- Product-owned input and references to authorized domain data.
- Locale and response-format requirements.
- Aviation-sensitivity classification or the facts needed to derive it.
- Product transaction context and deadline.

It must not supply a provider API key, provider SDK object, provider model name,
provider-specific token limit, or an instruction to bypass safety, entitlement,
budget, or ledger controls.

### Orchestration decision

The Orchestrator produces a traceable decision containing:

- Policy, feature, entitlement, safety, prompt, registry, and budget versions.
- Approved model route and ordered fallback policy.
- Authorized context plan for RAG, tools, memory, and cache.
- Credit reservation reference when the work is billable.
- Gateway execution constraints.
- Reasons for denial, degradation, or deterministic-only handling.

### Normalized execution result

The platform returns:

- A product-consumable result or a normalized safe failure.
- Provider-neutral usage facts and provenance.
- Safety and grounding metadata.
- Credit reconciliation and immutable-ledger references when applicable.
- Correlation, attempt, and audit identifiers.

Provider-native payloads and provider secrets do not cross into Flutter or
ordinary business-module contracts.

## Failure and fallback semantics

- Authentication, authorization, entitlement, budget, missing registry assets,
  missing approved prompts, and aviation-safety policy fail closed.
- AI unavailability must not disable an independent deterministic legality,
  salary, ranking, or other domain calculation.
- The Orchestrator owns semantic fallback and may use only routes approved for
  the feature, safety class, data location, capability, and budget.
- The Gateway may perform bounded transport retry for an idempotent attempt but
  must not silently choose another provider or model.
- A provider failure is normalized and returned to the Orchestrator with
  retryability and billing facts.
- A fallback attempt receives a distinct attempt identifier under the same
  logical request and idempotency scope.
- No attempt may be billed twice. Reservations must be reconciled against
  actual accepted usage or released.
- If all approved routes fail, return a controlled unavailable or
  deterministic-only response. Never fabricate an AI answer.
- Safety-sensitive outputs that cannot be grounded or validated must abstain
  or return UNKNOWN, not infer from provider memory.

## Architectural decisions

### AI-PLAT-001 — Provider-independent mandatory path

- **Decision:** All target-state AI calls follow Product API → Orchestrator →
  Gateway → Provider Adapter → provider. Provider adapters are the only
  provider call sites.
- **Rationale:** Central control is required for safety, cost, auditability,
  portability, and consistent product behavior.
- **Alternatives considered:** Direct provider calls per business module;
  provider SDK wrappers inside each domain; Flutter-to-provider calls.
- **Accepted trade-offs:** Additional internal interfaces and one extra
  coordination layer.
- **Security impact:** Centralizes secret isolation and prevents provider
  credentials or native payloads from reaching clients and business modules.
- **Cost impact:** Enables global budgets, routing, caching, reconciliation,
  and provider price comparison; adds modest platform overhead.
- **Scalability impact:** Gives one controlled execution seam that can scale
  independently when justified.
- **Migration impact:** Existing direct Anthropic/OpenAI calls remain legacy
  until moved behind the seam without changing public product contracts.
- **Implementation priority:** Must implement before internal alpha for every
  AI feature admitted to that alpha.

### AI-PLAT-002 — Product APIs remain the external contract

- **Decision:** Flutter and other clients call product APIs, never internal AI
  platform components.
- **Rationale:** Product APIs own authorization, validation, domain semantics,
  backward compatibility, and user-facing response contracts.
- **Alternatives considered:** A public generic AI endpoint; direct client
  access to the Orchestrator or Gateway.
- **Accepted trade-offs:** Product modules must maintain explicit use-case
  contracts instead of relying on one untyped chat surface.
- **Security impact:** Prevents bypass of product authorization and data-scope
  controls.
- **Cost impact:** Avoids uncontrolled generic usage and improves attribution
  by feature.
- **Scalability impact:** Product endpoints and AI execution can evolve and
  scale independently behind stable contracts.
- **Migration impact:** Existing FastAPI routes stay compatible while their
  internal execution path changes later.
- **Implementation priority:** Must implement before internal alpha.

### AI-PLAT-003 — Control plane is separate from execution

- **Decision:** The Orchestrator owns policy and route decisions; the Gateway
  owns normalized execution; adapters own provider translation.
- **Rationale:** Combining these roles would recreate provider coupling and
  make policy, billing, and fallback difficult to audit.
- **Alternatives considered:** One provider-switching service; policy inside
  adapters; routing inside business modules.
- **Accepted trade-offs:** More explicit contracts and correlation across
  components.
- **Security impact:** Least-privilege scopes can be applied to policy data,
  execution, and provider secrets separately.
- **Cost impact:** Makes per-attempt cost visible and allows routing policy to
  change without changing adapters.
- **Scalability impact:** Execution hotspots can scale without duplicating
  product policy.
- **Migration impact:** A compatibility path may initially host these logical
  components in one FastAPI deployment, provided boundaries remain explicit.
- **Implementation priority:** Must implement before internal alpha.

### AI-PLAT-004 — Deterministic and grounded authorities outrank models

- **Decision:** Aviation legality, operational rules, calculations, and
  governed manual content remain authoritative; AI may explain or orchestrate
  them but may not replace them with model memory.
- **Rationale:** NAJM is aviation-sensitive and must be reproducible,
  traceable, and safe under provider failure.
- **Alternatives considered:** Model-only answers; prompts containing copied
  rule constants; accepting uncited model knowledge.
- **Accepted trade-offs:** Some responses will abstain or be less conversational
  when authoritative context is missing.
- **Security impact:** Reduces prompt-injection and untrusted-context influence
  over operational outcomes.
- **Cost impact:** Deterministic execution can avoid unnecessary model calls;
  grounding and validation add compute and storage cost.
- **Scalability impact:** Deterministic engines scale separately and can serve
  degraded mode without AI providers.
- **Migration impact:** Existing legality-rule and knowledge sources are
  preserved and exposed to AI only through governed context/tool boundaries.
- **Implementation priority:** Must implement before internal alpha.

### AI-PLAT-005 — Registry data replaces provider constants

- **Decision:** Provider and model identities, prompt versions, capabilities,
  and route eligibility become governed registry data rather than
  business-module constants.
- **Rationale:** Portability and controlled rollback require centrally
  versioned assets.
- **Alternatives considered:** Environment-only model strings; constants in
  every module; provider-specific feature code.
- **Accepted trade-offs:** Registry availability and governance become runtime
  dependencies and must fail safely.
- **Security impact:** Supports explicit allowlists and prevents unapproved
  model/provider use.
- **Cost impact:** Allows price and margin metadata to guide policy without
  product code releases.
- **Scalability impact:** New providers and models can be added without
  multiplying business integrations.
- **Migration impact:** Existing constants remain compatibility inputs until
  each call site is migrated and verified.
- **Implementation priority:** Must implement before internal alpha for active
  routes; broader administration can mature before paid launch.

## Security considerations

- Provider secrets remain server-side and adapter-scoped.
- Firebase identity and claims remain the authentication foundation; product
  APIs must derive actor identity from verified credentials.
- The Cloud Functions service token remains server-only and never becomes a
  client credential.
- Product, user, roster, knowledge, and memory data must be minimized before
  provider transmission.
- Every route must declare permitted data classes and provider-processing
  constraints.
- Provider-native request and response bodies must not be logged by default.
- Zero-knowledge roster credentials can never be inserted into prompts, RAG,
  memory, cache, tools, ledger events, or provider payloads.
- Admin changes to AI policy and registries require least privilege and
  auditable change records.

## Cost considerations

- Users consume NAJM AI Credits, not provider tokens.
- Provider token counts and charges are internal cost facts.
- Billable work eventually requires reservation, actual-usage reconciliation,
  and an immutable ledger event.
- Product modules may request a feature and service level but may not pick a
  cheaper or more expensive provider directly.
- Caching and deterministic handling may reduce provider cost only when safety,
  privacy, freshness, and policy allow.
- Existing cost projections tied to one Claude model are legacy estimates and
  must not be treated as the target platform cost model.

## Scalability considerations

- The boundaries are logical and do not require separate deployments at MVP.
- Product APIs, Orchestrator, Gateway, and adapters may initially coexist in
  the existing stateless FastAPI service if their interfaces and dependency
  directions are preserved.
- Correlation and idempotency must survive retries, worker changes, and later
  service separation.
- Provider-specific concurrency, quota, timeout, and circuit state belong
  behind the Gateway/adapter boundary.
- Registry and policy reads may be cached only with bounded TTLs and safe
  defaults.

## Migration considerations

- Migration is incremental and preserves public product API behavior.
- Direct Anthropic and OpenAI calls are explicitly labeled legacy; they are
  not removed in Phase 1.
- A migrated use case must produce compatible product responses and retain a
  rollback path to its prior implementation until acceptance is complete.
- Provider-specific fields must not leak into new product contracts during
  migration.
- Embeddings follow the same target path as generation: Orchestrator, Gateway,
  and an embedding-capable adapter.
- Current prompts and model constants require inventory and version capture
  before any runtime redirect.

## Delivery classification

This classification states architecture requirements; it is not a plan for a
subsequent phase.

### Must implement before internal alpha

- Mandatory platform call path for every AI feature admitted to alpha.
- Product/API, Orchestrator, Gateway, and adapter boundaries.
- Provider/model/prompt allowlists and version provenance.
- Fail-closed authorization, safety, feature, entitlement, and budget checks.
- Request correlation, idempotency, normalized failures, and provider-secret
  isolation.
- Deterministic-first handling for aviation-sensitive tasks.
- A non-billable or auditable reservation/reconciliation basis for alpha usage.

### Must implement before paid launch

- Immutable AI usage ledger and complete NAJM AI Credit accounting.
- Cost, price, margin, tax/commission, refund, and adjustment reconciliation.
- Production feature flags, entitlements, provider health, incident kill
  switches, audit trails, and retention controls.
- Tested fallback routes and provider-specific capacity controls.
- Billing-support and dispute-grade provenance.

### Deferred until scale justifies it

- Physically separating the logical components into independent services.
- Automated price/performance optimization across many providers.
- Advanced enterprise/family credit pooling beyond an approved product need.
- Dedicated multi-region AI execution.
- Provider-specific commitments or proprietary routing infrastructure.

## Open questions

The following are intentionally unresolved and require later owner approval or
the companion Phase 1 documents:

- Whether the logical Orchestrator and Gateway deploy together or separately.
- The first runtime provider/model route and any default/fallback ordering.
- Exact normalized request, response, streaming, and tool-call schemas.
- Exact data residency and retention policy per provider and data class.
- Credit prices, burn rates, reservation windows, and pool inheritance.
- Which AI capabilities, if any, are admitted to the internal alpha.
- Operational owners and service-level objectives for AI incidents.

## References

- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Secrets Management](../SECRETS.md)
- [Infrastructure Cost Model](../cost-model.md)
- [DevOps Runbook](../devops-runbook.md)
- [OpenAPI — current legacy contract](../openapi.yaml)
- [API contract — current legacy contract](../api-contract.yaml)
- [Zero-Knowledge Credential Model](../ZERO_KNOWLEDGE_CREDENTIALS.md)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
- AI Orchestrator: [AI_ORCHESTRATOR.md](AI_ORCHESTRATOR.md)
- AI Gateway and Provider Adapters:
  [AI_GATEWAY_AND_PROVIDER_ADAPTERS.md](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- Planned Phase 1 companions: AI registries, Prompt Registry, feature
  flags/entitlements, credits/ledger/billing, safety/observability/incidents,
  data-model proposals, and migration strategy.
