# NAJM AI Orchestrator — Responsibilities and Boundaries

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation
**Document role:** Authoritative target-state component contract
**Last reconciled:** 2026-07-16

## Purpose

The AI Orchestrator is the policy and coordination authority for every
target-state AI operation in NAJM. It converts an authenticated product use
case into a governed execution decision, coordinates approved context and
tools, delegates provider execution to the AI Gateway, validates the result,
and closes the accounting and audit obligations.

The Orchestrator is the only component allowed to decide:

- Feature eligibility.
- Entitlement eligibility.
- Budget and NAJM AI Credit eligibility.
- Aviation-safety handling.
- RAG, tool, memory, and cache use.
- Prompt version.
- Model route and fallback route.
- Whether an AI request may execute, degrade, abstain, or be denied.

It never calls an external AI provider directly.

## Scope

This document defines:

- Orchestrator inputs, outputs, responsibilities, and exclusions.
- Its relationship with Product APIs, domain engines, registries, feature
  flags, entitlements, budgets, credits, safety, context services, and the AI
  Gateway.
- Request policy evaluation and decision provenance.
- Failure, fallback, idempotency, and kill-switch behavior.
- Security, cost, scalability, migration, and delivery requirements.

## Non-goals

The Orchestrator does not:

- Replace FastAPI Product APIs or own their public contracts.
- Authenticate raw Firebase tokens itself when the Product API already owns
  that boundary; it consumes trusted verified identity context.
- Own subscription products, payment processing, or authoritative balances.
- Store provider secrets or call provider APIs/SDKs.
- Translate provider-native request or response formats.
- Become the authoritative legality, fatigue, salary, roster, trade, or
  operational-knowledge engine.
- Permit a model to make or override an aviation legality decision.
- Define concrete runtime classes, dependencies, endpoints, collections, or
  deployment topology in Phase 1.

## Current legacy state

Current AI-enabled FastAPI modules combine several responsibilities that the
target Orchestrator will separate. Existing paths may:

- Invoke Anthropic directly for assistant and knowledge responses.
- Invoke OpenAI directly for embeddings.
- Select model names from module constants.
- Keep prompt bodies in runtime modules.
- Apply feature limits or daily usage checks within individual features.
- Perform feature-specific grounding and fallback locally.

These paths remain unchanged during Phase 1. They are legacy migration scope,
not approved examples for new work.

The existing Firebase identity, Free/Pro scaffolding, service-token plane,
legality source of truth, Knowledge Engine, and zero-knowledge roster model are
preserved. The Orchestrator will integrate with their governed interfaces
rather than replacing their authority.

## Approved target state

### Orchestration flow

For an AI-enabled product operation, the target logical flow is:

1. The Product API authenticates the caller, authorizes the product operation,
   validates product input, and derives trusted actor context.
2. The Product API submits a provider-neutral AI work request.
3. The Orchestrator resolves all applicable global, environment, feature,
   entitlement, safety, budget, credit, prompt, model, context, and incident
   policies.
4. The Orchestrator determines whether the operation is denied,
   deterministic-only, cache-served, or eligible for provider execution.
5. If provider execution is allowed, the Orchestrator obtains the required
   credit reservation or non-billable authorization before execution.
6. The Orchestrator selects approved prompt and model-route versions and
   prepares only the authorized RAG, memory, cache, and tool context.
7. The Orchestrator sends a normalized, fully resolved execution request to
   the AI Gateway.
8. The Gateway returns a normalized result, usage facts, safety signals, or
   normalized failure.
9. The Orchestrator validates grounding, structured output, product policy,
   safety policy, and fallback eligibility.
10. The Orchestrator reconciles the reservation, requires immutable usage and
    audit events, and returns a provider-neutral outcome to the Product API.
11. The Product API remains responsible for any resulting business
    transaction or user-facing response.

The ordering above is a responsibility model, not a prescribed runtime
implementation or persistence state machine.

### Policy resolution

Every orchestration decision must be reproducible from a versioned policy
snapshot containing, as applicable:

- Actor and authorization context.
- Environment and tenant or organization context.
- NAJM feature and task classification.
- Global and feature-specific kill-switch states.
- Feature-flag and rollout decision.
- Entitlement decision.
- Budget decision and credit reservation reference.
- Aviation-sensitivity classification.
- Provider, model, prompt, tool, RAG, memory, cache, and fallback policy
  versions.
- Data classification, residency, and retention requirements.
- Request deadline and execution limits.

A later policy change must not alter the record of why an earlier attempt was
allowed, denied, routed, or billed.

## Component responsibilities and boundaries

### The Orchestrator owns

- Provider-neutral AI work coordination.
- Global and feature kill-switch evaluation.
- Feature-flag resolution.
- Entitlement and subscription policy integration.
- Budget-controller integration.
- NAJM AI Credit reservation and reconciliation coordination.
- Aviation-sensitivity classification and deterministic-first enforcement.
- Prompt Registry version resolution.
- Provider Registry and Model Registry route resolution.
- Approved fallback ordering and stopping conditions.
- RAG retrieval policy and authorized context assembly.
- Tool selection, authorization scope, call budget, and result validation.
- Memory-read and memory-write policy.
- Cache eligibility, policy compatibility, and freshness decisions.
- Gateway execution deadlines and normalized constraints.
- Structured output, grounding, citation, and safety validation.
- Request, attempt, reservation, ledger, and audit correlation.
- Provider-neutral result and failure semantics.

### The Orchestrator does not own

- Firebase token verification at the external Product API edge.
- Product-specific input validation or public response compatibility.
- Provider credentials, SDKs, HTTP clients, request translation, or provider
  response parsing.
- Subscription catalog, purchase validation, or payment-provider webhooks.
- Authoritative credit balances or immutable ledger storage.
- Provider-native token pricing as product-visible units.
- Legality-rule values or deterministic aviation calculations.
- Roster-provider credentials or raw private calendar feeds.
- Knowledge-document authoring, approval, or lifecycle.
- Business writes such as accepting a trade or submitting a bid.
- Provider-specific fallback inside an adapter.

## Collaborating component contracts

| Collaborator | Orchestrator consumes | Orchestrator returns or requires |
|---|---|---|
| Product API | Trusted actor context, feature/task, validated product input, data references, idempotency key | Provider-neutral outcome, provenance, safe error, ledger/audit references |
| Feature Flag service | Versioned flag decision and rollout context | Evaluation identifiers for audit |
| Entitlement service | Authoritative access decision and limits | Feature usage intent and final outcome where consumption applies |
| Budget Controller | Request-level cost ceiling and policy | Estimated route cost, reservation request, actual cost facts |
| AI Credit service | Available pool and reservation result | Reconciliation or release instruction tied to idempotency |
| Safety policy | Task classification and required controls | Evidence of deterministic grounding, validation, abstention, or denial |
| Prompt Registry | Immutable approved prompt version and variables contract | Prompt-version provenance and validation result |
| Provider/Model Registries | Eligible routes, capabilities, status, pricing metadata, constraints | Route decision and attempt outcome |
| RAG boundary | Authorized query context and retrieval policy | Grounded passages, source/version metadata, retrieval confidence |
| Tool boundary | Approved tool schema, authorization, and call limits | Typed tool results and provenance |
| Memory boundary | Scoped memory policy and permitted keys | Authorized memory snapshot or write request |
| Cache boundary | Policy-compatible lookup key and freshness requirements | Hit/miss, provenance, and cached result if permitted |
| AI Gateway | Resolved execution request and attempt policy | Normalized result, usage facts, provider identifiers, or normalized error |
| Ledger/Audit boundary | Final immutable event facts | Event identifiers and append outcome |

## Required conceptual interfaces

These are required information contracts, not code schemas or endpoint
definitions.

### AI work request

A Product API request to the Orchestrator must carry:

- Logical request identifier.
- Idempotency key scoped to the product operation.
- Trusted actor identifier and authorization context.
- Environment, tenant, family, corporate, or enterprise context when
  applicable.
- NAJM feature key and task type.
- Validated product input or authorized data references.
- Locale and required response shape.
- Product-supplied sensitivity hints, without allowing a caller to downgrade a
  server-derived safety classification.
- Deadline and product transaction reference.
- Optional continuity reference for an approved conversation or workflow.

It must not carry:

- Provider credentials.
- A provider SDK client.
- An unrestricted provider or model override.
- An unregistered prompt body.
- A flag to bypass entitlement, budget, credits, safety, retention, ledger, or
  audit controls.
- Roster-provider credentials or raw private feed data.

### Orchestration policy snapshot

The Orchestrator must produce an immutable decision view containing:

- Applicable policy and registry versions.
- Allow, deny, deterministic-only, cache, or provider-execution decision.
- Reason codes suitable for product handling and audit.
- Approved route and fallback route identifiers, not secret configuration.
- Context/tool/memory/cache plan.
- Prompt version and required variables.
- Budget ceiling and credit reservation reference.
- Data-handling and retention classification.
- Incident and kill-switch state.

### Gateway execution plan

The resolved plan sent to the Gateway must contain only execution facts:

- Request and attempt identifiers.
- Selected registry provider and model keys.
- Capability and normalized input.
- Resolved prompt/message or embedding input.
- Approved tool schemas when supported.
- Normalized generation controls.
- Deadline, timeout, and bounded-retry rules.
- Data-handling classification.
- Idempotency and trace context.

The Gateway is not asked to re-evaluate product policy.

### Orchestration outcome

The Product API receives:

- Outcome classification: completed, denied, unavailable, deterministic-only,
  cached, abstained, or invalid.
- Provider-neutral content or structured result.
- Grounding, citation, tool, and deterministic-engine provenance.
- Safety validation status and user-safe reason codes.
- Prompt, model-route, and policy versions.
- Credit reconciliation and ledger references when applicable.
- Request and attempt correlation identifiers.
- Instructions about whether the Product API may commit its business
  transaction.

Provider-native payloads remain internal to the Gateway/adapter boundary.

## RAG, tools, memory, and cache boundaries

### RAG

- The Orchestrator decides whether retrieval is required and which approved
  corpus, versions, filters, and citation policy apply.
- The Knowledge Engine owns document ingestion, versioning, retrieval facts,
  and source metadata.
- Retrieved text is untrusted model context and cannot override system policy,
  deterministic rules, authorization, or tool controls.
- Embedding generation must eventually use the AI Gateway and an
  embedding-capable adapter.
- An aviation-sensitive answer that requires a governed source must abstain
  when adequate grounded material is unavailable.

### Tools

- The Orchestrator chooses only registered tools allowed for the feature,
  actor, safety class, and request.
- Tools invoke deterministic domain services or authorized data access; they
  do not call AI providers.
- Tool input and output are typed, bounded, validated, and correlated.
- A model request for an unregistered or unauthorized tool is rejected.
- A model cannot directly commit a bid, trade, subscription, or other
  consequential business action.

### Memory

- Memory is a governed context source, not an unrestricted transcript store.
- The Orchestrator applies identity, purpose, consent, retention, data-class,
  and write-policy controls.
- Memory must be user- and tenant-scoped and cannot contain provider secrets or
  roster-provider credentials.
- Product records and authoritative user data remain outside model-owned
  memory.

### Cache

- Cache use requires a policy-compatible key covering the feature, authorized
  scope, prompt/model/policy versions, safety class, and freshness boundary.
- A cache hit cannot bypass entitlement, kill-switch, privacy, or audit
  requirements.
- Safety-sensitive results must not be reused after their authoritative data or
  rule version changes.
- Credit treatment for cache hits is intentionally deferred to the approved
  credits and billing document.

## Failure, fallback, and kill-switch semantics

- The Orchestrator denies before provider execution when authentication
  context, authorization, feature policy, entitlement, safety policy, budget,
  reservation, prompt, or route approval is missing.
- A global AI kill switch stops all provider execution while preserving
  independent deterministic product behavior.
- Provider, model, feature, prompt-version, tool, RAG, memory, and
  organization-level kill switches may narrow the affected scope.
- The Orchestrator, not the Gateway or adapter, decides whether a normalized
  failure qualifies for retry or fallback.
- Fallback is allowed only to an explicitly approved route satisfying the same
  task capability, data-handling, safety, region, deadline, and budget
  constraints.
- Safety controls must not be weakened to obtain a fallback response.
- Content blocking, grounding failure, structured-output failure, and safety
  validation failure are not automatically equivalent to provider
  unavailability.
- Each attempt has a unique attempt identifier under one logical request and
  idempotency key.
- An uncertain provider outcome must be reconciled before another billable
  attempt can produce a duplicate user charge.
- Exhausted fallbacks produce a normalized unavailable or abstained outcome.
- Incident policy may force deterministic-only mode even when providers are
  technically healthy.

## Architectural decisions

### AI-ORCH-001 — Central policy authority

- **Decision:** The Orchestrator is the single target-state authority that
  combines feature, entitlement, budget, credit, safety, context, prompt,
  route, fallback, and incident policy for an AI operation.
- **Rationale:** Distributed policy inside features produces inconsistent
  access, safety, cost, and audit behavior.
- **Alternatives considered:** Policy in each Product API; policy in the
  Gateway; policy in provider adapters.
- **Accepted trade-offs:** The Orchestrator becomes a critical dependency and
  requires strong availability and safe caching.
- **Security impact:** Centralizes least-privilege checks and prevents bypass
  through a weaker feature path.
- **Cost impact:** Enables one reservation and cost-control path before paid
  execution.
- **Scalability impact:** Policy evaluation can be cached and scaled separately
  from provider execution.
- **Migration impact:** Legacy feature-local checks remain until each use case
  is routed through the Orchestrator.
- **Implementation priority:** Must implement before internal alpha.

### AI-ORCH-002 — Deterministic engines retain domain authority

- **Decision:** The Orchestrator coordinates deterministic tools and grounded
  context but cannot originate or override authoritative aviation results.
- **Rationale:** Aviation-sensitive outcomes require reproducible domain logic
  and approved sources.
- **Alternatives considered:** Model-generated legality; copied rule values in
  prompts; provider-specific safety logic as the authority.
- **Accepted trade-offs:** AI responses may abstain and some tasks require
  additional deterministic calls.
- **Security impact:** Limits prompt injection and model behavior from changing
  consequential results.
- **Cost impact:** Deterministic-first handling can eliminate unnecessary model
  calls; validation adds bounded processing.
- **Scalability impact:** Domain engines remain independently scalable and
  usable during AI outages.
- **Migration impact:** The current legality and knowledge authorities are
  preserved and exposed through governed context/tool contracts.
- **Implementation priority:** Must implement before internal alpha.

### AI-ORCH-003 — Versioned decision provenance

- **Decision:** Every orchestration outcome records the policy and asset
  versions that determined it.
- **Rationale:** Routing, prompts, flags, safety policy, and prices change over
  time; incidents and billing disputes require reproducibility.
- **Alternatives considered:** Log only provider/model; retain only the final
  text; rely on current registry state.
- **Accepted trade-offs:** More metadata and immutable audit storage.
- **Security impact:** Supports forensic review while requiring strict
  minimization of PII and prompt content.
- **Cost impact:** Adds small storage/write cost and reduces investigation and
  dispute cost.
- **Scalability impact:** Append-only metadata scales independently of request
  payload retention.
- **Migration impact:** Legacy calls need captured compatibility identifiers
  until fully migrated.
- **Implementation priority:** Must implement before internal alpha.

### AI-ORCH-004 — Idempotent reservation and reconciliation

- **Decision:** Billable orchestration requires one logical idempotency scope,
  reservation before execution, and reconciliation or release after outcome.
- **Rationale:** Retries, timeouts, fallbacks, and duplicate client requests
  must not create duplicate charges or unbounded provider spend.
- **Alternatives considered:** Charge after response only; decrement credits in
  each feature; trust provider request IDs alone.
- **Accepted trade-offs:** Reservation expiry and uncertain-outcome handling
  add workflow complexity.
- **Security impact:** Prevents replay-based credit abuse and unauthorized
  spend.
- **Cost impact:** Bounds spend and aligns internal credits with actual
  provider facts.
- **Scalability impact:** Requires transactional or otherwise atomic
  reservation semantics at high concurrency.
- **Migration impact:** Existing daily caps remain until the credit system is
  implemented; Phase 1 creates no balances or ledger.
- **Implementation priority:** Basic semantics before internal alpha; complete
  dispute-grade accounting before paid launch.

### AI-ORCH-005 — Central fallback and incident control

- **Decision:** Only the Orchestrator may choose semantic fallback or enforce
  AI degraded mode; the Gateway and adapters report facts and perform only
  bounded transport behavior.
- **Rationale:** Safe fallback depends on product, safety, entitlement, data,
  budget, and incident policy unavailable to adapters.
- **Alternatives considered:** Adapter-local fallback; Gateway selecting the
  cheapest available provider; business-module retry loops.
- **Accepted trade-offs:** The Orchestrator needs timely health and incident
  signals.
- **Security impact:** Prevents fallback to an unapproved provider, region, or
  data-processing policy.
- **Cost impact:** Prevents uncontrolled retry cascades and allows capped
  fallback spend.
- **Scalability impact:** Central retry budgets reduce provider stampedes.
- **Migration impact:** Legacy provider-specific degraded modes are documented
  compatibility behavior until replaced.
- **Implementation priority:** Must implement before internal alpha.

### AI-ORCH-006 — Context is minimized and governed

- **Decision:** RAG, tools, memory, and cache are separate governed boundaries;
  the Orchestrator authorizes the minimum context needed for each operation.
- **Rationale:** A generic context bucket would mix authority, privacy,
  freshness, and retention semantics.
- **Alternatives considered:** Send all user context to every provider; store
  complete conversations indefinitely; let models request arbitrary data.
- **Accepted trade-offs:** More policy metadata and feature-specific context
  design.
- **Security impact:** Reduces data leakage and preserves zero-knowledge roster
  credential guarantees.
- **Cost impact:** Smaller prompts lower provider cost; retrieval and policy
  checks add bounded internal cost.
- **Scalability impact:** Context services can scale and cache independently.
- **Migration impact:** Existing RAG and assistant context paths require
  inventory before redirection.
- **Implementation priority:** Must implement before internal alpha for any
  context-bearing feature.

## Security considerations

- Trust only identity and authorization context established by an authenticated
  server boundary.
- Recheck context ownership and purpose before retrieving roster, memory, or
  knowledge data.
- Derive sensitive classifications server-side; callers cannot downgrade them.
- Never place provider secrets, service tokens, Firebase tokens, roster
  credentials, or secret-bearing feed URLs in orchestration payloads.
- Use least-privilege access for registry, entitlement, budget, ledger,
  incident, memory, and tool services.
- Redact or hash user identifiers in operational metrics where full identity is
  unnecessary.
- Do not log prompt bodies, retrieved roster content, memory content, or model
  output by default.
- Treat model output and retrieved document text as untrusted until validated.

## Cost considerations

- Resolve feature eligibility and safe cache/deterministic paths before paid
  provider execution.
- Request a reservation against a policy-approved maximum rather than assuming
  actual provider cost.
- Carry provider-neutral estimated cost into route evaluation and actual
  provider usage into reconciliation.
- Bound tool loops, fallback attempts, output size, context size, and deadline.
- Do not allow product modules or model output to increase a budget.
- Cost and margin policy remains outside the Orchestrator and is consumed from
  the Budget Controller and registries.

## Scalability considerations

- Orchestration must be stateless between calls except for durable request,
  reservation, ledger, and audit records.
- Policy/registry data may use bounded caches with version-aware invalidation.
- Request deadlines and retry budgets must include all context, tool, and
  provider attempts.
- Tool and fallback fan-out must be bounded; no unbounded model-driven loops.
- Conversation continuity must use explicit durable references, not
  worker-local memory.
- The logical component can initially run in the FastAPI monolith and later be
  separated without changing Product API contracts.

## Migration considerations

- Migrate one product use case at a time behind its existing Product API.
- Preserve current response shape, authentication, entitlement behavior, and
  product transaction semantics during compatibility periods.
- Capture the legacy prompt, model, feature-limit, and fallback behavior before
  redirecting a use case.
- Compare legacy and orchestrated outcomes in a non-user-visible validation
  mode only when later explicitly approved.
- Rollback changes the internal execution path, not the client contract.
- Direct Anthropic/OpenAI code remains untouched in Phase 1.

## Delivery classification

This is an architecture classification, not a plan for a subsequent phase.

### Must implement before internal alpha

- Provider-neutral work request and outcome contracts.
- Central policy resolution and provenance.
- Safety classification and deterministic-first behavior.
- Feature, entitlement, budget, and reservation checks.
- Prompt/model route resolution through approved registries.
- Idempotency, bounded attempts, normalized failures, and kill switches.
- Governed RAG/tool/memory/cache access for admitted features.

### Must implement before paid launch

- Complete immutable usage and credit-ledger integration.
- Transactional entitlement consumption and credit reconciliation.
- Cost/margin attribution, adjustment, refund, and dispute provenance.
- Production incident controls, dashboards, alerts, and audited admin
  overrides.
- Tested fallback policies under provider and registry failures.

### Deferred until scale justifies it

- Separate Orchestrator deployment.
- Complex multi-agent workflows.
- Dynamic cross-provider optimization based on live benchmarks.
- Long-lived generalized memory beyond approved product needs.
- Organization-specific policy composition beyond actual enterprise demand.

## Open questions

- Exact transport and schema for Product API to Orchestrator calls.
- Whether actor claims are embedded in a trusted request context or referenced
  by an internal authorization decision ID.
- Exact safety-class taxonomy and approving owner.
- Whether any cache hit consumes NAJM AI Credits.
- Maximum tool-call and fallback-attempt policies by feature.
- Conversation and memory retention periods.
- Which orchestration metadata is retained for internal alpha versus paid
  launch.
- Deployment topology and service-level objectives.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Gateway and Provider Adapters](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Secrets Management](../SECRETS.md)
- [Zero-Knowledge Credential Model](../ZERO_KNOWLEDGE_CREDENTIALS.md)
- [Roster Synchronization](../ROSTER_SYNC.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
- Planned Phase 1 companions: registries, Prompt Registry, feature
  flags/entitlements, credits/ledger/billing, safety/observability/incidents,
  data-model proposals, and migration strategy.
