# NAJM Prompt Registry and Prompt-Version Lifecycle

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation, Milestone 2
**Document role:** Authoritative target-state prompt governance contract
**Last reconciled:** 2026-07-16

## Purpose

This document defines the Prompt Registry and prompt-version lifecycle for the
approved NAJM AI Platform.

The permanent rule is:

> Every production-executable prompt body is a versioned, governed Prompt
> Registry asset. A migrated Product API, domain engine, tool, Gateway, or
> Provider Adapter must not own a production prompt body.

The Prompt Registry makes prompt behavior reviewable, reproducible, testable,
provider-independent, and reversible without allowing prompts to replace
deterministic aviation engines or governed operational sources.

## Scope

This document defines:

- Prompt family, prompt version, immutable production asset, and active-version
  concepts.
- Prompt lifecycle, approval, promotion, deactivation, and rollback semantics.
- Required prompt metadata, variables, output contracts, safety requirements,
  and compatibility declarations.
- Provider-neutral prompt design and governed route-specific rendering.
- Relationships with the Orchestrator, AI Registries, Gateway, RAG, tools,
  memory, cache, feature flags, entitlements, and evaluation.
- Security, cost, scale, migration, and compatibility boundaries.

## Non-goals

This document does not:

- Create prompt records, Firestore collections, storage objects, endpoints,
  administration UI, or runtime loaders.
- Move or change any current prompt body.
- Define the text of any production prompt.
- Choose a provider, model, fallback route, or internal-alpha capability.
- Define exact evaluation thresholds or approver identities.
- Define provider pricing, credit burn rates, budget formulas, or ledger
  schemas.
- Define exact retention periods, regions, or observability implementation.
- Permit prompts to contain authoritative aviation rule values copied from
  model memory or ungoverned constants.

## Current legacy state

Current prompt bodies are embedded in runtime AI and knowledge modules and are
executed through direct Anthropic calls. Existing model constants and
feature-local handling determine which prompt is used. OpenAI embedding input
construction is also feature-local.

The NAJM Master Project Directive already says AI prompts should be
configurable where practical. The later owner-approved AI Platform rule is
more specific and absolute for the target state: every production prompt body
must become a versioned Prompt Registry asset.

Current prompt code remains unchanged during Phase 1 and continues to describe
legacy executable behavior. No Prompt Registry is implemented, and this
document must not be read as claiming otherwise.

## Approved target state

### Prompt selection flow

    FastAPI Product API
      -> submits provider-neutral feature/task request
      -> AI Orchestrator
          -> resolves feature, entitlement, safety, RAG, tool, and route policy
          -> Prompt Registry
              -> resolves one approved prompt family/version
              -> validates variable and output contracts
          -> Provider/Model Registries
              -> confirms capability compatibility
          -> AI Gateway
              -> receives resolved prompt/messages
              -> invokes one Provider Adapter

The Product API identifies a NAJM feature and task. It does not submit an
arbitrary production system prompt, native model name, or provider-specific
prompt override.

### Prompt family

A prompt family is the stable NAJM identity for one semantic task contract,
such as a grounded knowledge answer or a provider-neutral filter extraction.
The family defines:

- Intended NAJM feature and task.
- Required input variables and their authority.
- Expected output contract.
- Safety classification and deterministic-first requirements.
- Required RAG, tool, memory, and cache behavior.
- Compatibility contract for model capabilities.
- Locale and supported-content requirements.

A prompt family is not a provider, model, feature flag, entitlement, or
business API.

### Prompt version

A prompt version is a content-addressed production asset under one prompt
family. It includes the prompt body plus its variable, output, safety,
compatibility, evaluation, and governance metadata.

Once a version is approved for execution, its prompt body and material
contract metadata are immutable. Any material change creates a new version.

### Active version

Activation is an environment-scoped pointer or policy decision to one approved
prompt version. Exact storage is deferred to the data-model proposal.

Only the AI Orchestrator resolves the active version. Product modules,
Gateways, adapters, clients, and tools do not maintain their own active prompt
selection.

## Component responsibilities

### Prompt Registry owns

- Stable prompt-family identity.
- Versioned prompt bodies.
- Immutable approved-version content hashes.
- Typed variable contract and allowed data classes.
- Output-schema contract reference.
- Safety, grounding, citation, RAG, tool, memory, and cache requirements.
- Provider/model capability compatibility.
- Locale support and approved rendering variants.
- Evaluation evidence and known limitations.
- Lifecycle, environment promotion, activation, deactivation, and rollback
  metadata.
- Governance, change reason, authorship, review, and approval evidence.

### Prompt Registry does not own

- Feature entitlement.
- Provider or model selection.
- Provider credentials or SDK parameters.
- Authoritative legality rules or operational knowledge.
- RAG documents, memory records, tool implementations, or cache contents.
- User credit prices or provider invoices.
- Product business transactions.

### AI Orchestrator owns

- Selecting the prompt family for an approved feature/task.
- Resolving an approved active version.
- Validating required variables and authorized data references.
- Selecting an approved rendering compatible with the chosen model route.
- Combining governed context without changing source authority.
- Recording prompt family, version, content hash, rendering, and evaluation
  provenance.
- Denying, degrading, or abstaining when the prompt asset is unavailable or
  incompatible.

### Product API owns

- Product request validation.
- Trusted identity and authorization context.
- Product-owned input and output compatibility.
- Business transaction and user-facing error handling.

The Product API must not own or accept an unrestricted production prompt body.

### AI Gateway and Provider Adapter own

- Transporting the resolved prompt/messages through the normalized execution
  contract.
- Provider-specific request translation.

They must not edit semantic prompt intent, select another prompt, add hidden
system instructions, or fall back to a provider-owned business prompt.

## Prompt Registry proposed model

This is a conceptual information contract. Exact collections, storage, field
serialization, and indexes are deferred to the approved data-model proposal.

| Field group | Required meaning |
|---|---|
| Identity | Stable prompt-family key, immutable version, registry revision |
| Purpose | NAJM feature, task, intended behavior, non-goals |
| Body | Versioned system/developer instruction assets and approved composition order |
| Variables | Typed names, source authority, required/optional status, size limits, data classification |
| Output | Structured schema or response contract reference and validation policy |
| Context | RAG, tool, memory, cache, locale, and citation requirements |
| Safety | Aviation-sensitivity class, deterministic-first rule, abstention policy, prohibited claims |
| Compatibility | Required model capabilities and approved rendering variants |
| Evaluation | Evaluation set/version, results reference, known limitations, approval evidence |
| Lifecycle | State, environment activation, effective time, predecessor, supersession, rollback eligibility |
| Governance | Author, reviewer/approver, change reason, change summary, timestamps |
| Integrity | Prompt-body content hash, full asset hash, immutable revision |

Prompt variables contain data, not executable provider routing. Provider
credentials, service tokens, Firebase tokens, roster-provider credentials, and
secret-bearing feed URLs are forbidden prompt variables.

## Prompt composition boundaries

The target prompt asset may define governed layers, but the composition order
must be explicit and versioned:

1. Platform safety and authority rules.
2. Feature/task behavior.
3. Output and tool contract.
4. Grounding and citation requirements.
5. Authorized context placeholders.
6. User input as untrusted content.

User input, retrieved text, memory, and tool results are data. They never
become higher-authority instructions merely because they are concatenated into
a request.

Prompt composition must not copy mutable legality thresholds, duty limits, or
other authoritative operational values into a prompt asset. Those facts are
obtained at request time from governed sources or deterministic tools and
remain labeled as data with provenance.

## Variable contract

Each variable must declare:

- Stable variable name and type.
- Required or optional status.
- Authoritative source class.
- Allowed data classification.
- Maximum size or item count.
- Escaping/serialization requirements.
- Missing-value behavior.
- Whether the value may be transmitted to the selected provider.
- Whether the value may be retained, cached, or included in diagnostics.

The Orchestrator validates the variable contract before Gateway execution.
Callers cannot add undeclared variables or downgrade a data classification.

Untrusted text must remain structurally separated from system/developer
instructions whenever the normalized provider capability permits it.

## Output contract

Every prompt version declares one of:

- A provider-neutral structured-output contract.
- A bounded text response contract with required provenance.
- A normalized tool-call contract.
- An embedding-input preparation contract where applicable.

The prompt does not define the Product API’s public schema. The Product API
owns backward compatibility; the Orchestrator validates and maps the AI result
within that product contract.

Malformed, incomplete, ungrounded, or policy-violating output is not accepted
because the provider returned HTTP success.

## Provider-neutral and route-specific rendering

The semantic prompt family and variable/output contract are provider-neutral.
When providers require materially different message or schema rendering, the
Prompt Registry may contain approved route-capability renderings under the
same family/version.

Route-specific rendering:

- Is versioned and evaluated as part of the prompt asset.
- Is selected only by the Orchestrator after route selection.
- Cannot live in Product APIs, domain engines, Gateways, or adapters.
- Cannot weaken safety, grounding, variable, output, or data-policy
  requirements.
- Cannot introduce a second business meaning for the same prompt family.

An adapter may translate normalized message structure to provider syntax but
must not own hidden semantic prompt text.

## Prompt lifecycle

Exact serialized enum names are deferred to the data-model proposal, but every
implementation must preserve these semantics.

| State | Executable? | Meaning |
|---|---:|---|
| Draft | No | Work in progress; not available to runtime |
| In review | No | Content and contracts are sealed for review |
| Approved | No by itself | Review passed and the version is immutable |
| Staged | Only in the approved non-production environment | Validation against approved routes is permitted |
| Active | Yes, in the explicitly activated environment | Eligible for Orchestrator resolution |
| Superseded | Compatibility only if policy explicitly permits | A newer active version exists |
| Suspended | No | Temporarily disabled for safety, security, quality, or incident reasons |
| Retired | No | Permanently ineligible for new execution |

A draft can be revised before review. Once submitted as a reviewable version,
material edits create a new version rather than changing the sealed asset.

## Review and promotion requirements

Before activation, a prompt version requires evidence appropriate to its task:

- Variable and output contract validation.
- Static checks for undeclared variables, secrets, prohibited routing, and
  unsafe authority claims.
- Evaluation against approved representative inputs.
- Grounding, citation, abstention, and prompt-injection scenarios when
  applicable.
- Tool-call authorization and malformed-argument scenarios when applicable.
- Compatibility evidence for each approved rendering/model capability.
- Token/context-size and provider-cost estimate.
- Aviation-safety review for aviation-sensitive tasks.
- Recorded author, reviewer/approver, change reason, and known limitations.

Exact evaluation thresholds, reviewer identities, approval count, and
aviation-safety taxonomy remain open decisions.

Environment promotion must reference the same immutable prompt version. It
must not rebuild or silently alter the body between development, staging, and
production.

## Activation, fallback, and rollback

- Missing, unreadable, unapproved, suspended, incompatible, or invalid prompt
  state fails closed before provider execution.
- A migrated AI feature must not fall back to an in-code prompt constant.
- Prompt fallback is an Orchestrator decision and may use only an explicitly
  approved compatible version.
- Model/provider fallback does not permit a different unapproved prompt
  meaning.
- Rollback reactivates a previously approved immutable version.
- Rollback never edits or deletes the failed version or its historical audit
  references.
- Every attempt records the exact prompt version, rendering, and content hash.
- An emergency global or prompt-specific kill switch can suspend execution
  without changing the prompt body.
- Independent deterministic product behavior remains available when no AI
  prompt can execute.

## Feature flags and prompt experiments

Feature flags may select between approved prompt versions only through the
Orchestrator. A flag:

- Cannot activate a draft or unapproved prompt.
- Cannot bypass safety, data, entitlement, or budget controls.
- Cannot give a client or Product API a raw prompt override.
- Must record the flag evaluation and selected prompt version.
- Must use stable, auditable assignment when an approved comparison is run.

This document does not approve any prompt experiment, cohort, or alpha
capability.

## Architectural decisions

### AI-PRM-001 — Prompt Registry is the production prompt source of truth

- **Decision:** Every production-executable prompt body for a migrated AI
  feature is resolved from the Prompt Registry.
- **Rationale:** Embedded prompts cannot be centrally governed, versioned,
  evaluated, rolled back, or audited across providers.
- **Alternatives considered:** Prompt bodies in business modules; environment
  variables; adapter-owned prompts; provider console prompts.
- **Accepted trade-offs:** Prompt Registry availability becomes a fail-closed
  runtime dependency.
- **Security impact:** Central review prevents arbitrary prompt injection from
  clients and limits secret/policy leakage.
- **Cost impact:** Central prompt sizing and evaluation improve token-cost
  control; registry reads add small overhead.
- **Scalability impact:** One governed family can support many Product APIs and
  provider routes without duplication.
- **Migration impact:** Current code prompts remain legacy until captured and
  migrated without changing public behavior.
- **Implementation priority:** Must implement before internal alpha for every
  admitted AI feature.

### AI-PRM-002 — Approved production versions are immutable

- **Decision:** Prompt body or material-contract changes create a new immutable
  version; promotion and rollback move active references.
- **Rationale:** Reproducibility and rollback are impossible when active prompt
  content changes in place.
- **Alternatives considered:** Mutable current prompt; overwrite on deploy;
  source-control history alone.
- **Accepted trade-offs:** More versions and lifecycle metadata.
- **Security impact:** Provides tamper evidence and accountable changes.
- **Cost impact:** Small storage cost; reduced incident and regression cost.
- **Scalability impact:** Immutable versions cache and distribute safely.
- **Migration impact:** Each current prompt requires a captured baseline hash
  before later migration.
- **Implementation priority:** Must implement before internal alpha.

### AI-PRM-003 — Typed variables and output contracts

- **Decision:** Every prompt version declares typed input variables, authority,
  data handling, bounds, and expected output/tool contracts.
- **Rationale:** Untyped string concatenation obscures trust boundaries and
  makes provider/model changes unsafe.
- **Alternatives considered:** Free-form prompt concatenation; validation only
  after provider response; per-provider DTOs in Product APIs.
- **Accepted trade-offs:** Prompt authors maintain explicit schemas.
- **Security impact:** Separates trusted instructions from untrusted user,
  retrieval, memory, and tool data.
- **Cost impact:** Size bounds prevent uncontrolled context and output spend.
- **Scalability impact:** Stable contracts support multiple model routes and
  automated validation.
- **Migration impact:** Legacy prompt inputs must be inventoried and typed
  before redirection.
- **Implementation priority:** Must implement before internal alpha.

### AI-PRM-004 — Provider-neutral semantics with governed renderings

- **Decision:** Prompt meaning and contracts are provider-neutral; unavoidable
  route-specific renderings are versioned Prompt Registry assets.
- **Rationale:** Provider syntax differs, but allowing semantic prompts inside
  adapters recreates hidden provider coupling.
- **Alternatives considered:** One universal string regardless of capability;
  adapter-owned prompts; provider-specific Product APIs.
- **Accepted trade-offs:** Some prompt versions require multiple evaluated
  renderings.
- **Security impact:** Route differences remain reviewable and cannot silently
  weaken safety/data policy.
- **Cost impact:** Rendering variants may require additional evaluation but
  allow provider portability and cost comparison.
- **Scalability impact:** New providers reuse task contracts rather than
  duplicating business logic.
- **Migration impact:** Existing provider-specific wording is captured as an
  explicit compatibility rendering when later approved.
- **Implementation priority:** Must implement before a second provider route is
  enabled for a task; core semantic contract is required before alpha.

### AI-PRM-005 — Deterministic and governed sources outrank prompts

- **Decision:** Prompts describe behavior but cannot define, copy as authority,
  or override aviation legality, operational rules, authorization, or governed
  knowledge.
- **Rationale:** Prompt text and model memory are not reproducible regulatory
  sources.
- **Alternatives considered:** Hardcoded rule numbers in system prompts;
  provider safety policy as legality authority; model-only answers.
- **Accepted trade-offs:** Missing authoritative context produces abstention or
  deterministic-only output.
- **Security impact:** Limits prompt injection and model behavior from changing
  consequential facts.
- **Cost impact:** Deterministic-first handling can avoid unnecessary calls;
  grounding adds bounded context cost.
- **Scalability impact:** Safety sources evolve independently of prompt
  versions.
- **Migration impact:** Existing prompts must remove copied mutable authority
  when later migrated, without changing deterministic engines in Phase 1.
- **Implementation priority:** Must implement before internal alpha.

### AI-PRM-006 — Evaluated promotion and reversible activation

- **Decision:** Only reviewed, evaluated, immutable prompt versions may be
  activated; rollback reactivates a prior approved version.
- **Rationale:** Prompt changes can alter safety, quality, cost, and output
  compatibility without code changes.
- **Alternatives considered:** Immediate production edits; review after deploy;
  model-provider rollback only.
- **Accepted trade-offs:** Promotion requires evidence and operational
  discipline.
- **Security impact:** Prevents unauthorized prompt changes and supports rapid
  suspension.
- **Cost impact:** Pre-activation token/cost evaluation reduces expensive
  regressions.
- **Scalability impact:** Environment-scoped activation supports controlled
  rollout without copying prompt bodies.
- **Migration impact:** Legacy prompts remain untouched until an approved
  version passes compatibility validation.
- **Implementation priority:** Must implement before internal alpha.

## Security considerations

- Prompt Registry write, review, approval, activation, and rollback operations
  require least-privilege server authorization and immutable audit evidence.
- Prompt bodies contain no provider secret, service token, Firebase token,
  roster-provider credential, or secret-bearing URL.
- Prompt variables are minimized and purpose-bound.
- User input, retrieval, memory, and tool output remain untrusted data.
- Prompt content must not instruct providers to ignore deterministic engines,
  authorization, feature policy, entitlement, budget, or safety controls.
- Provider-native system prompts or console configuration cannot silently
  override the registered asset.
- Production prompt bodies must not be exposed to Flutter or ordinary Product
  API responses.

## Cost considerations

- Prompt versions record context/output estimates and evaluation cost facts,
  not user credit prices.
- Variables and retrieved context are bounded to prevent token amplification.
- Route-specific renderings may account for provider caching or tokenization
  only through approved Model Registry capabilities.
- Prompt experiments cannot bypass budget or credit reservation.
- Cost changes caused by a prompt version must be observable and reversible
  before paid launch.
- Detailed cost and margin accounting remains Milestone 3 scope.

## Scalability considerations

- Immutable prompt assets are cacheable by version and content hash.
- Active-version resolution uses small environment-scoped metadata.
- Large prompt bodies should not be duplicated into every feature record or
  ledger event; provenance uses stable identifiers and hashes.
- Prompt variable validation and composition must be bounded.
- A visual prompt-management product is unnecessary until operational scale
  justifies it.

## Migration considerations

- Current prompt code is not changed in Phase 1.
- A later migration inventories every current prompt, caller, variable,
  provider/model dependency, output contract, fallback, and safety claim.
- The captured legacy prompt becomes a compatibility version before traffic is
  redirected.
- Product API responses remain backward-compatible.
- A migrated feature cannot keep a hidden secondary in-code prompt path.
- Rollback returns the feature to an accepted prior application or prompt
  version without deleting prompt history.
- Existing direct Anthropic/OpenAI calls remain documented legacy scope.

## Delivery classification

This classification states architecture requirements and is not a plan for
Phase 2 runtime work.

### Must implement before internal alpha

- Prompt Registry coverage for every alpha-admitted AI feature.
- Immutable prompt versions, typed variables, output contracts, content hashes,
  evaluation evidence, and environment activation.
- Deterministic-first aviation rules, RAG/tool boundaries, and abstention.
- Fail-closed missing/incompatible prompt behavior.
- No alpha-admitted feature with a production prompt body in a Product API,
  domain engine, tool, Gateway, adapter, or client.

### Must implement before paid launch

- Audited author/reviewer/approver/activation operations.
- Production evaluation gates, regression suites, prompt-injection tests, and
  route-specific compatibility evidence.
- Cost and quality monitoring by prompt version.
- Tested suspension, rollback, cache invalidation, and historical provenance.
- Approved data retention and access policy for prompt assets and evaluations.

### Deferred until scale justifies it

- Visual prompt authoring and approval UI.
- Automated prompt optimization.
- Broad multivariate experimentation.
- Large multilingual rendering catalogs beyond approved product needs.
- External prompt-management SaaS.

## Open questions

- Exact Prompt Registry storage, indexes, serialization, and active-pointer
  model.
- Exact prompt-family and version naming convention.
- Prompt author, reviewer, approver, and emergency-suspension roles.
- Evaluation datasets, thresholds, and aviation-safety approval taxonomy.
- Which AI capabilities and prompt families, if any, enter internal alpha.
- Exact locale coverage.
- Exact prompt/evaluation retention and provider data-region requirements.
- Whether route-specific renderings share one version or use linked immutable
  subversions in the final data model.
- Exact propagation time for activation and suspension.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Orchestrator](AI_ORCHESTRATOR.md)
- [AI Gateway and Provider Adapters](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- [AI Registries](AI_REGISTRIES.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
- Milestone 2 companion:
  [AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md](AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md).
