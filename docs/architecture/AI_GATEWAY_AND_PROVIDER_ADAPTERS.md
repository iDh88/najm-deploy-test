# NAJM AI Gateway and AI Provider Adapters

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation
**Document role:** Authoritative target-state execution and adapter contract
**Last reconciled:** 2026-07-16

## Purpose

This document defines the provider-neutral execution boundary of the NAJM AI
Platform.

The AI Gateway executes a fully resolved AI request and normalizes the result.
An AI Provider Adapter translates that normalized request to one external
provider and translates the provider response back. AI Provider Adapters are
the only components permitted to call provider SDKs or APIs.

The Gateway does not make product, entitlement, safety, prompt, credit, or
semantic fallback decisions. Those belong to the AI Orchestrator.

## Scope

This document defines:

- AI Gateway responsibilities and exclusions.
- The mandatory AI Provider Adapter contract.
- Normalized request, response, usage, streaming, tool-call, embedding, and
  error concepts.
- Provider capability negotiation.
- Adapter-scoped secret handling.
- Transport retry, timeout, idempotency, health, and failure semantics.
- Compatibility for GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, and future
  providers.
- Security, cost, scalability, migration, and rollback boundaries.

## Non-goals

This document does not:

- Create an AI Gateway or any provider adapter.
- Add provider SDKs, API keys, environment variables, endpoints, or runtime
  configuration.
- Select a preferred provider, model, or fallback order.
- Define model or provider registry storage.
- Define prompt bodies or prompt-version workflow.
- Define NAJM AI Credit prices or user billing.
- Allow Product APIs, domain engines, Flutter, Cloud Functions, RAG services,
  or tools to call providers directly.
- Treat a provider safety classifier as authoritative aviation safety.
- Require the Gateway or adapters to be separate deployable services.

## Current legacy state

Current runtime modules call Anthropic directly for assistant and knowledge
generation and OpenAI directly for embeddings. Existing documents also refer
to Claude-specific model settings, degraded mode, monitoring, pricing, and
secret names.

Those direct calls and provider-specific controls remain current legacy
behavior. Phase 1 does not remove, wrap, refactor, or reconfigure them.

The approved target converts each such integration into:

    AI Orchestrator
      -> AI Gateway
          -> selected AI Provider Adapter
              -> external provider

Until a call site has been migrated and accepted, documentation must clearly
distinguish its legacy direct path from this unimplemented target.

## Approved target state

### Gateway execution boundary

For each provider attempt, the Orchestrator submits one resolved,
provider-neutral execution plan. The Gateway:

1. Validates required identifiers, deadline, capability, route, and execution
   constraints.
2. Confirms that the selected provider/model route is still enabled and that
   an adapter binding exists.
3. Resolves the adapter without exposing its secret material.
4. Enforces normalized request-size, timeout, concurrency, and bounded
   same-route retry controls.
5. Invokes exactly one adapter per attempt.
6. Normalizes content, structured output, tool calls, embeddings, finish
   reason, usage, provider identifiers, latency, safety signals, or error.
7. Emits provider-neutral telemetry and returns the result to the Orchestrator.

The Gateway must not choose a different provider or model. If the route is
unavailable or fails, it reports normalized facts; the Orchestrator decides
whether another approved attempt is permitted.

### AI Provider Adapter boundary

An adapter is a provider-specific translation and invocation component. It:

- Maps normalized requests to the provider API or SDK.
- Applies provider authentication through its scoped secret reference.
- Maps normalized generation controls to supported provider parameters.
- Executes the provider request with bounded transport behavior.
- Maps provider content, structured output, tool calls, embeddings, finish
  reasons, safety signals, usage, request identifiers, and errors into the
  normalized Gateway contract.
- Declares capabilities and known limitations.
- Redacts secrets and prevents provider-native payload leakage.

An adapter does not:

- Decide whether the user is entitled.
- Select prompts, models, providers, fallbacks, or credit prices.
- Fetch arbitrary product data.
- Execute domain tools.
- Write business state.
- Mark an aviation result legal or safe.
- Call another provider or adapter.

## Provider compatibility

The target supports the following as adapter families, not product
dependencies:

| Provider family | Target relationship | Phase 1 implementation claim |
|---|---|---|
| GLM | AI Provider Adapter selected through registries | None |
| Claude | AI Provider Adapter; current direct Anthropic path is legacy | None |
| OpenAI | AI Provider Adapter; current direct embedding path is legacy | None |
| Gemini | AI Provider Adapter selected through registries | None |
| DeepSeek | AI Provider Adapter selected through registries | None |
| Qwen | AI Provider Adapter selected through registries | None |
| Future provider | New adapter implementing the same contract | None |

No provider is enabled merely because it appears in this table. Activation
requires approved registry entries, model capability data, adapter
configuration, secrets, safety/data review, feature policy, and operational
health controls.

## Component responsibilities and boundaries

### AI Gateway owns

- Execution-plan validation.
- Registry-key-to-adapter binding.
- Execution-time provider/model enabled-state validation.
- Capability compatibility validation.
- Normalized request constraints.
- Provider-specific concurrency and quota coordination.
- Deadlines, timeouts, circuit state, and bounded same-route transport retry.
- Adapter invocation.
- Normalized response, usage, and error envelopes.
- Attempt-level correlation and provider request identifiers.
- Provider-neutral metrics and health facts.
- Prevention of provider-native payload leakage across the boundary.

### AI Gateway does not own

- Product authentication or authorization.
- Feature flags, entitlements, subscriptions, budgets, credit balances, or
  pricing charged to users.
- Prompt authoring, approval, or semantic variable validation.
- Model/provider/fallback selection.
- RAG retrieval, memory policy, cache eligibility, or tool execution.
- Aviation-sensitive task classification.
- Grounding sufficiency or final product-output validation.
- Business transactions.

### AI Provider Adapter owns

- Provider authentication and provider-scoped secret use.
- Provider endpoint/SDK interaction.
- Provider request translation.
- Provider response and error translation.
- Provider usage-fact extraction.
- Provider request ID and rate-limit metadata extraction.
- Provider-specific streaming frame translation.
- Capability and configuration self-description.

### AI Provider Adapter does not own

- Cross-provider routing.
- Product- or user-visible pricing.
- Subscription or credit logic.
- Prompt Registry state.
- Product data retrieval.
- Safety policy or authoritative deterministic calculations.
- Provider-independent retry/fallback policy.

## Required conceptual interfaces

The following are logical contracts for later implementation. They do not
select a programming language, SDK, transport, or deployment model.

### Normalized Gateway execution request

Every attempt must include:

- Logical request identifier.
- Unique attempt identifier.
- Idempotency key or provider-safe derived key.
- Correlation and trace context.
- Provider Registry key and Model Registry key selected by the Orchestrator.
- Required capability, such as text generation, structured generation,
  tool-capable generation, embeddings, vision, or streaming.
- Resolved prompt/messages, embedding input, or other normalized input.
- Approved structured-output schema or tool schemas when applicable.
- Provider-neutral generation constraints.
- Deadline, timeout, and bounded same-route retry allowance.
- Data classification, region/residency constraints, and retention policy
  identifier.
- Prompt, policy, and route versions for telemetry.

The request must not include:

- Raw provider credentials.
- A caller-controlled provider endpoint.
- A request to ignore registry, safety, or data-handling restrictions.
- Business transaction instructions.
- Roster-provider credentials or secret-bearing feed URLs.

### Normalized Gateway result

A successful result must provide, when applicable:

- Logical request and attempt identifiers.
- Registry provider and model keys.
- Provider request identifier.
- Normalized text or structured content.
- Normalized tool-call requests.
- Embedding vector and dimensional metadata.
- Streaming completion status.
- Finish reason.
- Provider safety/moderation signals as facts, not final NAJM decisions.
- Native provider usage facts with unit labels.
- Estimated or reported provider cost facts and currency when available.
- Latency and retry count.
- Cache-related provider headers when relevant.
- Adapter and contract version.

Provider-native request or response bodies must never cross the adapter
boundary into Gateway consumers, Product API contracts, ledgers, or ordinary
telemetry. The adapter may inspect them only ephemerally to perform
normalization and redaction.

### Normalized error

Every failure must map to a stable provider-neutral category:

- Configuration unavailable.
- Authentication or credential rejected.
- Model or capability unavailable.
- Invalid normalized request.
- Provider-invalid request after translation.
- Content blocked.
- Rate limited or quota exhausted.
- Timeout.
- Provider unavailable.
- Transport failure.
- Contract or response-shape violation.
- Output incomplete or streaming interrupted.
- Usage or billing facts uncertain.
- Cancelled.
- Unknown provider failure.

The error must also state:

- Whether a same-route transport retry is safe.
- Whether provider execution may have occurred.
- Whether usage/cost is known, zero, partial, or uncertain.
- Provider request ID when known.
- Retry-after information when available.
- Sanitized diagnostic code.

The error must not decide cross-provider fallback or user credit treatment.

### AI Provider Adapter contract

Every adapter must support the following conceptual operations:

| Operation | Required behavior |
|---|---|
| Identity | Expose stable adapter and provider keys plus contract version |
| Capabilities | Declare supported task types, modalities, tools, structured output, streaming, usage detail, and limits |
| Configuration validation | Report configured/unconfigured without returning secret values |
| Request translation | Map only supported normalized fields; reject unsupported semantics explicitly |
| Execution | Call only the adapter’s provider with bounded timeout and cancellation handling |
| Response normalization | Return normalized content, tool calls, embeddings, finish reason, usage, and provider request ID |
| Error normalization | Map provider errors to the standard taxonomy and uncertainty facts |
| Usage normalization | Preserve native units and expose enough facts for cost reconciliation |
| Health signal | Provide configuration and recent execution health without making paid probe calls by default |
| Redaction | Remove secrets and disallowed provider-native payloads from errors and telemetry |

Adapters must not claim a capability they cannot faithfully normalize.

## Capability negotiation

- The Model Registry describes capabilities and limits for a model version.
- The Provider Registry binds a provider to an approved adapter and operational
  status.
- The Orchestrator selects only routes matching the feature policy.
- The Gateway revalidates the selected capability against current registry and
  adapter declarations before execution.
- A mismatch fails before provider invocation and returns a normalized
  configuration/contract error.
- The Gateway must not silently drop a requested schema, tool, safety control,
  modality, or data-handling requirement.
- Provider-specific optional features remain inaccessible until represented in
  the normalized contract and approved registries.

## Streaming, tools, and embeddings

### Streaming

- Streaming is a declared capability, not assumed.
- Stream events must be normalized and correlated to one attempt.
- Partial output is untrusted and non-final until the adapter reports a
  terminal result and usage state.
- Interrupted streams must report execution and usage uncertainty.
- The Product API decides whether streaming is part of its backward-compatible
  public contract.

### Tool calls

- An adapter normalizes provider tool-call requests but never executes tools.
- The Gateway returns the normalized tool call to the Orchestrator.
- The Orchestrator authorizes and invokes the registered deterministic tool,
  then may authorize a subsequent provider attempt.
- Tool names and schemas are NAJM assets; provider-native tool identifiers
  cannot become business-module dependencies.
- Model-proposed arguments are untrusted until validated.

### Embeddings

- Embeddings are an AI Platform capability and follow the same Orchestrator,
  Gateway, and adapter path as generation.
- The normalized result records model version, vector dimension, normalization
  metadata, and usage facts.
- Stored vector indexes must record the embedding model/version so incompatible
  vectors are never mixed.
- Current direct OpenAI embedding usage remains legacy until migrated.

## Secret and authorization boundary

- Provider credentials exist only in server-side secret storage and are
  resolved for the specific adapter.
- Flutter, the Admin client, Product APIs, domain engines, the Orchestrator,
  prompts, tools, memory, RAG documents, cache entries, ledgers, and telemetry
  never receive secret values.
- The Gateway may hold only a secret reference or adapter binding; the adapter
  is the logical component permitted to resolve and use the credential.
- Credentials are scoped by provider, environment, and runtime identity.
- One provider credential must not grant access to another adapter.
- Secret rotation must not require Product API or business-module changes.
- Adapter configuration health exposes boolean/status facts only.
- The internal service token authenticates NAJM service calls and is never a
  provider credential.

## Failure, retry, and fallback semantics

- A logical request may contain multiple attempts, but each attempt invokes
  exactly one adapter and route.
- The Gateway may retry the same route only for normalized transient transport
  conditions, within the Orchestrator-provided deadline and retry allowance.
- A retry is forbidden when execution may have occurred and idempotency cannot
  prevent a duplicate consequential or billable effect.
- The Gateway never switches provider, model, prompt, task, data policy, or
  safety policy.
- Adapters never fall back internally to another model or endpoint unless that
  endpoint is the same approved registry route and its behavior is explicitly
  represented.
- Circuit breakers and quota controls report route unavailability to the
  Orchestrator.
- The Orchestrator alone decides whether to start a new fallback attempt.
- Usage uncertainty is preserved through reconciliation; it must not be
  converted to zero cost merely because the response failed.
- When all routes fail, the platform returns an honest unavailable,
  deterministic-only, or abstained outcome.

## Observability contract

The Gateway and adapters emit attempt-level facts suitable for metrics and
incident response:

- Request, attempt, trace, adapter, provider, model-route, prompt-version, and
  feature identifiers.
- Start/end time, latency, retry count, deadline outcome, and normalized status.
- Input/output unit counts and estimated/reported internal cost.
- Rate-limit, circuit, configuration, capability, and provider-health signals.
- Content-block and contract-validation counts.
- Fallback eligibility facts, without making the fallback decision.

They must not emit:

- Secret values or authorization headers.
- Raw roster-provider credentials or feed URLs.
- Raw prompts, retrieved roster content, memory, or model output by default.
- Unredacted provider-native error bodies.

## Architectural decisions

### AI-GW-001 — Gateway is execution-only

- **Decision:** The Gateway validates and executes an Orchestrator-selected
  route and normalizes its outcome; it does not own product or semantic policy.
- **Rationale:** A narrow execution boundary keeps routing, safety, billing, and
  provider translation independently auditable.
- **Alternatives considered:** Gateway as full Orchestrator; policy duplicated
  in adapters; provider selection in Product APIs.
- **Accepted trade-offs:** More explicit internal contracts and coordination.
- **Security impact:** Prevents execution infrastructure from bypassing
  entitlement or product authorization.
- **Cost impact:** Makes provider attempts measurable without embedding user
  pricing logic in transport code.
- **Scalability impact:** Execution can scale by provider/capability without
  duplicating product policy.
- **Migration impact:** Legacy calls are first represented as normalized
  attempts before product modules can be decoupled.
- **Implementation priority:** Must implement before internal alpha.

### AI-GW-002 — Adapters are the exclusive provider boundary

- **Decision:** Only AI Provider Adapters may call provider SDKs or APIs.
- **Rationale:** One enforceable dependency direction prevents provider
  coupling from spreading back into business modules.
- **Alternatives considered:** Shared provider utility imported anywhere;
  provider SDKs in Product APIs; direct client calls.
- **Accepted trade-offs:** Every provider capability requires adapter
  normalization before use.
- **Security impact:** Constrains provider secrets and outbound data to a
  reviewable boundary.
- **Cost impact:** Centralizes usage facts and avoids unaccounted calls.
- **Scalability impact:** Providers can be added or removed without changing
  product modules.
- **Migration impact:** Direct Anthropic/OpenAI call sites remain legacy until
  moved; no new direct call is permitted.
- **Implementation priority:** Must implement before internal alpha.

### AI-GW-003 — Normalized contract with explicit capabilities

- **Decision:** Requests, responses, usage, tool calls, embeddings, streaming,
  and errors use a provider-neutral contract with explicit capability checks.
- **Rationale:** Lowest-common-denominator assumptions silently lose semantics
  and make provider swaps unsafe.
- **Alternatives considered:** Expose provider-native payloads; one untyped
  text contract; per-feature provider DTOs.
- **Accepted trade-offs:** New provider-specific features wait until the
  normalized contract is deliberately extended.
- **Security impact:** Validation and allowlisting reduce unreviewed parameter
  and payload exposure.
- **Cost impact:** Usage normalization enables comparable internal cost facts.
- **Scalability impact:** Stable contracts support parallel adapters and later
  service separation.
- **Migration impact:** Existing provider responses require compatibility
  mapping without changing public Product API responses.
- **Implementation priority:** Must implement before internal alpha.

### AI-GW-004 — No hidden semantic fallback

- **Decision:** Gateway retries are same-route and bounded; cross-provider or
  cross-model fallback is exclusively an Orchestrator decision.
- **Rationale:** Fallback must preserve feature, safety, data, budget,
  entitlement, and capability policy.
- **Alternatives considered:** Adapter-local fallback; automatic cheapest-route
  selection; business-module retry.
- **Accepted trade-offs:** Some failures return to the Orchestrator rather than
  being hidden.
- **Security impact:** Prevents data from reaching an unapproved provider or
  region.
- **Cost impact:** Avoids uncontrolled retry/fallback spend.
- **Scalability impact:** Central retry budgets reduce cascading load.
- **Migration impact:** Legacy provider-specific degraded modes remain current
  behavior until explicitly migrated.
- **Implementation priority:** Must implement before internal alpha.

### AI-GW-005 — Native usage facts are preserved

- **Decision:** Adapters preserve provider-native usage units and uncertainty;
  the Gateway normalizes labels but does not convert them into user credits.
- **Rationale:** Cost reconciliation and margin accounting require source
  facts, while user pricing is an independent NAJM policy.
- **Alternatives considered:** Store only NAJM Credits; trust invoice totals;
  estimate all usage from text length.
- **Accepted trade-offs:** Ledger events carry more metadata and providers may
  differ in reporting precision.
- **Security impact:** Usage records must avoid prompt/output content and
  unauthorized identifiers.
- **Cost impact:** Enables accurate reconciliation, anomaly detection, and
  provider comparison.
- **Scalability impact:** Compact usage facts scale better than raw payload
  retention.
- **Migration impact:** Legacy calls need a mapping for whatever usage facts
  are available.
- **Implementation priority:** Basic facts before internal alpha; invoice-grade
  reconciliation before paid launch.

### AI-GW-006 — Adapter-scoped provider secrets

- **Decision:** Provider secrets remain server-side, environment-specific, and
  logically scoped to the adapter that uses them.
- **Rationale:** Provider independence is incomplete if credentials are shared
  broadly or leak into clients and product modules.
- **Alternatives considered:** One shared AI secret bundle; client-supplied
  keys; secrets resolved in Product APIs.
- **Accepted trade-offs:** More granular IAM and secret rotation procedures.
- **Security impact:** Reduces blast radius and supports least privilege.
- **Cost impact:** Minor secret-management overhead; fewer compromise and
  rotation costs.
- **Scalability impact:** Independent credentials and quotas support scaling by
  provider and environment.
- **Migration impact:** Existing Anthropic/OpenAI secrets remain current until
  later adapter-scoped migration; Phase 1 changes no secrets.
- **Implementation priority:** Must implement before internal alpha.

## Security considerations

- Validate route keys against approved registries; never accept arbitrary URLs
  or model identifiers from a product caller.
- Use outbound allowlists and TLS for provider traffic.
- Apply request-size, response-size, timeout, concurrency, and cancellation
  controls before provider invocation.
- Minimize transmitted data and honor provider/data-class restrictions.
- Do not send roster-provider credentials, secret-bearing URLs, Firebase
  tokens, service tokens, or unnecessary identifiers.
- Treat all provider output, tool arguments, citations, and safety metadata as
  untrusted facts awaiting Orchestrator/product validation.
- Separate operational telemetry from content retention.
- Sanitize provider errors before returning them across the adapter boundary.

## Cost considerations

- Record native input, output, cached, reasoning, image, audio, embedding, or
  other billable units when a provider exposes them.
- Preserve estimated versus provider-reported versus invoice-reconciled cost
  as distinct facts.
- Bound retries, concurrency, context, output, and streaming duration.
- Do not select a route based on price; the Orchestrator owns the
  policy-approved route.
- Provider prompt caching or batch APIs may be exposed as capabilities only
  after their billing and safety semantics are represented.
- Gateway overhead should remain small compared with provider latency and
  should be observable separately.

## Scalability considerations

- Maintain provider-specific concurrency and quota pools.
- Use bounded queues/backpressure rather than unbounded retry.
- Circuit state is per provider/model route and environment.
- Adapters must be stateless apart from safe connection pools and bounded
  operational state.
- Streaming connections require explicit concurrency and deadline budgets.
- Logical adapter isolation may later become process or service isolation
  without changing Product API or Orchestrator contracts.
- Health checks must avoid paid provider requests unless an explicitly
  approved synthetic probe policy exists.

## Migration considerations

- Preserve public FastAPI response contracts while replacing internal direct
  calls.
- Capture current Claude/OpenAI request, response, error, usage, timeout, and
  degraded-mode behavior before migration.
- Introduce adapters without changing provider behavior first; policy
  optimization is separate.
- Maintain a reversible legacy path per migrated use case until compatibility
  acceptance.
- Model/provider identifiers introduced by the target remain internal registry
  keys and do not leak to Flutter contracts.
- Existing deployment/rollback mechanisms remain valid; a migrated route must
  be rollback-compatible with the previous application revision.

## Delivery classification

This is an architecture classification, not a plan for a subsequent phase.

### Must implement before internal alpha

- Normalized request, result, usage, and error contracts.
- At least one approved adapter for each AI capability admitted to alpha.
- Registry binding, capability validation, adapter-scoped secrets, timeouts,
  bounded retries, correlation, and normalized telemetry.
- Every AI feature admitted to internal alpha uses the AI Platform; direct
  provider access by its Product API, domain engines, tools, or clients is
  forbidden. Unmigrated legacy AI features remain outside the alpha gate.
- Honest unavailable behavior and Orchestrator-controlled fallback.

### Must implement before paid launch

- Invoice-grade usage/cost reconciliation facts.
- Production quota, circuit, concurrency, health, incident, and kill-switch
  integration.
- Tested provider failure, timeout, partial-stream, duplicate, and uncertain
  billing scenarios.
- Audited secret rotation and adapter enable/disable procedures.
- Retention and provider data-processing controls approved for production.

### Deferred until scale justifies it

- Physical Gateway service separation.
- A large adapter catalog beyond approved product demand.
- Multi-region provider egress.
- Provider batch APIs and advanced prompt caching.
- Automatic live price/performance benchmarking.
- Dedicated hardware or self-hosted model adapters.

## Open questions

- Exact normalized schema and transport.
- Required capability set for internal alpha.
- The first approved provider/model routes and fallback order.
- Same-route retry limits by capability.
- Streaming exposure through current Product APIs.
- Permitted sanitized diagnostic metadata beyond normalized error codes,
  without retaining provider-native payloads.
- Provider-specific data regions and retention guarantees.
- Whether adapter isolation is logical, process-level, or service-level at
  initial implementation.
- Health and service-level objectives per provider route.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Orchestrator](AI_ORCHESTRATOR.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Secrets Management](../SECRETS.md)
- [Infrastructure Cost Model](../cost-model.md)
- [DevOps Runbook](../devops-runbook.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Current API contract](../api-contract.yaml)
- [Zero-Knowledge Credential Model](../ZERO_KNOWLEDGE_CREDENTIALS.md)
- Planned Phase 1 companions: AI registries, Prompt Registry, feature
  flags/entitlements, credits/ledger/billing, safety/observability/incidents,
  data-model proposals, and migration strategy.
