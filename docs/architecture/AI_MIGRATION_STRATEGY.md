# NAJM AI Platform — Migration, Compatibility, and Rollback Strategy

**Status:** Approved for Phase 1 documentation, not yet implemented

**Phase:** Phase 1 — Architecture Documentation, Milestone 4

**Document role:** Authoritative target-state migration constraints

**Last reconciled:** 2026-07-16

## Purpose

This document defines the constraints and evidence required for a later,
separately approved migration from current direct Anthropic and OpenAI usage to
the provider-independent NAJM AI Platform. The migration is wrapper-first,
behavior-preserving, server-feature-flagged, observable, and reversible until
parity is approved.

This document does not start that migration. Phase 1 changes no runtime
behavior and leaves every current call path, subscription rule, prompt,
counter, API response, deployment workflow, and provider secret untouched.

## Scope

This document defines:

- Migration principles and backward-compatibility guarantees.
- A current legacy source inventory summary based on completed audit context
  and the explicitly inspected evidence.
- A conceptual sequence for later approved runtime migration.
- Migration paths for direct Anthropic generation, OpenAI embeddings,
  hardcoded prompts, daily counters, subscriptions, entitlements, credits, and
  ledger observation.
- Shadow/advisory and feature-flagged cutover constraints.
- Single-authority dual-read and dual-write boundaries.
- Provider, prompt, ledger, entitlement, and credit fallback semantics.
- Rollback requirements and evidence-preservation rules.
- Provider expansion gates.
- Internal-alpha, paid-launch, and scale-deferred migration requirements.

## Non-goals

This document does not:

- Modify, wrap, refactor, remove, or add any provider call.
- Create an Orchestrator, Gateway, Provider Adapter, registry, prompt asset,
  feature flag, data model, collection, migration, test, or environment
  variable.
- Choose a first target provider, model, route, prompt policy, shadow
  percentage, rollout percentage, incident threshold, or cutover date.
- Resolve current API-contract discrepancies or change a client response.
- Introduce a direct-provider fallback as approved target architecture.
- Implement credits, billing, ledger enforcement, subscriptions, or provider
  pricing.
- Change deployment or rollback workflows.
- Create a Phase 2 implementation plan, task breakdown, estimate, owner
  assignment, or schedule.
- Begin Milestone 5.

## Current legacy state

The following are compatibility facts, not approved future architecture:

- The general AI assistant imports Anthropic directly and performs separate
  provider calls for intent classification, filter extraction, and
  conversational generation.
- The Knowledge Engine assistant independently calls Anthropic for grounded
  question answering.
- The embedding client calls OpenAI directly using a fixed embedding model,
  dimension, and batching behavior.
- Model identifiers, generation limits, prompts, output mapping, and error
  behavior are embedded in runtime modules.
- The CLAUDE_MODEL, AI_MAX_TOKENS, and AI_TEMPERATURE examples in current
  environment documentation are not consumed by the scoped legacy calls;
  executable model and limit constants, not intended configuration, are the
  compatibility evidence to capture.
- The conversational prompt injects current legality values at runtime. Those
  values remain governed deterministic inputs; they must not be frozen as
  unversioned prompt text.
- The filter flow validates model-extracted constraints and passes them to a
  deterministic filter engine. That separation must be preserved.
- A single product request may cause multiple provider attempts while legacy
  counters record only one request.
- Different direct and Cloud Functions paths have different counter timing and
  failure semantics. Knowledge and embedding paths are not fully represented
  by the current daily counter.
- Legacy aiUsage, usageCounters, and rate limiting are not a complete provider
  usage record, immutable ledger, credit balance, or invoice source.
- Current Free/Pro scaffolding and subscriptions-disabled Free-launch behavior
  remain the executable subscription state.
- Current Functions messaging refers to an unlimited Pro upgrade even though
  the scoped enforcement does not establish an approved unlimited-AI policy.
  The wording is a legacy contract discrepancy, not target entitlement.
- Cloud Functions currently call FastAPI rather than a provider, preserving
  that boundary.
- The current AI status surface exposes provider/model fields. That is a
  pre-existing compatibility exception to the provider-independent target and
  requires an owner-approved compatible removal, internalization, or versioned
  contract decision.
- Current API documents and executable behavior contain pre-existing
  compatibility differences, including request/response naming, limits,
  routes, intent shapes, authentication wording, and provider/model exposure.
  A canonical, runtime-verified compatibility contract is therefore required
  before parity can be approved.

This summary uses the completed Phase 0 context and the sources listed in the
Milestone directive. It is not a new code audit and does not declare additional
scope.

## Approved target state

Every migrated AI capability follows:

    Flutter or trusted service caller
      -> unchanged or explicitly versioned FastAPI Product API
      -> AI Orchestrator
      -> AI Gateway
      -> one Provider Adapter per attempt
      -> GLM / Claude / OpenAI / Gemini / DeepSeek / Qwen / future provider

Product features express a provider-neutral NAJM capability and task. The
Orchestrator resolves feature, entitlement, safety, budget, credits, prompt,
RAG, memory, cache, tools, route, and fallback. The Gateway executes a
normalized request. Only the selected Provider Adapter calls the provider.

After migration acceptance, no Product API, domain engine, tool, parser,
scheduler, Flutter client, Cloud Function, or admin UI may call a provider.
Provider and model identity remain internal and are not user-visible product
dependencies, quotas, or entitlements.

## Source-of-truth hierarchy

During migration:

1. Latest explicit owner decision, the Master Directive, Architecture Lock,
   and approved Phase 1 AI documents govern target architecture.
2. Deterministic aviation engines, governed rule sources, Knowledge Engine
   sources, Firebase identity, subscription authority, and product-domain
   stores remain authoritative for their facts.
3. The runtime-verified public Product API contract selected for compatibility
   validation defines accepted external behavior.
4. Versioned target registries, prompts, policies, decisions, attempts, and
   immutable usage records become authority only when their runtime components
   are separately implemented and activated.
5. Existing direct call code, model constants, embedded prompts, counters, and
   deployment revisions remain current compatibility evidence until cutover.
6. Reports, caches, shadow output, analytics, and provider output are evidence
   or derived facts, never authorities for behavior or policy.

When old and target paths coexist, a server-side rollout decision selects
exactly one user-serving execution authority before a request starts.

## Component responsibilities

### Product API compatibility boundary

- Preserve authenticated endpoint behavior, identity derivation, validated
  input, output shape, reason/error mapping, and product transaction semantics
  unless a separately approved API version changes them.
- Call only the selected internal compatibility seam or AI Orchestrator.
- Never expose rollout cohort, provider, model, prompt, native usage, or
  internal cost.
- Keep deterministic paths independently usable.

### Compatibility wrapper

- Provide a provider-neutral seam around each current execution family without
  initially changing accepted behavior.
- Capture request purpose, legacy prompt/model/config identity, normalized
  output, error semantics, and correlation facts.
- Route to exactly one user-serving path based on a server-authoritative flag.
- Never become a permanent provider SDK owner; provider calls move behind
  adapters.

### AI Orchestrator

- Reproduce approved compatibility behavior while enforcing target policy.
- Resolve exact registry, prompt, flag, entitlement, safety, incident, budget,
  and route versions.
- Decide shadow eligibility, semantic fallback, response mode, and rollback
  behavior.
- Coordinate observational ledger facts before any future credit enforcement.
- Never call a provider directly.

### AI Gateway and Provider Adapters

- Match normalized compatibility requests and results.
- Preserve provider-native call composition only to the extent needed for
  accepted parity, while keeping provider specifics outside product modules.
- Emit attempt and ProviderUsageFact records even when user behavior remains
  unchanged.
- Never own product semantics, safety, credits, subscription policy, or
  cross-route fallback.

### Prompt Registry

- Capture current prompt bodies, variable contracts, output contracts,
  generation settings, and hashes as immutable versions.
- Preserve dynamic deterministic values as typed, governed runtime variables.
- Require evaluation and approval before activation.
- Provide prior approved-version rollback; no hidden embedded prompt fallback
  after migration acceptance.

### Feature Flag, Entitlement, Budget, Credit, and Ledger boundaries

- Feature Flags select rollout and can disable the target path server-side.
- Entitlements preserve current Free/Pro and subscriptions-disabled behavior
  until separately changed.
- Budget decisions may begin advisory/non-billable but may not bypass safety or
  authorization.
- Ledger observation records what happened before credit charging is enforced.
- The Milestone 3 architecture governs later reservations, reconciliation,
  immutable credit events, and paid-launch enforcement.

### Deployment and operations

- Use existing approved deployment and revision rollback workflows until a
  later operational change is approved.
- Record deployed revision, migration/flag state, and validation evidence.
- Preserve old approved revision availability only for the bounded rollback
  window.
- Never delete target audit, attempt, usage, or ledger evidence during
  rollback.

## Required boundaries

The following migration-specific boundaries are mandatory in every later
approved implementation.

### No new direct-provider debt

- Existing direct calls are temporary legacy compatibility paths.
- No new business module, Product API, tool, parser, scheduler, client, admin
  UI, or Cloud Function may add provider access during migration.
- New providers enter only through a Provider Adapter after Gateway contract
  and governance approval.
- A compatibility wrapper may invoke an existing legacy call only while that
  exact path remains the selected legacy authority. It is not the target
  Provider Adapter contract.

### Behavior preservation

The first migrated route for a capability must preserve the accepted:

- Product request and response contract.
- Identity and authorization behavior.
- Deterministic engine invocation and rule/source provenance.
- Prompt purpose, variables, model capability, generation bounds, tool-free or
  tool-enabled behavior, and call sequence where required for parity, except
  where an explicit safety correction is separately approved.
- Structured-output validation and deterministic filter handoff.
- User-visible errors, abstention, unavailability, and degradation semantics.
- Free/Pro and subscriptions-disabled access behavior.
- Legacy counter behavior until a separately approved compatibility change.

Preservation means contract and safety parity, not byte-identical generative
text. Exact parity tolerances and the canonical external contract remain open.

### Single authority during coexistence

- A server-side, stable, auditable rollout decision is made before execution.
- Exactly one path supplies the user response and business effect.
- A request cannot fall from the target path into a direct legacy provider call
  after an ambiguous or possibly successful target attempt.
- Dual reads may compare configuration or projections, but only one value is
  authoritative for a decision.
- Temporary dual writes are permitted only for an explicitly defined
  compatibility projection, with idempotency and one declared authority.
- Legacy counters and observational ledger facts may both be written during
  migration; they do not enforce the same concept and must not be reconciled
  into a fictional atomic balance.

## Required semantics

### Migration principles

1. **Documentation-only Phase 1:** no behavior changes now.
2. **Wrapper first:** create a provider-neutral compatibility seam around all
   provider execution families before changing provider behavior.
3. **Capture before optimize:** record current prompt, model, settings, call
   sequence, input/output contract, and error behavior before routing changes.
4. **Deterministic authority first:** preserve legality, filtering, roster,
   authentication, subscription, and product sources.
5. **Prompt governance before experimentation:** register and approve current
   prompts before variants or traffic experiments.
6. **Adapter and Gateway parity before expansion:** prove normalized execution
   before adding providers or optimizing routes.
7. **Safety and incident controls before broad rollout:** kill switches and
   deterministic-only modes precede alpha traffic.
8. **Observe usage before charging:** produce immutable observational usage and
   cost evidence before reservations or credit enforcement.
9. **Server-feature-flagged cutover:** rollout and rollback are controlled
   server-side and audited.
10. **Evidence-based decommission:** remove the legacy fallback only after
    contract, safety, reliability, cost, usage, and rollback parity are
    approved.

### Migration source inventory summary

The later migration must account for these execution families:

| Legacy family | Current compatibility behavior | Target destination |
|---|---|---|
| NLP intent classification | Direct Anthropic call, embedded classification prompt, provider-native response parsing | Orchestrator task -> Gateway -> approved generation adapter |
| Filter extraction | Direct Anthropic call, structured extraction, validation, deterministic filter-engine handoff | Orchestrator task -> Gateway -> adapter; deterministic filter remains authority |
| Conversational assistant | Direct Anthropic generation, embedded prompt, dynamic legality grounding, recent history, legacy response mapping | Orchestrator with Prompt Registry, governed context, safety, Gateway, adapter |
| Knowledge assistant | Knowledge retrieval followed by direct Anthropic generation and citation response | Orchestrator-governed RAG, Prompt Registry, Gateway, adapter |
| Embeddings | Direct OpenAI model, fixed dimension and batch behavior | Orchestrator embedding task -> Gateway -> embedding-capable adapter |
| Daily usage controls | aiUsage and related compatibility counters with path-specific semantics | Preserve initially; add observational ledger; later owner-approved credit enforcement |
| Provider configuration | API keys and runtime constants in current server configuration | Adapter-scoped secrets and Provider/Model Registry references |
| Prompt configuration | Bodies and settings in runtime modules | Immutable Prompt Registry versions and typed runtime variables |

This inventory does not approve exact implementation units or a work schedule.

### Later runtime migration sequence

The following is a required dependency order for any later approved
implementation, not authorization to begin work:

1. Establish a canonical, runtime-verified external compatibility contract and
   accepted parity evidence for each capability.
2. Introduce provider-neutral request, response, error, attempt, and
   idempotency contracts at the compatibility seam.
3. Capture legacy prompt/model/settings/config hashes and dynamic variable
   contracts without changing user behavior.
4. Make the current provider behavior available only through the normalized
   Gateway and its first approved Adapter while preserving the selected
   compatibility path.
5. Put Orchestrator policy, safety classification, kill switches, registry,
   prompt, and route resolution ahead of Gateway execution.
6. Emit redacted decisions, attempts, ProviderUsageFacts, audit events, and
   non-billable/advisory ledger observations.
7. Validate offline or in explicitly approved shadow/advisory mode.
8. Cut over bounded cohorts through a server-side flag with one user-serving
   authority and a tested rollback.
9. Approve parity and remove the direct provider path for that capability.
10. Only after observational evidence and separate commercial approval,
    introduce enforced reservations, reconciliation, and credits for paid
    traffic.

Each capability crosses these gates independently. Completing one does not
authorize another.

### Phase 2 readiness boundary

Without defining or authorizing a Phase 2 plan, a later runtime phase is not
ready to begin until the owner has approved:

- The canonical external compatibility contract and parity criteria.
- Initial capability scope and its safety classification.
- Normalized Orchestrator/Gateway/Adapter contracts.
- First provider/model route and adapter data-handling approval.
- Captured legacy prompt versions and dynamic-variable contracts.
- Server-side feature flag and kill-switch semantics.
- Redacted observability, audit, idempotency, and advisory ledger shapes.
- Test/evaluation evidence, rollback criteria, and operational owners.
- Resolution or explicit acceptance of any current contract discrepancy that
  affects the selected capability.

This boundary is a prerequisite statement only. It contains no task ownership,
sequence by team, estimate, schedule, or runtime authorization.

## Capability migration paths

### Legacy direct Anthropic calls

- Place a compatibility seam around every caller, including paths that invoke
  filter handling outside the primary chat endpoint.
- Capture current prompt, model, parameter, call sequence, validation, timeout,
  and error mapping as compatibility evidence.
- Reproduce the accepted request through one Anthropic Adapter behind the
  Gateway before considering another provider.
- Add Orchestrator policy ahead of execution without allowing the Product API
  to name the adapter.
- Record classification and generation as separate attempts correlated to one
  logical request.
- Preserve the deterministic filter and legality engines as authoritative.
- After parity and cutover approval, remove or disable the direct path; it must
  not remain as a hidden fallback.

### Legacy direct OpenAI embeddings

- Capture document/chunk provenance, batching, normalization, model revision,
  dimension, and the current zero-vector failure behavior as explicit
  compatibility evidence.
- Route embedding requests through the Orchestrator, Gateway, and an
  embedding-capable Adapter.
- The target treats provider failure as unavailable, not as a successful
  placeholder vector. Because that intentionally corrects legacy behavior, it
  requires an explicit safety/compatibility approval gate and validation
  rather than being mislabeled as unchanged behavior.
- Do not mix vectors created by incompatible model revisions or dimensions.
- A new provider/model requires a separately versioned index or a controlled
  full re-embedding, validation, cutover, and rollback boundary.
- Knowledge document/version authority remains outside the vector index.

### Legacy hardcoded prompts

- Capture each prompt body exactly as an immutable draft version with semantic
  family, feature/task, variable contract, output contract, model capability,
  generation settings, source hash, and current behavior evidence.
- Separate dynamic deterministic facts, such as current legality values, into
  typed governed variables rather than freezing values into the asset.
- Validate and approve the captured version before it becomes active.
- Migrate activation before any A/B test, provider optimization, or prompt
  rewrite.
- After parity acceptance and legacy decommission, rollback uses only a prior
  approved Registry version; embedded prompt fallback is forbidden. Before
  acceptance, a whole-request rollback may restore the selected legacy path,
  including its embedded prompt, without mixing it into a target execution.

### Legacy usage counters

- Preserve current counters and their user-visible compatibility behavior
  until an explicit owner-approved change.
- Do not infer provider attempts, tokens, cost, credit balance, or opening
  ledger history from a request counter.
- During advisory observation, write correlated target request/attempt/usage
  facts without making them charging authorities.
- Compare counter and target event coverage to expose, not conceal, differences
  across classification, generation, knowledge, search, and embedding paths.
- Before paid launch, migrate billable features to immutable usage, budget,
  reservation, reconciliation, and credit semantics; legacy counters may
  remain rate/compatibility controls only if explicitly defined.

### Legacy subscription compatibility

- Firebase Auth, claim-based authorization, current Free/Pro scaffolding,
  service-token behavior, and subscriptions-disabled Free launch remain
  unchanged through initial migration.
- Entitlements are provider-neutral capability decisions derived from approved
  commercial state; they do not use provider tokens or provider names.
- A feature flag cannot grant a capability absent entitlement, and a legacy
  counter cannot grant a subscription.
- Migration does not promise unlimited AI and does not create new customer
  pricing.
- Credit enforcement begins only after Milestone 3 paid-launch requirements
  and separate commercial approval.

## Shadow and advisory mode

Shadow execution is not automatically approved. When explicitly approved:

- Prefer offline replay or captured non-sensitive evaluation fixtures over a
  second live provider call.
- A live shadow call receives its own attempt ID, internal budget,
  ProviderUsageFact, cost estimate/reconciliation, safety policy, data-policy
  approval, and immutable audit classification.
- Shadow output cannot affect the user response, product state, tool execution,
  entitlement, deterministic verdict, feature flag, credit balance, or route.
- Shadow traffic is non-billable to the user and cannot increment a second
  legacy request counter or credit charge.
- Sensitive data may be sent only when the target provider/region/purpose has
  separately passed the same authorization as user-serving traffic.
- Comparison stores redacted metrics and approved evaluation evidence, not raw
  production payloads by default.
- A shadow result is evidence, never an automatic cutover decision.

## Feature-flagged cutover

- The rollout flag is server-authoritative, typed, environment-scoped,
  auditable, and evaluated before execution.
- Assignment is stable for the required compatibility window and records
  feature, policy, and cohort decision references without exposing provider
  details.
- Critical flag or kill-switch uncertainty denies the target provider
  execution.
- The owner-approved compatibility policy may keep the whole request on the
  legacy path while that legacy path remains enabled; it cannot switch there
  after an ambiguous target attempt.
- Rollout expands only after the previous cohort meets contract, safety,
  reliability, usage, cost, and rollback gates.
- Client hints never select or bypass the authoritative path.

## Dual-read and dual-write constraints

### Dual reads

- Permitted for comparison only when one source is declared authoritative.
- Differences are recorded as evidence and do not result in per-field merging.
- Safety, entitlement, prompt, route, or balance uncertainty uses the safer
  outcome.
- Target and legacy results must not both trigger provider or business
  side effects.

### Dual writes

- Permitted temporarily only for explicit projections or observational facts.
- Each write has a stable idempotency key, correlation, and declared source of
  truth.
- Failure of a non-authoritative comparison write cannot promote it to
  authority.
- Legacy counter plus target observational ledger is not a double-entry
  transaction and cannot be represented as one.
- Paid credit enforcement cannot have two mutable balance authorities.
- An outbox or later queue may deliver derived events, but it never becomes the
  ledger or policy authority.

## Compatibility guarantees

Until a separately approved breaking change:

- Flutter and existing callers retain the accepted FastAPI Product API
  boundary.
- Firebase identity, account approval, custom claims, and trusted
  service-token identity remain enforced.
- Current deterministic legality, fatigue, filter, roster, bid, and trade
  authorities remain unchanged.
- Product responses do not expose provider/model identity, native tokens,
  provider quotas, or provider pricing in the approved target. The current
  status endpoint is an unresolved legacy exception and no new target surface
  may repeat it.
- Current Free/Pro and subscriptions-disabled behavior remains intact.
- Legacy counter semantics remain intact unless a named migration gate changes
  them.
- The zero-knowledge roster credential model remains intact.
- Provider outage or rollback does not alter deterministic aviation rules.
- Each migrated capability can be disabled without disabling independent
  deterministic product behavior.
- Historical audit, safety, usage, ledger, and migration evidence survives
  deployment rollback.

Because current API documents and executable behavior are not fully aligned,
the exact canonical wire contract is an unresolved prerequisite, not something
Milestone 4 chooses.

## Fallback and rollback strategy

### Provider fallback

- Only the Orchestrator selects an approved alternate route.
- The alternate must meet capability, safety, grounding, data-region, provider
  approval, deadline, budget, prompt, output-contract, and incident policy.
- A Provider Adapter never invokes another provider.
- A Product API never names or selects the alternate.
- If no compatible route exists, return controlled unavailable, abstained, or
  deterministic-only behavior.

### Prompt fallback

- A suspended or failed prompt may fall back only to a prior separately
  approved immutable Prompt Registry version compatible with the task,
  variables, model capability, safety, and output contract.
- Before a prompt family is migrated, its embedded prompt is legacy
  compatibility behavior.
- After migration acceptance, the embedded prompt cannot silently reappear.

### Ledger fallback

- In non-billable observational alpha, a target ledger-observation failure may
  preserve accepted legacy product behavior only under explicit policy, while
  recording or recovering an operational discrepancy without charging.
- Once paid credit enforcement begins, legacy counters cannot substitute for
  reservation, immutable ledger, or reconciliation.
- A provider-success/accounting-write failure preserves pending recovery and
  idempotency evidence; it must not repeat provider execution or fabricate a
  final charge.
- Exact durable recovery requires later design approval.

### Entitlement and credit fallback

- An entitlement lookup failure or conflict cannot grant access.
- Credit or Budget Controller uncertainty cannot bypass safety, entitlement,
  feature, or incident policy.
- Emergency credits or admin overrides follow Milestone 3 audit and scope
  requirements and do not bypass safety or kill switches.
- Current Free/Pro compatibility remains the authority until credit
  enforcement is explicitly activated.

### Legacy fallback

- The direct legacy path is a temporary whole-request compatibility route
  while explicitly enabled and selected before execution.
- A target internal-alpha cohort uses the AI Platform path exclusively for its
  admitted capability. A separately approved non-cohort compatibility path may
  remain legacy until parity; reactivating legacy for an alpha cohort removes
  that capability from target-alpha evaluation.
- It is not a target fallback route and cannot be extended to new providers or
  capabilities.
- After parity acceptance and decommission, legacy fallback is disabled.
- If disabled and the target path is unavailable, return the controlled product
  response; do not resurrect direct provider access.

### Deployment rollback

- Stop or freeze new affected target requests using a server kill switch.
- Determine whether in-flight attempts may have executed before retrying or
  rerouting.
- Restore only an approved prior application revision, active registry/prompt
  pointer, or rollout state through existing deployment governance.
- Preserve all target decisions, attempts, provider usage, ledger, audit,
  safety, incident, flag, and migration evidence.
- Do not reverse an immutable data migration destructively; issue a
  compensating migration or restore an approved read pointer.
- Validate authentication, deterministic behavior, Product API contract,
  counter compatibility, and incident state after rollback.
- Recovery or re-cutover requires a new owner-approved gate.

## Data migration strategy

This is conceptual only:

- Use forward-only, numbered, checksummed, idempotent migrations with
  environment and deployment-revision evidence.
- Dry-run and validate in non-production before gated production execution.
- Use deterministic target IDs and resumable bounded batches.
- Backfill immutable revisions or evidence without rewriting current legacy
  facts.
- Record schema version, source identity, source hash, migration marker,
  validation result, and rollback-window reference.
- Shadow-read a new representation where useful, with one declared authority.
- Retain the old representation during the approved rollback window.
- Correct mistakes with a new compensating migration.
- Do not migrate legacy counters into opening credit balances without explicit
  owner-approved policy.
- Do not copy transcript history into governed memory or raw content into
  telemetry by default.
- Embedding model changes require a compatible separate index or complete
  controlled re-embedding; incompatible dimensions do not share an index.

No exact migration, marker schema, batch size, retention time, or database
transition is approved here.

## Provider expansion strategy

GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, and future providers are eligible
adapter targets only after:

- The normalized Gateway and Adapter contracts are stable.
- An adapter passes capability, structured-output, timeout, usage, error,
  idempotency, safety-signal, and redaction conformance.
- Provider/model Registry revisions and route policy are approved.
- Data use, region, retention, training, security, secret, and incident
  requirements are approved.
- Feature-specific quality, grounding, deterministic consistency, latency,
  availability, and internal cost benchmarks meet owner-approved thresholds.
- Prompt/model compatibility is evaluated using an approved Prompt Registry
  version.
- Server-side kill switches and rollback are tested.
- Budget, ProviderUsageFact, cost, and ledger observation are complete.

Provider expansion never changes a customer quota or exposes provider identity.
No provider is implicitly preferred by its order in this document.

## Validation and owner approval gates

A later migration cannot advance a capability without evidence for:

- Canonical external request, response, authentication, and error contract.
- Deterministic engine and governed-source parity.
- Prompt, model, generation setting, and dynamic-variable provenance.
- Structured-output and tool-contract validation.
- Safety classification, injection, grounding, refusal, and deterministic-only
  behavior.
- Provider output, malformed result, timeout, rate-limit, outage, and unknown
  execution handling.
- Redacted observability, audit, usage, cost, and idempotency coverage.
- Legacy counter and subscription compatibility.
- Performance and internal cost within approved bounds.
- Shadow isolation and non-billable classification where used.
- Server flag, kill switch, rollback execution, and post-rollback validation.
- Owner approval of parity, cohort expansion, decommission, and paid
  enforcement as separate decisions.

Live-model evaluation and production traffic are not authorized by this
document.

## Failure and fallback semantics

| Condition | Required migration behavior |
|---|---|
| Canonical compatibility contract unresolved | Do not approve shadow or cutover for the affected capability |
| Safety policy unavailable | Do not execute the target provider path; retain independent deterministic behavior |
| Firestore target configuration unavailable | Target path fails closed; a whole request may use legacy only if selected before execution by an explicit still-active compatibility policy |
| RAG unavailable or governed source missing | Do not use model memory as a substitute; abstain, unavailable, or deterministic-only |
| Memory unavailable | Continue without it only when optional and compatibility policy allows |
| Cache unavailable | Treat as a miss; do not change authority |
| Tool denied or timed out | Preserve controlled error and unknown-effect/idempotency state; never fall through to provider-selected action |
| Provider outage | Orchestrator-approved adapter fallback only; otherwise controlled unavailable/deterministic-only |
| Model or prompt suspended | Resolve only an approved compatible version; otherwise disable the target capability |
| Unsafe or malformed provider output | Reject it and record target evidence; do not serve it for parity |
| Prompt injection detected | Enforce safety outcome; never use legacy routing to bypass the detection |
| Safety incident active | Kill-switch response dominates rollout assignment |
| Observability write failure | Do not log raw payloads; apply approved controlled degradation |
| Mandatory audit write failure before target execution | Fail closed |
| Audit/ledger write failure after possible provider success | Preserve pending recovery/idempotency; do not re-execute through target or legacy |
| Fallback route unavailable | Return controlled unavailable, abstained, or deterministic-only |
| Legacy fallback disabled | Do not reactivate it; no direct provider call |
| Rollback requested | Stop affected new target execution, preserve evidence, restore only an approved prior pointer/revision/path, and validate |

## Architectural decisions

### AI-MG-001 — Migration is wrapper-first, behavior-preserving, and feature-flagged

- **Decision:** Introduce provider-neutral seams around all current execution
  families, preserve accepted behavior, and move cohorts through audited
  server-side flags.
- **Rationale:** Provider abstraction must not silently change product,
  deterministic, authentication, subscription, or failure behavior.
- **Alternatives considered:** Big-bang replacement; rewrite and provider switch
  together; client-selected rollout.
- **Accepted trade-offs:** Temporary compatibility layers and duplicated
  observation increase short-term complexity.
- **Security impact:** Central seams allow policy, redaction, authorization, and
  kill switches before broad cutover.
- **Cost impact:** Parallel observation and approved shadow calls add temporary
  internal cost; bounded flags limit exposure.
- **Scalability impact:** Normalized contracts prevent per-feature/provider
  integrations from multiplying.
- **Migration impact:** Each capability requires its own parity and owner gate;
  no new direct calls may be added.
- **Implementation priority:** Must implement before internal alpha.

### AI-MG-002 — Existing direct provider paths are legacy fallback only until parity is proven

- **Decision:** Current direct paths may remain temporary whole-request
  compatibility routes, selected before execution, and must be disabled after
  migration acceptance.
- **Rationale:** Backward compatibility needs a bounded rollback path while the
  target forbids permanent business-module provider access.
- **Alternatives considered:** Immediate deletion; indefinite hidden fallback;
  mid-request fallback after target uncertainty.
- **Accepted trade-offs:** Two internal paths exist temporarily and require
  explicit ownership, flags, evidence, and decommission criteria.
- **Security impact:** Prevents direct paths from bypassing target safety and
  incident controls after cutover.
- **Cost impact:** Temporary maintenance cost is accepted; duplicate user
  charging and uncontrolled double execution are forbidden.
- **Scalability impact:** Legacy paths are not extended to new capabilities or
  providers.
- **Migration impact:** Rollback is whole-request and time-bounded; ambiguous
  target execution never falls through to legacy.
- **Implementation priority:** Define before internal alpha; use the Platform
  exclusively for each target-alpha cohort during its evaluation; remove the
  legacy path for each billable feature before paid launch.

### AI-MG-003 — Prompt migration happens before prompt experimentation

- **Decision:** Capture, version, validate, and approve current prompts and
  dynamic variable contracts before testing variants or providers.
- **Rationale:** Otherwise a provider migration and prompt change cannot be
  distinguished or rolled back reliably.
- **Alternatives considered:** Rewrite prompts during adapter work; keep code
  prompts indefinitely; provider-native prompt management.
- **Accepted trade-offs:** Initial target behavior retains legacy prompt
  limitations until separately improved.
- **Security impact:** Creates review, injection boundaries, integrity hashes,
  and controlled rollback.
- **Cost impact:** Requires asset/evaluation work before optimization; prevents
  unmeasured prompt-driven spend changes.
- **Scalability impact:** Prompt families and typed variables support
  provider-neutral reuse and systematic evaluation.
- **Migration impact:** Dynamic deterministic values remain governed inputs and
  embedded fallback is removed after acceptance.
- **Implementation priority:** Must implement before internal-alpha
  user-serving migration of each prompt-backed feature.

### AI-MG-004 — Ledger observation precedes credit enforcement

- **Decision:** Record immutable non-billable/advisory request, attempt, usage,
  cost, and budget facts before enforcing reservations or NAJM AI Credit burn.
- **Rationale:** Coverage, retries, multi-attempt requests, failures, and cost
  reconciliation must be proven before customer balances can be affected.
- **Alternatives considered:** Charge from legacy request counters; activate
  credits at first adapter cutover; use provider invoices alone.
- **Accepted trade-offs:** Internal alpha carries accounting overhead without
  customer charging.
- **Security impact:** Idempotency and audit coverage can be validated before
  financial effects are enabled.
- **Cost impact:** Adds event storage and reconciliation work; reduces future
  leakage, double charge, and dispute risk.
- **Scalability impact:** Establishes correlation and event shape before paid
  volume.
- **Migration impact:** Legacy counters remain compatibility mechanisms and are
  not opening ledger history.
- **Implementation priority:** Must implement for internal alpha observation;
  enforcement before paid launch only.

### AI-MG-005 — Provider expansion happens only after Gateway, adapters, and benchmarks

- **Decision:** GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, and future
  providers enter only through a conforming Adapter, approved registries, and
  feature-specific benchmark gates.
- **Rationale:** Provider count must not outrun safety, data, cost, quality, or
  operational governance.
- **Alternatives considered:** Business modules integrate providers directly;
  enable every provider at platform launch; route solely by price.
- **Accepted trade-offs:** Some providers remain unavailable until evidence and
  approval exist.
- **Security impact:** Centralizes secrets, data handling, incident suspension,
  and output validation.
- **Cost impact:** Benchmarking has bounded cost and prevents unvalidated route
  economics.
- **Scalability impact:** A common adapter contract supports future providers
  without multiplying product dependencies.
- **Migration impact:** First prove current-provider parity, then approve
  expansion separately; no implicit default provider is chosen.
- **Implementation priority:** Deferred until the first Gateway/Adapter path
  and benchmarks are approved; any provider used for paid launch must pass
  before activation.

### AI-MG-006 — Rollback never deletes historical audit or ledger evidence

- **Decision:** Deployment, pointer, prompt, provider, model, feature, and data
  rollback preserve all immutable target decisions, attempts, usage, safety,
  incident, audit, credit, and migration evidence.
- **Rationale:** Operational recovery cannot erase what executed or alter
  accounting and investigation facts.
- **Alternatives considered:** Restore a database snapshot as the sole
  rollback; delete failed-rollout events; mutate charges or prompt history.
- **Accepted trade-offs:** Rollback restores behavior without returning storage
  to an artificial pre-event state.
- **Security impact:** Preserves accountability and incident evidence.
- **Cost impact:** Retained history consumes storage but supports disputes,
  reconciliation, and recovery.
- **Scalability impact:** Immutable event storage and retention policy must
  accommodate rollout history.
- **Migration impact:** Corrections use linked events and compensating
  migrations; re-cutover is a new approved change.
- **Implementation priority:** Must implement before internal alpha and remain
  binding through paid launch.

## Security considerations

- Migration never moves provider secrets into clients, Product APIs, domain
  engines, Firestore config records, prompts, logs, or tests.
- Adapter-scoped secret access replaces, rather than duplicates, provider
  access after cutover.
- Firebase and service-token identity remain server-verified and are not
  inferred from model or client fields.
- Shadow traffic uses the same data-class, region, consent, RAG, tool, and
  safety controls as user-serving traffic.
- Zero-knowledge roster credentials never enter compatibility capture,
  prompts, evaluation fixtures, logs, queues, or provider calls.
- Rollout and rollback commands require least privilege, idempotency, reason,
  scope, and append-only audit.
- Direct legacy paths must not bypass a global safety incident while they
  coexist; the exact compatibility control must be approved before use.

## Cost considerations

- Baseline provider attempts must be counted accurately, including classifier,
  extractor, generation, knowledge, and embedding calls.
- Shadow calls are internally budgeted and non-billable to users.
- Provider-native usage and cost remain internal facts separate from NAJM AI
  Credits.
- Parity gates include cost per accepted task and failure/retry behavior, not
  just list price.
- Migration does not approve exact provider prices, customer prices, burn
  rates, quotas, or unlimited AI.
- Budget or cost rollback never weakens safety, entitlement, or deterministic
  authority.

## Scalability considerations

- Migrate by capability, with stable normalized contracts, rather than by
  scattered call site.
- Correlation and idempotency must cover multi-attempt logical requests.
- Rollout assignment, critical flags, and kill switches must be consistent
  across instances.
- Incompatible embedding spaces require versioned indexes and controlled
  reprocessing.
- Deferred stores and asynchronous infrastructure are introduced only at the
  scale triggers defined in AI_DATA_MODEL_PROPOSALS.md.
- Multi-region active-active migration is deferred until consistency,
  residency, and incident behavior are approved.

## Migration considerations

- No behavior changes occur in Phase 1.
- The exact canonical API contract, parity tolerances, first capability,
  provider/model route, rollout cohorts, and legacy decommission window remain
  owner decisions.
- Current contract discrepancies are pre-existing and must be resolved or
  explicitly accepted for the selected capability before cutover measurement.
- Existing deployment and rollback documentation remains current operational
  context.
- A separately approved implementation must verify actual deployed behavior;
  documentation alone is not parity evidence.
- This strategy preserves compatibility but does not authorize indefinite
  legacy debt.

## Delivery classification

### Must implement before internal alpha

- Canonical compatibility contract for each alpha capability.
- Wrapper-first seams for NLP generation, knowledge generation, and embeddings
  in the selected alpha scope.
- Normalized request, response, error, attempt, usage, and idempotency
  contracts.
- Captured and approved legacy prompt/model/config versions.
- AI Orchestrator safety classification, deterministic-only behavior, and
  server-authoritative kill switches.
- One conforming Gateway/Adapter path for each enabled execution capability.
- Redacted observability and append-only non-billable/advisory ledger
  observation.
- Server-side rollout and whole-request rollback behavior.
- Platform-exclusive execution for each target internal-alpha cohort; any
  still-enabled legacy path remains outside that cohort.
- Conceptual data model and idempotent migration evidence.

### Must implement before paid launch

- Tested incident and rollback procedures with owner-approved gates.
- Governed prompt/model/provider suspension.
- Audit-grade event retention and recovery.
- Migration away from direct provider calls for every billable feature.
- Enforced ledger, Budget Controller, reservation, reconciliation, credit, and
  observability integration.
- Admin-reviewed safety, incident, credit, and rollout controls.
- Proven contract, safety, reliability, cost, usage, idempotency, and dispute
  evidence.
- Removal of hidden embedded prompt and direct provider fallbacks for migrated
  billable capabilities.

### Deferred until scale justifies it

- Independent SIEM integration.
- Advanced experimentation platform.
- Dedicated Vector DB.
- PostgreSQL ledger migration.
- BigQuery analytics export.
- Redis distributed cache and rate limiter.
- Pub/Sub event lake.
- Cloud Tasks workflow infrastructure.
- Fully automated enterprise chargeback.
- Multi-region active-active AI Platform.
- Automated cross-provider real-time cost optimization.

## Open questions

- Which runtime-verified Product API contract is canonical for each legacy
  capability, and which documented discrepancies require correction?
- How will provider/model fields on the legacy AI status surface be removed,
  internalized, or versioned without an unapproved compatibility break?
- What exact behavioral, safety, output, latency, availability, and cost
  tolerances constitute parity?
- Which capability is approved for the first internal-alpha migration?
- Which existing prompt/model/settings snapshot becomes the initial approved
  compatibility asset for each path?
- Which first provider/model route, region, data handling, and fallback set are
  approved?
- Is any live shadow traffic approved, or is evaluation limited to offline
  replay and fixtures?
- What rollout cohort rules, dwell periods, success thresholds, and automatic
  stop conditions apply?
- How long may a legacy path remain enabled after target parity, and who
  approves decommission?
- How must a global target kill switch constrain the still-present legacy path
  during coexistence?
- What exact legacy counter behavior must remain user-visible during alpha?
- What approved messaging replaces or explicitly governs the legacy
  unsupported unlimited-Pro statement?
- What policy, if any, establishes opening credit balances; counters cannot
  decide it?
- What durable recovery mechanism is approved for provider success followed by
  audit or ledger persistence failure?
- What embedding re-index and rollback approach is approved for model or
  dimension change?
- Which approval gate accepts the intentional change from zero-vector embedding
  fallback to target unavailable behavior?
- Which migration and recovery actions require dual control?

These questions are explicitly unresolved. Milestone 4 does not authorize an
implementation team to decide them or start runtime work.

## References

- AI_PLATFORM_OVERVIEW.md
- AI_ORCHESTRATOR.md
- AI_GATEWAY_AND_PROVIDER_ADAPTERS.md
- AI_REGISTRIES.md
- PROMPT_REGISTRY.md
- AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md
- AI_CREDITS_LEDGER_AND_BILLING.md
- AI_SAFETY_OBSERVABILITY_AND_INCIDENTS.md
- AI_DATA_MODEL_PROPOSALS.md
- NAJM_ARCHITECTURE.md
- docs/ARCHITECTURE_LOCK.md
- docs/SECRETS.md
- docs/devops-runbook.md
- docs/openapi.yaml, current compatibility evidence only
- docs/api-contract.yaml, current compatibility evidence only
- docs/ROSTER_SYNC.md
- docs/ZERO_KNOWLEDGE_CREDENTIALS.md
- reports/SECURITY_REPORT.md
- reports/ARCHITECTURE_REPORT.md
- reports/RELEASE_READINESS.md
- python_services/ai/nlp_router.py, current-state evidence only
- python_services/knowledge_engine/ai_assistant.py, current-state evidence only
- python_services/knowledge_engine/embeddings.py, current-state evidence only
- python_services/legality/engine.py, current-state evidence only
- python_services/legality/rules_source.py, current-state evidence only
- python_services/utils/auth.py, current-state evidence only
- firebase/functions/src/index.ts, current-state evidence only
- .env.example, current-state evidence only
