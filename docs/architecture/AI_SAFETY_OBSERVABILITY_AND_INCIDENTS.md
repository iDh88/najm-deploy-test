# NAJM AI Platform — Safety, Observability, and Incident Architecture

**Status:** Approved for Phase 1 documentation, not yet implemented

**Phase:** Phase 1 — Architecture Documentation, Milestone 4

**Document role:** Authoritative target-state safety and incident architecture

**Last reconciled:** 2026-07-16

## Purpose

This document defines the safety, observability, and incident-control
boundaries for the provider-independent NAJM AI Platform. It specifies how the
future AI Orchestrator must protect aviation-sensitive work, how AI execution
must be observed without exposing sensitive data, and how server-authoritative
incident controls must stop or degrade AI safely.

This is architecture documentation only. It does not change current executable
behavior, authorize runtime work, or represent the target controls as already
implemented.

## Scope

This document defines:

- Aviation-sensitivity classification and deterministic-engine authority.
- Safety policy levels and allowed response modes.
- Prompt-injection, RAG, tool, memory, and cache boundaries.
- Refusal, degraded, deterministic-only, unavailable, and escalation
  semantics.
- Redacted request, execution, safety, and accounting observability.
- Global and scoped AI incident kill switches.
- Provider, model, prompt, cost, and data-leak incident handling.
- Append-only safety and incident evidence.
- Retention and redaction principles without selecting exact periods.
- Internal-alpha, paid-launch, and scale-deferred requirements.

## Non-goals

This document does not:

- Implement a Safety Layer, logger, kill switch, alert, data store, or runbook.
- Replace or weaken deterministic legality, fatigue, roster, trade, bid,
  subscription, authentication, authorization, or accounting systems.
- Approve exact safety thresholds, prompt policies, incident severities,
  response-time commitments, retention periods, or provider routes.
- Authorize an AI model to make an aviation legality decision or consequential
  business commit.
- Authorize raw prompt, model-output, retrieved-content, roster, credential, or
  token logging.
- Change current direct Anthropic or OpenAI calls, embedded prompts, or daily
  usage counters.
- Supersede the current deployment and rollback runbooks.
- Begin Milestone 5 or any runtime implementation phase.

## Current legacy state

The repository currently has direct Anthropic calls in the general AI
assistant and Knowledge Engine assistant, direct OpenAI calls for embeddings,
and prompt bodies and model names embedded in runtime modules. The current
assistant uses limited text replacement as an input sanitation measure; this
is not the approved target prompt-injection boundary. Some current logs contain
a user reference and a message prefix, and provider exception details may be
logged. Those are legacy migration items, not approved target observability.

The Knowledge Engine currently retrieves governed document chunks and provides
source metadata, but generated answers and citations do not constitute
claim-level proof. An embedding failure currently may return placeholder
vectors; the target architecture must treat embedding failure as unavailable
or insufficient grounding, never as successful retrieval.

Cloud Functions currently authenticate callers, enforce legacy daily counters,
and delegate AI chat to FastAPI. Stored AI session messages and caller-supplied
conversation history are current transcript behavior, not the approved target
Memory Layer.

The deterministic legality engine and configured legality-rule source remain
the executable authority for legality facts. The repository also records a
pre-existing owner-confirmation dependency for canonical numeric rules and the
FDP model. Milestone 4 neither resolves nor changes that dependency.

Firebase Auth, approval claims, the Functions-to-FastAPI service-token
boundary, current Free/Pro and subscriptions-disabled behavior, zero-knowledge
roster credentials, and existing deployment procedures remain unchanged.

No target Safety Layer, governed memory, normalized AI telemetry, or complete
AI-specific kill-switch system should be inferred to exist today.

## Approved target state

All AI-enabled product work follows:

    Flutter or authorized service caller
      -> FastAPI Product API
      -> AI Orchestrator
          -> safety, incident, entitlement, budget, context, and tool policy
          -> AI Gateway
          -> one Provider Adapter per execution attempt
          -> external provider

The AI Orchestrator owns the final NAJM safety decision. The AI Gateway reports
normalized provider and validation facts. A Provider Adapter is the only layer
that may call a provider API or SDK. Provider moderation signals inform, but
never replace, NAJM safety policy.

For aviation-sensitive work, deterministic domain authorities and governed
operational sources outrank prompts, retrieved text, memory, tool arguments,
provider output, and model memory. AI may explain, summarize, classify,
retrieve, or assist. It must not originate, override, loosen, or conceal a
deterministic aviation verdict.

## Source-of-truth hierarchy

### Architecture authority

1. The latest explicit, scoped owner decision.
2. The NAJM Master Project Directive.
3. The Architecture Lock.
4. Approved Phase 1 AI architecture documents.

### Safety and operational fact authority

1. Authenticated identity, authorization, and server-derived actor context.
2. Deterministic aviation engines and their versioned governed rule sources.
3. Governed operational sources, including active Knowledge Engine documents
   and their provenance.
4. Implemented, approved feature, entitlement, safety, incident, budget,
   registry, prompt, RAG, memory, cache, and tool policies.
5. Immutable decisions, attempts, safety events, audit events, and usage facts.
6. Derived views, caches, health summaries, and analytics.
7. Model output and provider-native safety signals.

Anything supplied by a user, model, provider, retrieved document, memory entry,
or tool argument is untrusted until its governing boundary validates it.

## Component responsibilities

### FastAPI Product APIs

- Authenticate the caller and preserve the user or trusted service identity.
- Own the product contract and deterministic business transaction.
- Invoke deterministic services directly where AI is unnecessary.
- Submit provider-neutral AI tasks only to the AI Orchestrator.
- Present controlled refusal, abstention, deterministic-only, degraded, or
  unavailable responses without revealing provider identity.
- Never select a provider, model, prompt version, or safety bypass.

### AI Orchestrator and Safety Layer

- Classify task aviation sensitivity before provider execution.
- Resolve the active safety and incident policies and record their versions.
- Enforce deny-dominant feature, entitlement, budget, credit, safety, and kill
  switch outcomes.
- Decide whether RAG is required, which governed sources qualify, whether
  memory or cache is permitted, and which tools may be proposed.
- Validate context sufficiency before execution and output acceptability after
  execution.
- Decide semantic fallback, retry eligibility, deterministic-only handling,
  refusal, abstention, unavailability, or escalation.
- Correlate safety, attempt, audit, budget, usage, and ledger evidence.
- Never call a provider directly or change deterministic domain facts.

### AI Gateway

- Validate the normalized execution envelope.
- Execute only the route and bounded retry instruction selected by the
  Orchestrator.
- Normalize result, malformed-output, content-block, timeout, rate-limit,
  usage, and provider-safety facts.
- Emit an attempt reference and redacted execution telemetry.
- Never decide aviation safety, entitlement, customer credit burn, product
  behavior, or cross-route fallback.

### Provider Adapters

- Hold adapter-scoped server-side access to one provider.
- Translate normalized requests and responses without embedding product or
  aviation policy.
- Redact provider errors before they cross the adapter boundary.
- Return native usage and provider safety facts for reconciliation.
- Never persist provider secrets, make product decisions, or call another
  adapter.

### Deterministic domain engines

- Remain authoritative for legality, fatigue, and other deterministic
  aviation decisions within their declared scope.
- Return versioned results and provenance suitable for explanation and audit.
- Never accept model-generated thresholds as authoritative configuration.
- Never call the AI Gateway, an adapter, or a provider.

### Knowledge Engine and RAG boundary

- Own governed document ingestion, activation, versioning, chunk provenance,
  retrieval facts, and source metadata.
- Return candidate evidence; it does not authorize provider execution.
- Keep source authority separate from model-generated synthesis.
- Route any future embedding generation through the Orchestrator, Gateway, and
  an embedding-capable Provider Adapter.

### Tool implementations

- Execute only deterministic services or governed data operations within a
  typed, authorized, capability-scoped contract.
- Treat model-proposed arguments as untrusted.
- Return provenance and a normalized result.
- Never call providers or grant authorization.

### Memory and cache layers

- Supply optional, policy-governed context only.
- Never become sources of authorization, entitlement, credit balance,
  registry configuration, aviation truth, or incident state.
- Enforce identity, tenant, purpose, version, freshness, and data-class
  boundaries.

### Observability and incident control plane

- Correlate decisions and attempts without storing prohibited content.
- Maintain server-authoritative kill-switch state and append-only change
  evidence.
- Produce health and incident facts; it does not independently choose product
  fallback.
- Restrict administrative actions to authenticated, least-privilege server
  APIs.

## Required boundaries

### Aviation-sensitive AI classification

Every AI task must be classified before context assembly or provider
execution. The classification is a policy fact, not a model preference.
Conceptually, the target safety levels are:

| Level | Meaning | Permitted target behavior |
|---|---|---|
| General assistance | No aviation, operational, authorization, or financial consequence | Governed generation subject to ordinary safety and privacy controls |
| Grounded operational information | Answer depends on approved operational knowledge | RAG is mandatory; source attribution and sufficiency checks apply |
| Aviation-sensitive advisory | Output may influence legality, fatigue, roster, bid, trade, or flight-duty judgment | Deterministic-first; AI may explain or summarize a versioned deterministic result and governed sources |
| Deterministic-exclusive | Correctness cannot safely depend on generative interpretation | No provider execution unless an approved explanation-only policy exists; deterministic result is the user-facing authority |

The exact serialized taxonomy, feature mapping, thresholds, and approval roles
remain open. A missing or indeterminate classification must use the safer
applicable class and must not silently default to general assistance.

### Deterministic-engine authority

- Deterministic results and governed rule provenance must be obtained before
  an aviation-sensitive explanation when the task requires them.
- An AI explanation must preserve the verdict, warnings, rule version, and
  what-if status supplied by the deterministic engine.
- A model may not insert, choose, or revise regulatory thresholds.
- A caller-supplied what-if rule set must remain clearly labeled as what-if and
  must not be presented as the official verdict.
- If deterministic authority is unavailable, the system returns
  deterministic-only unavailable, UNKNOWN, abstained, or refused according to
  product policy. It must not ask a model to reconstruct the answer.

### Prompt-injection boundary

- System policy, safety policy, identity, authorization, entitlement, budget,
  incident controls, route policy, and tool contracts are outside model
  control.
- User text, retrieved documents, memory, cached content, tool output, and
  provider output are untrusted data even when they contain instruction-like
  text.
- Retrieved instructions cannot change tool permissions, reveal prompts or
  secrets, select a provider, or override higher-trust instructions.
- Context must be structurally separated by provenance and data class.
- Tool names and arguments must be validated against server-owned schemas.
- AI or tool output cannot grant permissions or modify entitlements, credits,
  Provider/Model/Prompt Registry assets, feature flags, safety policies, or
  incident controls.
- Detected injection attempts produce a reason-coded safety event and the
  policy-defined refusal, context exclusion, or escalation outcome.
- String filtering alone is not an acceptable target control.

### RAG safety boundary

- The Orchestrator decides when grounding is mandatory and selects only
  approved corpora, active document versions, filters, freshness policy, and
  citation requirements.
- The Knowledge Engine remains authoritative for document/version metadata.
- Retrieved text cannot override deterministic rules or platform policy.
- Retrieval results must carry source, version, chunk, score, and activation
  provenance sufficient for later review.
- Aviation-sensitive output must abstain when required governed evidence is
  missing, stale, unauthorized, or insufficient.
- Source citations demonstrate provenance; they do not by themselves prove
  that every generated claim is supported.
- Embedding or retrieval failures are explicit failures, not fabricated
  vectors or empty-success responses.
- Exact source taxonomy, freshness, sufficiency, and claim-validation
  thresholds remain owner-approved implementation inputs.

### Tool-calling safety boundary

- Tools are registered capabilities, not arbitrary functions selected by a
  provider.
- The Orchestrator authorizes each proposed tool call against actor, tenant,
  feature, entitlement, safety class, incident state, purpose, and limits.
- The model proposes; the platform validates and decides; the tool executes.
- Inputs and outputs are typed, size-bounded, deadline-bounded, and
  provenance-stamped.
- Tools may read deterministic or governed data only within their declared
  authorization scope.
- Consequential operations such as bids, trades, subscription changes,
  registry activation, credit changes, or permission grants require the
  existing product transaction and explicit authorization. A model response
  cannot commit them.
- Tools never call providers.

### Memory safety boundary

- Governed memory is optional and future-controlled; current transcript
  storage is not automatically target memory.
- Any memory capability requires identity, tenant, purpose, user consent where
  applicable, allowed data classes, write policy, provenance, retention class,
  deletion behavior, and versioning.
- Provider secrets, service tokens, raw Firebase tokens, payment credentials,
  roster credentials, secret-bearing roster URLs, and other unapproved
  sensitive data are prohibited.
- Memory is contextual evidence, never an authorization, registry, credit,
  aviation, or operational source of truth.
- Cross-user and cross-tenant retrieval is forbidden.
- The model cannot silently create durable memory.
- Exact consent, retention, user controls, and continuity semantics remain
  open and must be approved before durable memory is enabled.

### Cache safety boundary

- Cache reads occur only after authentication and must not bypass feature,
  entitlement, safety, incident, privacy, budget, or audit checks.
- Cache keys must include the authorized scope and every material version:
  feature, task, prompt, model route where relevant, safety policy, source or
  rule version, tenant, locale, and freshness boundary.
- Kill-switch and suspension state must be re-evaluated independently of a
  cached generated response.
- Rule, document, policy, prompt, or authorization changes invalidate
  incompatible entries.
- A missing, expired, incompatible, or unavailable cache is a miss, not
  permission to serve stale content.
- Cache entries are never entitlement, balance, ledger, registry, incident, or
  aviation authorities.
- Exact time-to-live values and whether a cache hit burns credits remain open.

### Administrative and human-review boundary

- Admins operate through authenticated, authorized server APIs; admin clients
  never write sensitive control-plane records directly or receive provider
  secrets.
- Safety policy, prompt, model, provider, and kill-switch changes require a
  reason, actor, scope, version, effective time, and append-only audit event.
- Break-glass changes must be narrower and shorter-lived than routine
  activation and require retrospective review.
- Human review may approve policy or incident recovery; it cannot retroactively
  mutate a historical safety, attempt, usage, or ledger event.
- Exact role separation, dual-control requirements, escalation owners, and
  recovery approvals remain open.

## Required semantics

### Response modes

| Mode | Required meaning |
|---|---|
| Allowed | Policy permits AI output and all required validation succeeds |
| Grounded | Output is accepted only with adequate governed-source evidence and required attribution |
| Deterministic-only | Independent deterministic functionality remains available; no generated conclusion is used |
| Abstained or UNKNOWN | Required authority or evidence is insufficient to state the answer |
| Refused | Policy forbids the task, content, data use, or requested action |
| Degraded | An explicitly approved reduced capability operates without weakening safety or authorization |
| Unavailable | The requested AI capability cannot safely complete and no permitted fallback exists |
| Escalated | A reason-coded case is referred to an authorized human or incident workflow |

These modes are provider-neutral. They must not expose provider names or imply
that a provider outage changes aviation rules.

### Safety event types

The target event taxonomy must distinguish at least:

- Safety classification and policy decision.
- Deterministic-authority or grounding sufficiency failure.
- Prompt-injection detection.
- Tool authorization denial, validation failure, timeout, or prohibited
  consequential action.
- Memory or cache policy rejection and isolation failure.
- Provider content block or provider-native safety signal.
- Unsafe, ungrounded, contradictory, or malformed model output.
- Prompt, model, provider, feature, or global suspension.
- Kill-switch activation, change, recovery approval, and expiration.
- Data handling, redaction, cross-tenant, or suspected leakage incident.

Safety events are immutable facts. Corrections or reclassifications are new,
linked events.

### Observability event types

The target must correlate, without storing raw content by default:

- Logical AI request and Orchestrator decision.
- Gateway attempt, bounded retry, and adapter result.
- Provider/model/prompt/route revision references.
- Feature, entitlement, safety, incident, budget, credit, RAG, memory, cache,
  and tool decision references.
- Deterministic rule, governed document, and tool-result provenance.
- Latency, deadline, retry, normalized failure, and output-contract status.
- Provider-native usage, estimate certainty, reconciliation state, and internal
  cost references.
- Ledger, reservation, transaction, audit, and incident correlation IDs.
- Health transition, circuit state, kill-switch evaluation, and recovery.

### Redaction and minimization

Ordinary telemetry must exclude:

- Provider keys, secret-manager payloads, service tokens, authorization
  headers, cookies, raw Firebase tokens, and deployment credentials.
- Roster PRNs, passwords, session tokens, secret-bearing feed URLs, and other
  zero-knowledge credentials.
- Payment credentials, raw receipts, and billing-provider secrets.
- Raw prompts, provider payloads, retrieved source text, memory contents,
  tool payloads, roster schedules, and model output by default.
- Unredacted provider errors and unnecessary user or organization PII.

Events should use opaque request, actor, tenant, account, source, and version
references. Exceptional content capture, if ever approved, requires a narrow
purpose, separate access, explicit retention class, redaction, encryption,
audit, and owner-approved policy. This document does not approve it.

### Incident kill switches

The target must support a global AI kill switch and scoped switches for:

- Product capability or feature.
- Organization or tenant where authorized.
- Provider, adapter, model, model revision, or route.
- Prompt family or prompt version.
- Safety class or incident policy.
- RAG corpus or source.
- Tool or tool version.
- Memory or cache capability.

Kill switches are server-authoritative and deny/degrade dominant. Missing,
unreadable, expired-without-safe-resolution, or conflicting critical incident
state must not permit provider execution. Client state and caches are display
or acceleration aids only.

Each change requires an actor, reason, scope, prior and new state, effective
time, optional expiry, correlation to an incident, and an append-only audit
event. Emergency credits, admin grants, routing overrides, and provider health
cannot bypass a safety or global incident stop.

### Incident-specific handling

#### Provider incident

- Provider health is evidence supplied to the Orchestrator.
- The Gateway may perform only an approved same-route bounded retry.
- The Orchestrator alone may select a different approved route.
- A global or scoped stop prevents both the affected route and any hidden
  direct-provider fallback.
- If no compatible route exists, return unavailable or deterministic-only.

#### Prompt incident

- Suspend the affected prompt version or family through server-authoritative
  policy.
- Roll back only to a previously approved immutable Prompt Registry version.
- Preserve every affected request and activation reference.
- Do not silently fall back to an embedded runtime prompt after that feature
  has migrated to the Prompt Registry.

#### Model incident

- Suspend the model or revision independently of provider status.
- Re-evaluate feature capability, safety, grounding, data-region, cost, and
  deadline requirements before any alternate route.
- Never expose the model identity to the user as a quota or dependency.

#### Cost incident

- Budget policy or an incident switch may cap, degrade, or stop affected AI
  execution.
- A cost response must not weaken safety, authorization, entitlement,
  deterministic authority, or immutable accounting.
- Usage uncertainty and reconciliation obligations remain recorded even when
  execution is stopped.

#### Data-leak incident

- Stop affected provider, prompt, RAG, memory, cache, tool, or feature scopes.
- Preserve minimal audit and incident evidence without spreading the suspected
  content into additional logs.
- Apply existing authentication, secret-rotation, deployment, legal, and
  privacy procedures.
- Recovery requires explicit authorization and validation that the affected
  data path is contained.

## Proposed records

These are conceptual record groups, not approved Firestore schemas:

- **AISafetyDecision:** classification, policy revision, required authorities,
  outcome, reason codes, validation summary, and request correlation.
- **AISafetyEvent:** append-only event type, scope, severity reference, actor or
  system origin, policy and asset versions, redacted facts, and linked event.
- **AIObservabilityEvent:** redacted request/attempt lifecycle facts, timings,
  normalized outcome, correlation references, and retention class.
- **AIKillSwitchState:** current server-authoritative scoped projection,
  effective/expiry state, governing incident, and last immutable audit event.
- **AIIncident:** incident identity, scope, status projection, affected assets,
  declared response mode, review references, and recovery gate.
- **AIProviderHealthFact:** timestamped provider/adapter/model health evidence,
  certainty, scope, and expiry.
- **AIAdminSafetyAction:** append-only actor, authorization basis, reason,
  before/after references, approval evidence, and incident correlation.

Current projections may change; decision, event, attempt, usage, ledger, and
audit facts are append-only. Collection proposals and field groups are defined
in AI_DATA_MODEL_PROPOSALS.md.

## Failure and fallback semantics

| Condition | Required target behavior |
|---|---|
| Safety policy unavailable | Deny provider execution; preserve independent deterministic behavior; emit or queue required failure evidence |
| RAG retrieval unavailable | If mandatory, abstain or return unavailable/deterministic-only; if optional, omit only under explicit policy |
| Governed knowledge source missing, inactive, stale, or insufficient | Do not answer from model memory; abstain, UNKNOWN, deterministic-only, or unavailable |
| Memory unavailable | Continue without memory only when memory is optional by policy; otherwise unavailable; never cross scopes |
| Cache unavailable | Treat as a miss and use the authoritative path if permitted; never weaken policy |
| Tool call denied | Do not execute; return a controlled refusal or alternate product response and record the reason |
| Tool call timeout | Treat outcome as unknown until the tool contract resolves idempotency; do not repeat a consequential action blindly |
| Provider outage | Use only an Orchestrator-approved compatible route; otherwise unavailable or deterministic-only |
| Model suspended | Route only to a separately approved compatible model; never use an unregistered constant |
| Prompt suspended | Use only an approved prior or alternate Registry version; otherwise disable the capability |
| Provider returns unsafe output | Reject it; do not charge acceptance-dependent credits until accounting policy reconciles the attempt; record the event |
| Provider returns malformed structured output | Validate as failure; bounded repair or retry only when approved and safe; never pass malformed arguments to tools |
| Prompt injection detected | Exclude or reject affected context according to policy; never obey it; record a redacted safety event |
| Safety incident active | Apply the scoped or global deterministic-only, degraded, refused, or unavailable mode before execution |
| Ordinary observability write failure | Do not log sensitive fallback content; degrade or alert according to policy while preserving required audit obligations |
| Mandatory audit write failure before execution | Fail closed for provider execution or consequential commit |
| Mandatory audit write failure after provider success | Preserve a pending recovery fact without repeating the provider call; do not fabricate completion |
| Firestore control configuration unavailable | Critical policy, registry, prompt, flag, entitlement, budget, or incident uncertainty denies provider execution |
| Fallback route unavailable | Return unavailable, abstained, or deterministic-only; never call a provider directly |
| Legacy fallback disabled | Do not re-enter the direct provider path; return the controlled target response |
| Rollback requested | Stop new affected executions, move only approved mutable pointers or deployment routing, and retain all historical evidence |

The exact durable recovery mechanism for a post-execution audit-write failure
is an implementation decision. It must prevent duplicate provider execution
and must preserve evidence sufficient for reconciliation.

## Audit-event requirements

An append-only audit event is required for:

- Safety policy, incident policy, and classification-policy publication,
  activation, suspension, rollback, or retirement.
- Provider, model, prompt, feature, tool, RAG, memory, or cache suspension.
- Kill-switch activation, scope change, expiry, recovery test, and release.
- Administrative override, break-glass access, and recovery approval.
- Safety-event correction, legal hold, retention-class change, and authorized
  exceptional content access.
- Failed or denied administrative actions where they are security-relevant.

Every event must include a unique event ID, idempotency or command reference,
actor or system identity, authorization basis, environment, scope, reason,
occurred time, recorded time, relevant before/after version references,
correlation IDs, retention class, and integrity metadata. Corrections append a
new linked event; they never rewrite history.

## Data-retention requirements

Retention is policy-class based:

- **Control-policy history:** safety and incident policy revisions needed to
  reproduce past decisions.
- **Safety and incident evidence:** append-only facts required for security,
  operational review, and legal obligations.
- **Financial and usage evidence:** governed by the Milestone 3 ledger and
  accounting retention class.
- **Operational telemetry:** minimized, lower-sensitivity execution facts with
  a bounded operational lifetime.
- **Content-bearing evaluation evidence:** prohibited by default; if separately
  approved, isolated and shorter-lived.
- **Transient state:** caches, circuits, locks, and idempotency projections,
  retained only as long as their correctness window requires.

Exact periods, legal bases, residency, legal-hold behavior, deletion versus
de-identification, and exceptional content retention remain open. Records must
carry a retention-class reference rather than an ad hoc duration.

## Architectural decisions

### AI-SI-001 — Deterministic aviation engines remain authoritative

- **Decision:** Deterministic aviation engines and governed operational sources
  remain authoritative. AI may explain, summarize, classify, or retrieve but
  may not replace or override their results.
- **Rationale:** Aviation-sensitive correctness must be reproducible,
  versioned, and grounded in governed rules rather than probabilistic model
  memory.
- **Alternatives considered:** Model-first aviation answers; prompt-only
  disclaimers; provider safety filters as the deciding authority.
- **Accepted trade-offs:** Some requests will abstain or provide less fluent
  deterministic-only responses when required authority is unavailable.
- **Security impact:** Reduces manipulation of regulatory outcomes through
  prompts, injected context, or compromised provider output.
- **Cost impact:** Deterministic-first paths may avoid provider spend; grounded
  explanation adds retrieval and validation cost.
- **Scalability impact:** Versioned rule and source provenance must accompany
  requests and caches.
- **Migration impact:** Existing direct assistants must be wrapped and their
  aviation behavior validated against deterministic results before cutover.
- **Implementation priority:** Must implement before internal alpha.

### AI-SI-002 — Prompt injection cannot override platform policy

- **Decision:** All lower-trust content is data. It cannot override system,
  safety, authorization, entitlement, budget, incident, routing, or tool
  policy.
- **Rationale:** User, RAG, memory, tool, and provider text share an instruction
  channel unless the platform creates and enforces explicit trust boundaries.
- **Alternatives considered:** Relying on prompt wording; simple string
  filtering; delegating all injection defense to the provider.
- **Accepted trade-offs:** More structured context, validation, false-positive
  handling, and safety events are required.
- **Security impact:** Limits policy bypass, data exfiltration, unauthorized
  tools, and cross-tenant leakage.
- **Cost impact:** Adds classification and validation work but avoids
  uncontrolled provider and tool execution.
- **Scalability impact:** Policies and reason codes must be consistently
  enforced across every feature and provider.
- **Migration impact:** Legacy text sanitation is compatibility evidence, not
  sufficient target protection.
- **Implementation priority:** Must implement before internal alpha.

### AI-SI-003 — Memory, RAG, tools, and cache are capability-scoped and policy-gated

- **Decision:** Each context or action capability is independently authorized,
  versioned, data-scoped, observable, and revocable by the Orchestrator.
- **Rationale:** These layers can expose sensitive data or create effects even
  when provider execution itself is controlled.
- **Alternatives considered:** A shared unrestricted context store; model-owned
  tools; cache hits that bypass policy.
- **Accepted trade-offs:** Feature integration requires typed contracts,
  provenance, isolation, and more explicit failure modes.
- **Security impact:** Enforces least privilege and prevents context from
  becoming an authorization or secret store.
- **Cost impact:** Adds policy reads and metadata; safe caching and optional
  context can reduce later execution cost.
- **Scalability impact:** Scope-aware keys, invalidation, and bounded context
  are required as tenants and features grow.
- **Migration impact:** Current transcripts, retrieved chunks, and direct
  embeddings must be classified and routed through governed boundaries.
- **Implementation priority:** Minimum boundaries before internal alpha;
  durable governed memory may remain deferred.

### AI-SI-004 — Incident kill switches are server-authoritative and deny/degrade dominant

- **Decision:** Global and scoped incident controls are evaluated server-side
  before execution; a stop or safer degradation outranks flags, entitlements,
  credits, routing, cache, and administrative grants.
- **Rationale:** Incident containment must not depend on stale clients, model
  behavior, or commercial policy.
- **Alternatives considered:** Client-only flags; provider-health-driven
  automatic routing; manual deployment rollback as the only stop mechanism.
- **Accepted trade-offs:** Conservative configuration failures may reduce AI
  availability.
- **Security impact:** Provides rapid, auditable containment of compromised
  providers, assets, data paths, or features.
- **Cost impact:** Prevents uncontrolled spend during incidents and requires
  reliable control-plane reads and administration.
- **Scalability impact:** Scope resolution, cache invalidation, and propagation
  must work consistently across instances and tenants.
- **Migration impact:** Legacy paths remain outside this protection until
  wrapper-first migration and must not survive as hidden post-cutover bypasses.
- **Implementation priority:** Must implement before internal alpha.

### AI-SI-005 — Observability is mandatory, redacted, and privacy-scoped

- **Decision:** Every governed AI request and attempt produces correlated,
  content-minimized observability sufficient for safety, reliability, usage,
  and accounting without logging prohibited secrets or raw content by default.
- **Rationale:** Provider-independent operations and dispute-grade accounting
  require traceability, while AI payloads can contain highly sensitive data.
- **Alternatives considered:** Full-payload logging; provider dashboards only;
  optional per-module telemetry.
- **Accepted trade-offs:** Some debugging requires controlled reproduction
  rather than inspecting raw production payloads.
- **Security impact:** Reduces credential and personal-data exposure while
  retaining anomaly and incident evidence.
- **Cost impact:** Event storage and metrics add cost; minimization and sampling
  of non-audit telemetry bound it.
- **Scalability impact:** Stable event schemas, controlled cardinality, and
  trace correlation are required.
- **Migration impact:** Legacy message-prefix and unredacted provider-error
  logging must be removed in a later approved implementation.
- **Implementation priority:** Redacted event shape before internal alpha;
  audit-grade retention and tested alerting before paid launch.

### AI-SI-006 — Safety events are audit facts and must not be mutated

- **Decision:** Safety decisions, incidents, kill-switch actions, and
  administrative changes are append-only facts; corrections are linked events.
- **Rationale:** Investigation and rollback require the exact policy and action
  history that existed at execution time.
- **Alternatives considered:** Mutable incident documents as the only record;
  overwriting an incorrect classification; relying on application logs.
- **Accepted trade-offs:** Current-state projections and immutable history must
  both be maintained and reconciled.
- **Security impact:** Improves tamper evidence, accountability, and
  least-privilege review.
- **Cost impact:** Append-only storage grows over time and requires retention
  policy.
- **Scalability impact:** Event partitioning or an analytical sink may be
  needed only when measured volume justifies it.
- **Migration impact:** Historical legacy logs and counters are not silently
  promoted into target audit events.
- **Implementation priority:** Event semantics before internal alpha;
  audit-grade controls before paid launch.

## Security considerations

- Provider secrets remain server-side and adapter-scoped.
- Firebase and service-token authentication must be validated before
  orchestration; model text and tool arguments never grant permissions.
- Every internal record and call uses least privilege and tenant isolation.
- Provider transmission is limited to data classes approved for that feature,
  provider, region, and purpose.
- Zero-knowledge roster credentials never enter AI prompts, RAG, memory,
  caches, tools, telemetry, or provider calls.
- Admin access to policy, incidents, and exceptional diagnostics is separately
  authorized and audited.
- Safety policy or audit uncertainty fails closed for provider execution.
- Model output remains untrusted until contract, safety, and grounding checks
  succeed.

## Cost considerations

- Safety, grounding, output validation, and redacted audit events are mandatory
  platform costs, not optional provider features.
- Rejected or unsafe provider attempts may still create internal provider cost
  and ProviderUsageFact records; customer credit treatment is governed by the
  Milestone 3 policy and remains separate.
- Shadow execution requires explicit approval, internal budget, and
  non-billable classification.
- Kill switches and Budget Controller actions can reduce or stop spend but
  cannot bypass safety or deterministic authority.
- Exact alert thresholds, sampling, raw-content exceptions, and provider
  incident budgets remain open.

## Scalability considerations

- Keep the Orchestrator logically authoritative even if components later
  separate physically.
- Use stable request, decision, attempt, event, source, prompt, and policy IDs
  for correlation.
- Versioned policy and bounded caches prevent global scans on each request;
  critical kill-switch staleness must be stricter than ordinary configuration.
- Metrics must avoid unbounded user, prompt, document, and error-string
  cardinality.
- Append-only events may later export to an approved analytical or SIEM sink,
  but that sink never becomes operational policy authority.
- Multi-region active-active AI control is deferred until consistency,
  residency, and incident-propagation requirements are explicitly approved.

## Migration considerations

- Current direct provider calls, prompt-only safeguards, embedded prompts,
  message-prefix logging, raw session transcripts, and placeholder embedding
  fallback are legacy migration scope.
- Wrapper-first migration must preserve accepted product behavior while adding
  the Orchestrator safety decision and redacted evidence ahead of provider
  execution.
- Shadow or advisory evaluation cannot affect users, deterministic state,
  entitlement, credits, or product commits.
- Feature-flagged cutover must have an audited server-side kill switch and a
  defined controlled response when the target path is disabled.
- Rollback preserves target safety, attempt, usage, ledger, and audit evidence.
- Once a feature has completed migration, an embedded prompt or direct
  provider call is not an allowed fallback.
- The outstanding owner confirmation of current aviation rule values remains a
  pre-existing dependency; this document does not resolve it.

## Delivery classification

### Must implement before internal alpha

- Server-authoritative global and feature/provider/model/prompt kill switches.
- Aviation-sensitivity classification and deterministic-first policy.
- Deterministic-only, abstained, refusal, and unavailable response contracts.
- Prompt-injection trust boundaries for user, RAG, tool, memory, cache, and
  provider content.
- Redacted request, decision, attempt, safety, and audit event shapes.
- Approved conceptual AI Platform record and collection design for the
  alpha-enabled safety and incident controls.
- No logging of prohibited secrets, credentials, tokens, or raw content by
  default.
- RAG insufficiency and embedding failure represented as failure, not success.
- Tool authorization and typed validation for any alpha-enabled tool.
- Wrapper-first compatibility and rollback semantics.

### Must implement before paid launch

- Tested AI incident procedures and recovery approvals.
- Governed provider, model, prompt, feature, RAG, tool, memory, and cache
  suspension.
- Audit-grade event integrity, retention classification, access review, and
  recovery from event-write failure.
- Admin-reviewed safety and incident controls with least privilege and
  break-glass evidence.
- Migration away from direct provider calls for every billable feature.
- Ledger, Budget Controller, credit, cost, and observability correlation.
- Grounding sufficiency and output-validation policy for paid
  aviation-sensitive capabilities.
- Provider data-handling and regional approval for each enabled route.

### Deferred until scale justifies it

- Independent SIEM integration.
- Advanced experimentation and automated safety-evaluation platform.
- Dedicated Vector DB.
- PostgreSQL ledger migration.
- BigQuery analytics export.
- Redis distributed cache and rate limiter.
- Pub/Sub event lake.
- Cloud Tasks workflow infrastructure.
- Fully automated enterprise chargeback.
- Multi-region active-active AI Platform.
- Durable personalized memory beyond separately approved minimal use cases.

## Open questions

- What exact safety classes, feature mappings, and approving roles apply?
- What evidence proves sufficient grounding and claim-to-citation support?
- Which governed source types and freshness rules qualify for each capability?
- Which tools, if any, are permitted in internal alpha, and which actions
  always require explicit user confirmation?
- What consent, deletion, retention, and review policy governs future memory?
- What cache lifetimes and emergency invalidation guarantees are required?
- What incident severity taxonomy, owners, propagation objective, escalation,
  communication, and recovery approvals apply?
- What provider regions, retention, training-use settings, and diagnostic
  metadata are approved?
- Are any raw-content diagnostics ever permitted, and under what isolated
  approval and retention class?
- What exact observability retention, sampling, metric cardinality, and alert
  thresholds apply?
- Which safety and administrative actions require dual control?
- When will the pre-existing canonical FTL defaults and FDP model receive the
  recorded owner/regulatory confirmation?

These questions are explicitly unresolved. Milestone 4 does not authorize an
implementation team to choose them unilaterally.

## References

- AI_PLATFORM_OVERVIEW.md
- AI_ORCHESTRATOR.md
- AI_GATEWAY_AND_PROVIDER_ADAPTERS.md
- AI_REGISTRIES.md
- PROMPT_REGISTRY.md
- AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md
- AI_CREDITS_LEDGER_AND_BILLING.md
- AI_DATA_MODEL_PROPOSALS.md
- AI_MIGRATION_STRATEGY.md
- NAJM_ARCHITECTURE.md
- docs/ARCHITECTURE_LOCK.md
- docs/SECRETS.md
- docs/devops-runbook.md
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
