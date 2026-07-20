# NAJM AI Credits, Immutable Usage Ledger, Budget, and Billing Architecture

**Status:** Approved for Phase 1 documentation, not yet implemented
**Phase:** Phase 1 — Architecture Documentation, Milestone 3
**Document role:** Authoritative target-state credit, usage-accounting, budget,
and billing-preparation contract
**Last reconciled:** 2026-07-16

## Purpose

This document defines the approved provider-independent architecture for NAJM
AI Credits, budget authorization, credit reservation, usage reconciliation,
immutable accounting, internal provider-cost attribution, and margin
accounting.

It turns the Milestone 1 and Milestone 2 boundaries into a durable financial
and operational contract. It does not implement those boundaries or change
current behavior.

The governing invariants are:

> Users consume NAJM AI Credits only. Provider-native units and provider costs
> remain internal business facts.

> Budget approval and, when applicable, credit reservation occur before
> provider execution. Every result is reconciled idempotently, and every
> billable effect is represented by immutable ledger events.

> Credits and budget policy can deny AI execution, but they can never override
> authentication, authorization, feature flags, entitlements, aviation-safety
> policy, deterministic authority, route approval, or incident kill switches.

## Scope

This document defines:

- The NAJM AI Credit economy and provider-neutral burn-rate principles.
- Individual, family, corporate, enterprise, promotional, and internal-alpha
  account and pool boundaries.
- Request-level estimation, budget decisions, credit reservation,
  reconciliation, release, adjustment, and refund semantics.
- The immutable AI usage ledger and its relationship to balance projections.
- Provider usage facts, estimated cost, provider-reported cost,
  invoice-reconciled cost, and margin snapshots.
- The Budget Controller as a logical policy component coordinated by the AI
  Orchestrator during MVP.
- Provider budget caps and user or organization quota boundaries.
- Subscription and entitlement integration without creating commercial
  products or prices.
- Admin overrides, emergency credits, disputes, audit requirements, and
  retention requirements.
- Required idempotency, failure, fallback, compatibility, and rollback
  semantics.
- Conceptual normalized models for later implementation.
- Requirements for internal alpha, paid launch, and scale-deferred operation.

## Non-goals

Milestone 3 does not:

- Modify Python, Dart, TypeScript, Firebase rules, shell scripts, environment
  files, dependency files, tests, or deployed behavior.
- Create credit accounts, balances, reservations, transactions, ledgers,
  Firestore collections, indexes, security rules, migrations, APIs, or admin
  screens.
- Enable subscription enforcement, purchases, billing, or paid AI.
- Integrate Stripe, RevenueCat, Paddle, Apple App Store, Google Play, or an
  enterprise invoicing system.
- Approve a customer price, credit denomination, numeric burn rate, included
  allocation, quota amount, trial, refund promise, tax treatment, commission,
  currency, or foreign-exchange rule.
- Approve a family, corporate, or enterprise commercial product.
- Expose provider names, native model names, tokens, request quotas, or native
  billing units to users.
- Treat provider cost as the customer-visible value of a NAJM AI Credit.
- Select a ledger database, Firestore collection layout, transaction
  mechanism, event bus, warehouse, or reporting product.
- Change current Free/Pro behavior, the subscriptions-disabled Free launch, or
  existing counters.
- Remove or redirect legacy Anthropic or OpenAI calls.
- Define Milestone 4 safety, incident, persistence, or migration documents.
- Update architecture indexes or reconcile older cross-reference wording.

## Current legacy state

The following describes current repository behavior. It is not the approved
credit architecture and is not changed by this document.

| Current repository fact | Architectural interpretation |
|---|---|
| Subscription models define Free and Pro, and subscription enforcement is disabled by default | Preserved compatibility scaffolding; not a credit economy or paid-launch entitlement system |
| The Cloud Functions AI callable uses a daily `aiUsage` counter | A legacy request counter; not an immutable ledger, reservation, cost record, or credit balance |
| The Python subscription tracker uses monthly `usageCounters` | A legacy feature counter; not the target billing source of truth |
| A separate Python rate limiter uses daily `rateLimits` with hardcoded tier behavior | Pre-existing compatibility debt; it is not authoritative credit or subscription policy |
| Existing counter checks and writes use different windows, sources, and concurrency semantics | Evidence that no unified target accounting boundary exists today |
| Some legacy paths use wording or sentinels that imply no numeric cap for selected tiers | Current implementation evidence only; no target AI service is promised to be unbounded |
| RevenueCat-shaped fields and store-related comments exist | Future-oriented scaffolding; no purchase validation, webhook reconciliation, or store billing is implemented |
| `docs/cost-model.md` contains Claude-specific costs, tier projections, and margin estimates | An unvalidated planning scenario, not current telemetry, approved pricing, or target policy |
| Anthropic generation and OpenAI embeddings are called directly by current modules | Legacy migration debt; no runtime provider path changes in Phase 1 |

The existing counters do not preserve a complete estimate, reservation,
provider attempt, native usage, actual cost, final credit charge, adjustment,
or refund history. They must not be relabeled as the immutable AI usage ledger.

There is currently no implemented NAJM AI Credit balance, Budget Controller,
credit reservation workflow, billable reconciliation workflow, margin
accounting system, or external billing integration.

These are pre-existing repository conditions. Milestone 3 introduces only the
approved target-state documentation below.

## Approved target state

The target request path remains:

    Flutter or approved service caller
      -> authenticated FastAPI Product API
          -> AI Orchestrator
              -> kill switch, feature, entitlement, and safety decisions
              -> eligible prompt/model route candidate and cost estimate
              -> Budget Controller decision
              -> AI Credit service reservation or non-billable authorization
              -> final approved route and bounded attempt plan
              -> AI Gateway
                  -> exactly one Provider Adapter per attempt
                      -> external provider
              <- normalized provider usage and cost facts
              -> idempotent reconciliation or release
              -> immutable usage, credit, cost, and audit events
          <- provider-neutral product result and accounting references

The Product API owns the product contract. The Orchestrator coordinates the
policy sequence. The Budget Controller evaluates request-level spend and
credit policy. The AI Credit service owns authoritative account and pool
availability plus reservation and reconciliation results. The Gateway and
adapters preserve provider usage facts. The immutable ledger records what
occurred.

During MVP, these are logical boundaries that may coexist in the existing
FastAPI deployment. The Budget Controller is not an independent microservice
unless a later approved decision establishes measurable need.

No credit balance, grant, subscription, admin action, or model output can
authorize direct provider access. Provider Adapters remain the only provider
API or SDK call site.

## Source-of-truth hierarchy for credits, usage, and billing facts

This hierarchy specializes the authority model in
`AI_PLATFORM_OVERVIEW.md`. Sources answer different questions and must not be
collapsed.

### Normative authority

When architecture or policy documents conflict, authority remains:

1. Latest explicit owner decision.
2. NAJM Master Project Directive.
3. `docs/ARCHITECTURE_LOCK.md`.
4. Approved Phase 1 AI architecture documents, including this document.

Numeric commercial policy is authoritative only after explicit owner approval
and versioned publication through the future governed catalog. Historical
README, cost-model, source-code comment, or provider price wording cannot
create a customer price or credit promise.

### Runtime accounting authority

| Authority | Fact it owns | Facts it cannot redefine |
|---|---|---|
| Versioned feature, entitlement, safety, credit, burn-rate, and budget policy | What should have been allowed, reserved, charged, limited, or denied at decision time | What provider execution actually consumed |
| Credit account and pool grant facts | Which governed pool supplied spendable NAJM AI Credits and under what validity or restrictions | Provider-native usage or aviation authority |
| Immutable credit transactions and AI usage ledger events | What reservation, debit, release, grant, adjustment, refund, or usage effect occurred | Historical policy or provider facts |
| Gateway and Provider Adapter usage facts | What a provider reported or what execution facts remain zero, partial, known, or uncertain for an attempt | User credit burn or subscription value |
| Effective-dated Model Registry pricing references | How native usage was estimated or priced internally at a particular time | Customer-visible price or credit burn |
| Provider invoice reconciliation | Later internal correction of provider cost for a billed period | Original estimate, reported usage, or user charge history |
| Audit events | Who or what made an administrative or policy decision and why | Account balance by themselves |
| Balance, quota, cost, and margin projections | Rebuildable operational views over authoritative events | Independent mutations or historical truth |

The immutable ledger is the billing and accounting source of truth for credit
effects. A current balance is a transactionally maintained projection that
must reconcile to that ledger; it is not permission to edit historical
events.

Provider-estimated, provider-reported, and invoice-reconciled costs remain
separate facts. A later invoice correction appends a reconciliation or
adjustment event and never rewrites the original attempt record.

Legacy `aiUsage`, `usageCounters`, and `rateLimits` documents remain evidence
of current compatibility behavior only. They are not target ledger facts and
cannot settle a billing dispute.

Deterministic aviation engines and governed operational sources remain
authoritative for aviation facts. No credit or accounting event can change a
legality result or make model memory authoritative.

## Component responsibilities

### FastAPI Product APIs

Product APIs own:

- Authentication and product authorization at the external boundary.
- Product input validation and public response compatibility.
- A stable logical request identifier, product transaction reference, and
  idempotency key.
- Submission of a provider-neutral feature and task to the Orchestrator.
- User-safe handling of insufficient-credit, budget, unavailable, and pending
  accounting outcomes.
- The final business transaction after the Orchestrator says it may commit.

Product APIs must not read or mutate a credit balance directly, calculate a
provider charge, choose a provider for cost reasons, grant an override, or
call the Gateway, adapter, or provider.

### AI Orchestrator

The Orchestrator owns:

- Coordinating authentication/authorization context, kill switches, feature
  flags, entitlements, aviation safety, registries, prompts, budgets, credits,
  fallback, and accounting obligations.
- Requesting a Budget Decision before budget-governed provider execution.
- Requesting one logical credit reservation or explicit non-billable
  authorization before provider execution.
- Recording the budget, credit, price-policy, registry, prompt, and safety
  versions used.
- Binding all attempts and fallback attempts to one logical request and
  idempotency scope.
- Sending only resolved execution facts to the Gateway.
- Coordinating reconciliation, release, pending-accounting recovery, and
  immutable event append after the result.

The Orchestrator does not own payment-provider webhooks, commercial product
prices, authoritative account storage, immutable ledger storage, provider
SDKs, or provider secrets.

### Budget Controller

The Budget Controller owns the versioned decision about whether a proposed AI
request may consume an approved amount of internal cost and NAJM AI Credits.
It evaluates:

- Environment, feature, task, actor, and approved organization scope.
- Entitlement limits supplied by the authoritative Entitlement service.
- Credit policy, authoritative availability result supplied by the AI Credit
  service, request ceiling, and reservation need.
- Estimated native usage and internal cost derived from approved route and
  pricing facts.
- Provider, model-route, feature, account, pool, organization, environment,
  and time-window budget caps when configured.
- Maximum attempts, fallback allowance, tool calls, context/output limits, and
  deadline relevant to spend.
- Applicable authorized admin or emergency budget decision.

It returns an immutable `BudgetDecision` reference with allow, deny, or bounded
allow semantics. It does not select the route, invoke a provider, mutate the
ledger, grant an entitlement, weaken safety, or override a kill switch.

During MVP the Budget Controller is a logical Orchestrator policy component,
not an independent service.

### AI Credit service

The AI Credit service owns:

- Authoritative account and pool availability.
- Allocation validity, restrictions, expiry, and reservation eligibility.
- Atomic, idempotent reserve, amend, reconcile, release, grant, debit, credit,
  and adjustment outcomes.
- Prevention of overspend and duplicate financial effects.
- Ledger append requirements and balance-projection reconciliation.

It does not decide feature availability, entitlement, aviation safety,
provider route, provider cost, or payment-provider state.

### Immutable ledger and audit boundary

This boundary owns append-only credit transactions, AI usage events, cost
reconciliation events, and administration audit evidence. It returns stable
event identifiers and append outcomes. It never silently drops, edits, or
deletes an historical financial effect.

### Feature Flag and Entitlement services

- Feature flags decide whether an approved NAJM capability is operationally
  available.
- Entitlements decide whether the actor may use that provider-neutral
  capability and service level.
- Neither owns balances, burn rates, provider usage, or ledger mutations.
- A credit balance cannot create an entitlement, and an entitlement cannot
  create a credit balance.

### Subscription system and future billing boundary

The subscription system maps approved commercial or compatibility state to
provider-neutral entitlements. A future billing boundary may cause approved
credit grant, revocation, expiry, or refund-adjustment requests after external
commerce validation. It cannot write ledger history directly or expose raw
receipts to the Orchestrator.

### Provider and Model Registries

- The Model Registry supplies effective-dated internal provider pricing
  references, native unit vocabulary, capabilities, and route constraints.
- The registries do not contain user prices, credit balances, customer burn
  rates, or commercial entitlements.

### AI Gateway and Provider Adapters

- The Gateway executes the Orchestrator-approved route and returns normalized
  usage and internal cost facts.
- Each Provider Adapter extracts native unit labels, quantities, provider
  request identifiers, reported costs where available, and uncertainty.
- The Gateway never converts native units into NAJM AI Credits.
- Adapters never own business pricing, subscriptions, credits, margins, or
  cross-provider fallback.

### Flutter, admin clients, domain engines, and tools

- Flutter may display a server-authoritative NAJM AI Credit balance,
  reservation status, charge, or user-safe denial.
- Admin clients use governed server APIs and never write balances or ledger
  events directly.
- Domain engines and tools remain outside credit accounting and cannot call a
  provider.
- No client receives provider secrets, provider-native units, internal cost,
  invoice detail, or unrestricted accounting controls.

## Credit economy

### Definition

A **NAJM AI Credit** is a provider-neutral service-consumption accounting unit
defined by an approved, versioned NAJM credit policy. It is the only
AI-consumption unit that may be shown to or allocated to a user.

A NAJM AI Credit is not:

- A provider token, character, image, second, embedding unit, cache unit, or
  native request quota.
- A promise of a particular provider or model.
- A direct pass-through of provider cost.
- An entitlement to an AI feature.
- Permission to bypass a budget cap, safety rule, deterministic engine, data
  policy, or incident control.
- Automatically cash, currency, stored value, or refundable consideration;
  any legal or commercial characterization requires separate approval.

### Credit lifecycle

Credits enter or leave an account or pool only through immutable transactions
with an approved source and reason. Conceptual sources include:

- A compatibility or internal-alpha allocation.
- A future approved subscription allocation.
- A future validated one-time purchase.
- A promotional, referral, support, or administrative grant.
- An enterprise allocation from an approved organization pool.
- A refund, dispute resolution, or corrective adjustment.
- Expiry or revocation under the versioned policy that created the grant.

No source is commercially enabled by this document. Every grant records its
policy version, validity, restrictions, provenance, and idempotency scope.

### Burn-rate principles

Credit burn is governed by a versioned NAJM policy, not by a provider adapter
or native token count. The policy must:

- Name a NAJM feature, task, and service-level or outcome class.
- Define an estimate and maximum reservable credit amount before execution.
- Define how completed, cached, deterministic-only, partial, blocked, failed,
  cancelled, and uncertain outcomes are treated.
- Define how approved tool calls and fallback attempts fit within the same
  logical request ceiling.
- Remain provider-neutral in customer-facing representation.
- Use internal provider cost only as one governed business input; a provider
  price change does not silently change a customer charge.
- Be immutable by version, effective-dated, auditable, and reversible through
  activation of another approved version.
- Prevent a model, prompt, Product API, Gateway, or adapter from increasing the
  burn rate or request ceiling.

This document does not decide numeric rates, included allocations, cache-hit
treatment, minimum charges, rounding, rollover, expiry, or customer price.

## Credit pools and account hierarchy

### Account types

The target supports these conceptual account scopes:

| Account or pool | Intended boundary | Delivery position |
|---|---|---|
| Individual user account | Credits allocated directly to one authenticated user | Required for paid launch; may be advisory or non-billable during alpha |
| Internal-alpha pool | Explicitly non-billable or sponsored usage for approved testers | Required if internal alpha executes provider work without customer debit |
| Family pool | Shared allocation with governed membership, guardian/owner policy, and per-member controls | Target only; deferred until an approved family product exists |
| Corporate pool | Organization-funded credits with member allocations and policy limits | Target only; deferred until an approved corporate product exists |
| Enterprise pool | Contract-funded allocation with tenant isolation and delegated administration | Target only; deferred until an approved enterprise need exists |
| Promotional or support grant | Restricted, expiring, reasoned credit allocation | Paid-launch support capability when separately approved |

The presence of an account or pool never creates feature access. The
Entitlement service must allow the capability independently.

### Pool hierarchy rules

- Every reservation identifies its complete authorized funding source or
  sources without ambiguity. Whether split funding is allowed remains an open
  policy decision; if approved later, allocation must be atomic and each source
  effect immutable.
- Pool selection is server-authoritative and reproducible from versioned
  allocation policy; callers cannot pick a more permissive pool.
- A user may draw from an organization pool only through an active,
  authorized allocation.
- Individual, family, corporate, and enterprise balances remain isolated
  unless an explicit transfer or allocation event connects them.
- Parent-pool limits, child allocations, per-feature limits, per-member
  limits, and time-window quotas compose deny-dominantly.
- No child allocation can exceed the available parent authorization.
- Pool expiry, rollover, transfer, reclaim, and precedence require explicit
  policy and immutable events.
- Organization membership or role claims are authorization inputs, not credit
  balances by themselves.
- Removing a member prevents new reservations but does not rewrite historical
  usage or allocation events.

### Quota boundaries

Quotas may exist at the request, user, family, corporate, enterprise,
feature, environment, or time-window level. They are NAJM policy limits, not
provider-native quotas.

The strictest applicable authorized limit wins. A quota reset begins a new
period or allocation state and never deletes or rewrites prior consumption.
Exact periods, quantities, rollover, and hierarchy precedence remain open.

## Reservation and reconciliation semantics

### Pre-execution reservation

For every budget-governed request, the target sequence is:

1. The Product API supplies a logical request ID, product idempotency key,
   trusted actor context, feature/task, and transaction reference.
2. The Orchestrator obtains deny-dominant feature, entitlement, safety,
   registry, prompt, and incident decisions.
3. The Orchestrator obtains a route-specific internal cost estimate and a
   provider-neutral maximum credit estimate.
4. The Budget Controller evaluates applicable request, feature, account,
   pool, organization, provider-route, environment, and time-window ceilings.
5. If billable, the Orchestrator requests an atomic credit reservation against
   the complete authorized funding-source set under the approved pool policy.
6. If explicitly non-billable, the Orchestrator records the approved
   non-billable classification and any advisory reservation or budget ceiling.
7. Only after every mandatory decision allows does the Orchestrator send an
   execution plan to the Gateway.

A reservation:

- Is bound to one logical request, actor/scope, feature/task, credit-policy
  version, maximum amount, complete funding-source set, and idempotency key.
- Reduces available spendable capacity without becoming a final debit.
- Has an effective time and bounded expiry or recovery policy.
- Covers a bounded set of approved attempts under one logical request.
- Cannot be enlarged by the client, Product API, prompt, model, Gateway, or
  adapter.
- May be amended only through a new authorized, idempotent pre-execution
  decision and immutable event.
- Must not permit aggregate attempt charges above its authorized ceiling.

### Fallback and reservation scope

- Every provider or model attempt has a unique attempt ID beneath the same
  logical request and idempotency scope.
- A fallback is selected only by the Orchestrator and must satisfy the same
  entitlement, safety, data, prompt, deadline, and incident policy.
- Known and uncertain usage from prior attempts remains attached to the
  logical request.
- If a fallback fits inside the existing authorized reservation and budget,
  it may proceed under that reservation.
- If a fallback requires a larger ceiling, a new budget decision and atomic
  reservation amendment must succeed before the fallback executes.
- A failed attempt cannot create a separate customer charge merely because a
  second provider was tried.

### Post-execution reconciliation

Reconciliation preserves, rather than overwrites:

- Original cost and credit estimate.
- Original reservation and every authorized amendment.
- Every provider attempt and its known, zero, partial, or uncertain native
  usage.
- Provider-reported cost when available.
- Later invoice-reconciled cost when available.
- Final provider-neutral credit charge under the applicable burn policy.
- Released reservation amount.
- Adjustment, refund, dispute, or admin events linked to the original facts.

The final user credit effect occurs once per logical charge outcome. Unused
reserved credits are released. A partial or failed outcome follows the
versioned burn policy and must never be inferred from HTTP status alone.

Usage uncertainty is a first-class state. It cannot be silently treated as
zero. A reservation may remain in a bounded pending-accounting state until the
usage is resolved, an approved conservative policy applies, or an authorized
adjustment closes it.

### Reservation state projections

Reservation lifecycle labels are an implementation detail, but every design
must represent these semantics:

- Requested but not authorized.
- Active and holding capacity.
- Amended with immutable provenance.
- Reconciliation pending.
- Reconciled to a final charge and release.
- Released because execution is known not to have occurred.
- Expired without unsafe automatic release.
- Disputed or administratively adjusted.

The mutable current-state view is a projection. Each transition requires a
unique immutable event.

## Immutable ledger architecture

### Ledger purpose

The immutable AI usage ledger is the durable billing, dispute, audit, and
accounting record of AI execution and credit effects. It links policy intent
to provider execution facts without storing raw provider payloads.

### Ledger invariants

- Ledger events are append-only. Update-in-place and deletion of financial
  history are forbidden.
- Every event has a globally unique ID, stable event type, logical request ID,
  idempotency scope, occurred time, recorded time, actor/scope reference, and
  integrity metadata.
- Every credit movement identifies its funding account or pool, amount,
  direction, source/reason, policy version, and related event.
- Every request-level event links applicable feature, entitlement, safety,
  budget, prompt, provider, model, adapter, pricing, and burn-policy versions.
- Every adjustment links to the event it corrects without replacing it.
- Duplicate delivery returns the existing event or no-op outcome.
- A reused idempotency key with a different semantic fingerprint is rejected
  as a conflict.
- Balance and quota projections must be rebuildable and continuously
  reconcilable to immutable events.
- Event append and authoritative availability changes must be atomic or use a
  durable protocol that provides the same no-double-spend outcome.
- Events contain compact facts and references, not raw prompts, model output,
  retrieved documents, roster content, receipts, credentials, or secrets.

### Conceptual event families

| Event family | Required meaning |
|---|---|
| Credit allocation | Approved grant, purchase-derived grant, compatibility allocation, enterprise allocation, transfer, reclaim, or expiry |
| Reservation | Reservation created, denied, amended, expired, released, or moved to pending accounting |
| Provider attempt | Attempt started, completed, failed, cancelled, partial, or usage-uncertain with usage-fact references |
| Usage outcome | Logical request completed, cached, deterministic-only, blocked, failed, abstained, or unavailable |
| Credit reconciliation | Final debit, zero charge, partial charge, and reservation release under a burn-policy version |
| Cost reconciliation | Estimated, provider-reported, and invoice-reconciled internal cost facts and variance |
| Adjustment | Administrative correction, emergency grant, goodwill credit, refund, dispute result, reversal, or compensating debit |
| Audit | Authorized policy/admin action, reason, approval evidence, and affected resources |

Event names and persistence layout remain deferred. Their semantics and
immutability are binding.

### Balance and statement views

User-visible balances, account statements, quota status, support views,
finance reports, and dashboards are derived projections. A projection may be
rebuilt, cached, or corrected; it cannot alter the ledger.

If a projection disagrees with the ledger, new reservations fail closed or
enter a controlled accounting-unavailable state until reconciliation. The
projection is repaired from authoritative events rather than editing history.

## Cost and margin accounting

### Cost fact stages

Internal cost is represented through distinct stages:

1. **Cost estimate:** a pre-execution projection using proposed route,
   expected native usage, limits, and an effective-dated Model Registry
   pricing reference.
2. **Provider-reported cost:** usage-derived or directly reported provider
   cost associated with an attempt, including currency, source, and
   uncertainty.
3. **Invoice-reconciled cost:** a later finance-grade allocation from provider
   invoice or settlement data, appended without replacing earlier facts.
4. **Serving-cost allocation:** approved variable infrastructure or tool costs
   when measurement and allocation policy later justify them.

Provider-native units remain internal. They may include provider-defined
input, output, cached, reasoning, embedding, image, audio, duration, or other
billable units, but they never become user quotas.

### Cost estimation

A `CostEstimate` must preserve:

- Route, model, adapter, prompt, and pricing-fact versions.
- Native-usage assumptions and upper bounds.
- Currency and effective time of internal pricing facts.
- Tool, fallback, context, output, and retry assumptions.
- Expected amount, conservative ceiling, confidence/quality classification,
  and expiry.
- Whether pricing is complete, partial, unavailable, or intentionally omitted
  for an explicitly non-billable internal-alpha route.

A billable or budget-governed route with required but missing pricing facts
fails closed. An explicitly non-billable internal-alpha route may proceed only
under its approved classification, bounded provider caps, and usage/audit
capture requirements.

### Actual-cost reconciliation

- Provider usage from each attempt is preserved separately.
- The applicable effective-dated price fact converts native usage to an
  internal cost estimate or reported cost.
- Missing, partial, delayed, or uncertain provider usage remains labeled as
  such.
- A provider invoice may later correct cost attribution through a new
  reconciliation event.
- Invoice variance never rewrites the user’s original credit charge. A
  customer adjustment requires its own approved policy and immutable event.
- Cross-provider fallback costs aggregate internally beneath the logical
  request while the customer credit effect remains governed by one
  provider-neutral burn policy.

### Credit burn, revenue, and cost are separate

The architecture maintains separate measures for:

- NAJM AI Credits reserved and consumed.
- Approved customer price or subscription revenue allocation, if later
  established.
- Provider cost estimated, reported, and invoice-reconciled.
- Variable platform or payment costs, if later approved for allocation.
- Taxes, store commissions, discounts, grants, refunds, and disputes, if later
  applicable.

A credit amount is not recognized revenue. Provider cost is not customer
price. Converting either into financial reporting requires a versioned,
finance-approved allocation policy.

### Margin accounting

A `MarginSnapshot` is a versioned, reproducible internal view. It may report,
when approved facts exist:

- Allocated net revenue for the request, account, product, or period.
- Provider and variable serving costs.
- Payment/store commissions and approved commercial adjustments.
- Refund and dispute effects.
- Gross or contribution margin under a named formula and accounting-policy
  version.
- Completeness and confidence status where facts remain estimated.

This document approves no revenue-allocation formula, target margin, customer
price, tax position, commission assumption, or foreign-exchange method. The
figures in the current cost model are planning estimates and must not seed
production policy without validation.

## Budget Controller

### Decision boundary

For every budget-governed request, the Budget Controller returns a versioned
`BudgetDecision` with:

- Allow, deny, or bounded-allow result and stable reason.
- Request-level internal-cost ceiling.
- Maximum NAJM AI Credits reservable under the applicable burn policy.
- Applicable account, pool, quota, provider-route, feature, environment, and
  time-window cap references.
- Approved attempt, fallback, tool, context, output, and deadline constraints.
- Pricing-fact and estimate references.
- Validity period and whether a new decision is required before another
  attempt.
- Authorized override reference when one exists.

The decision is an input to Orchestrator policy composition. An allow never
overrides another component’s deny.

### Provider budget caps

Provider budget caps are internal risk controls. They may be scoped by:

- Provider or registered model route.
- Environment and project.
- Feature or task.
- Organization or funded pool.
- Request, hour, day, billing period, or other approved window.
- Spend amount, native usage, attempt count, concurrency, or quota fact.

Provider caps are never shown as user token quotas and do not create provider
entitlements. When a cap prevents a route:

- The Budget Controller denies or bounds that candidate route.
- The Orchestrator may select another independently approved route only if all
  safety, data, capability, deadline, feature, entitlement, and budget checks
  succeed.
- The Gateway and adapter do not choose a cheaper provider themselves.
- No fallback may exceed the logical reservation without pre-execution
  authorization.

Exact cap dimensions, amounts, warning thresholds, owners, and reset windows
remain open.

### Relationship to infrastructure budgets

Request-level Budget Controller decisions are separate from GCP project
budgets and alerts in ADR-018. Both are required controls:

- Project budgets detect or bound aggregate platform spend.
- The Budget Controller authorizes a particular AI request or attempt.
- Neither substitutes for immutable usage accounting or incident kill
  switches.

## Subscription and entitlement integration

### Separate questions

| Component | Question answered |
|---|---|
| Subscription or compatibility policy | Which approved commercial or launch state applies? |
| Entitlement service | May this actor use this NAJM capability/service level? |
| AI Credit service | Which approved account or pool can reserve the required NAJM AI Credits? |
| Budget Controller | May this request consume the proposed internal cost and credit ceiling now? |
| Feature/safety/incident policy | May AI execute under current operational and aviation constraints? |

All required answers must allow. No subscription, entitlement, balance, or
credit grant can bypass another denial.

### Free/Pro compatibility

- Current Free/Pro scaffolding remains unchanged.
- The subscriptions-disabled Free-launch behavior remains an explicit
  compatibility policy.
- Existing daily and monthly counters remain compatibility mechanisms until a
  later migration.
- Compatibility may reproduce current access and limit behavior, but it does
  not convert counters into credits or a ledger.
- No current user gains or loses access because this document exists.
- This document creates no new tier, price, quota, trial, referral, grant,
  purchase, or renewal behavior.

### Billing preparation without payment integration

The target prepares for future billing through provider-neutral interfaces:

- A validated external commerce event may request an idempotent credit grant,
  entitlement update, expiry, revocation, refund, or dispute adjustment.
- External product IDs, receipts, webhooks, store status, and payment
  credentials remain inside the future billing/subscription boundary.
- The credit service accepts only authorized normalized instructions and
  appends immutable transactions.
- Replayed or reordered external events cannot duplicate grants or refunds.
- A billing-system outage cannot authorize direct provider execution.
- Product prices, taxation, store commissions, invoicing, and refund promises
  require separate owner and finance/legal approval.

Nothing here implements or selects Stripe, RevenueCat, Paddle, app-store
purchases, or enterprise invoicing.

## Admin overrides, emergency credits, refunds, and disputes

### Admin credit overrides

An authorized admin action may later request a grant, deduction, reservation
release, budget ceiling change, pool allocation, expiry correction, or
goodwill adjustment. Every action requires:

- Authenticated administrator identity and server-verified privilege.
- Target account/pool, amount or bounded policy effect, and effective period.
- Stable reason code, human-readable justification, and support/incident case
  reference where applicable.
- Idempotency key and semantic fingerprint.
- Approval evidence and dual-control evidence when required by policy.
- Immutable credit transaction and audit event references.
- Expiry or revocation semantics for temporary effects.

An admin cannot edit an existing ledger event or set a balance directly.

### Emergency credits and budget override

Emergency credits are explicit, temporary, auditable grants. An emergency
budget override is a break-glass Budget Decision with bounded scope and
expiry. Neither is an invisible bypass.

Emergency handling:

- May address only the credit or budget denial explicitly authorized.
- Must occur before new provider execution.
- Must still produce a reservation or explicit non-billable authorization.
- Cannot bypass authentication, authorization, feature flags, entitlement,
  deterministic aviation authority, safety, data policy, registry approval,
  provider incident controls, or global kill switches.
- Must create high-priority audit evidence and later review.

Exact roles, approval count, maximum amount, duration, and review deadline
remain open.

### Refunds and disputes

- A refund or upheld dispute creates a compensating `RefundAdjustment` and
  credit transaction linked to the original charge.
- The original reservation, usage, charge, cost, and policy events remain
  unchanged.
- Opening a dispute records a case event and may place future collection or
  account action under policy; it does not erase usage.
- A denied dispute records the decision and evidence without adding a credit
  movement unless another adjustment is authorized.
- External payment refunds and internal credit refunds are distinct facts and
  must be linked without assuming a one-to-one monetary value.
- Refund eligibility, time windows, cash treatment, and external billing
  behavior are not approved here.

## Idempotency requirements

Idempotency is required at every boundary that can spend provider budget or
change credits.

### Required identifiers

- **Logical request ID:** one product-level AI operation.
- **Product idempotency key:** stable across client or service retries of that
  operation.
- **Attempt ID:** unique for each provider-route attempt beneath the logical
  request.
- **Reservation ID:** stable for the logical funding authorization.
- **Credit transaction ID:** unique immutable financial effect.
- **Usage ledger event ID:** unique immutable operational/accounting fact.
- **External event ID:** future billing, refund, or invoice event identifier.
- **Admin action ID:** unique governed override or support action.

### Behavioral requirements

- Replaying the same key and same semantic fingerprint returns or resumes the
  prior outcome; it does not create another provider call, reservation,
  debit, grant, refund, or event.
- Reusing a key with a different actor, account, feature, amount, policy,
  product transaction, or semantic payload fails as a conflict.
- Reservation, amendment, provider execution, reconciliation, release,
  adjustment, refund, and admin action each have deduplication protection.
- Same-route transport retry uses the attempt’s provider-safe idempotency
  context where supported.
- Fallback uses a new attempt ID but the same logical request and customer
  charge scope.
- An uncertain provider outcome blocks unsafe duplicate execution until the
  Orchestrator can prove retry safety or authorize a new attempt without
  double charge.
- Exactly-once business effect is required even when delivery is at least
  once.
- Idempotency records must outlive every applicable retry, reservation,
  reconciliation, refund, dispute, and external-event window.

## Audit-event requirements

Every material policy or financial action produces compact, immutable audit
evidence containing, as applicable:

- Audit ID, logical request ID, attempt IDs, reservation ID, transaction IDs,
  and ledger event IDs.
- Authenticated actor, organization/pool scope, and authorization-decision
  reference.
- Feature flag, entitlement, safety, incident, budget, credit, burn-rate,
  prompt, provider, model, adapter, and pricing-policy versions.
- Estimate, reservation ceiling, native usage-fact references, cost state,
  final credit charge, released amount, and adjustment links.
- Action/result type, stable reason code, occurred time, recorded time, and
  correlation/trace identifiers.
- For administration: admin identity, verified privilege, target, reason,
  case reference, approval evidence, effective time, expiry, and review state.
- For disputes or refunds: original event reference, case status, decision,
  evidence reference, and compensating event.

Audit records must exclude:

- Provider API keys, authorization headers, service tokens, Firebase tokens,
  roster credentials, secret-bearing URLs, or payment credentials.
- Raw provider requests/responses, raw prompts, model output, retrieved
  passages, memory contents, or roster data by default.
- Raw receipts or unnecessary user and organization PII.

Access to internal provider cost and margin facts is separately authorized
from user credit support access.

## Data-retention requirements

Immutability does not mean retaining every field forever. Each event or model
has a versioned retention class approved for its legal, finance, dispute,
security, privacy, and operational purpose.

Required retention principles:

- Retain immutable credit and billing effects long enough to support the
  applicable accounting, refund, dispute, tax, audit, and legal obligations.
- Retain idempotency evidence for at least the longest applicable replay,
  reconciliation, refund, dispute, external-event, and late-provider-usage
  window.
- Retain provider usage and cost provenance long enough for invoice
  reconciliation and anomaly investigation.
- Retain estimate, reservation, charge, release, refund, and adjustment
  linkages as one reconstructable chain.
- Store compact identifiers, quantities, classifications, versions, hashes,
  and reason codes; avoid prompt and response content.
- Apply least-privilege access, environment isolation, encryption, backup,
  legal-hold, archive, and deletion evidence appropriate to the retention
  class.
- On account deletion, remove or de-identify personal fields when permitted
  while preserving legally required accounting integrity and adjustment
  linkage.
- Legal hold suspends eligible deletion through an audited policy event; it
  does not mutate ledger history.
- Derived dashboards and caches may have shorter retention and remain
  rebuildable from authorized source events.

Exact durations, legal bases, regions, archive tiers, de-identification
method, and legal-hold roles remain open for owner, privacy, finance, and legal
approval.

## Failure and fallback semantics

| Scenario | Required target behavior |
|---|---|
| Insufficient credits | Deny before provider execution with a stable provider-neutral reason; do not revoke the entitlement or reveal provider units |
| Budget or quota cap reached | Deny or bound the route before execution; the Orchestrator may consider another independently approved route only through a new valid decision |
| Reservation timeout | Start no new execution after expiry; release only when execution is known not to have occurred, otherwise enter pending accounting |
| Provider failure after reservation | Preserve known zero, partial, actual, or uncertain usage; reconcile or release according to evidence and burn policy, never HTTP status alone |
| Provider success but ledger append fails | Preserve reservation and provider result/recovery reference, mark accounting unresolved, do not repeat provider execution, alert, and resume idempotent append/reconciliation before financial finalization |
| Reconciliation mismatch | Preserve estimate, reservation, provider usage, reported cost, final charge, and variance; append correction or investigation events rather than overwriting |
| Idempotency replay | Return or resume the existing logical and financial outcome; reject a mismatched semantic fingerprint |
| Fallback provider after reservation | Use a new attempt ID under the same logical charge scope; reauthorize before execution if the existing budget or reservation is insufficient |
| Usage or cost uncertain | Preserve uncertainty, hold bounded capacity under policy, prevent unsafe duplicate execution, and resolve through later facts or authorized adjustment |
| Non-billable internal-alpha traffic | Require explicit classification and Budget Decision; create no user debit, but retain request, attempt, usage, internal-cost, idempotency, and audit provenance where available |
| Cache-served outcome | Follow a versioned provider-neutral burn policy; exact charge remains an open commercial decision, and provider usage must not be fabricated |
| Deterministic-only or safety-denied outcome | Preserve deterministic/safety provenance and follow approved zero-or-other burn policy; credits never weaken the safety outcome |
| Emergency bypass request | Permit only an authorized, scoped, expiring budget/credit override before execution; all other policy controls still apply |
| Disputed charge | Preserve original events, record dispute state, and append the approved resolution or compensating adjustment |
| Admin override | Require verified privilege, reason, evidence, idempotency, bounded scope, immutable transaction, and audit event |
| Quota reset | Begin a new period or allocation through policy/event state; retain historical consumption and prior-period evidence |
| Balance projection disagreement | Fail closed for new billable reservations or enter accounting unavailable; repair the projection from immutable events |
| AI Platform unavailable | Preserve independent deterministic product behavior where authorized; never call a provider directly as fallback |

Exact user-response handling after provider success but accounting persistence
failure remains feature-specific and open. It must still preserve the no-repeat,
no-silent-charge, and eventual-reconciliation invariants above.

## Proposed normalized models

These are conceptual field groups, not implementation classes, Firestore
documents, APIs, or approved collection names. Exact field names, types,
indexes, atomicity mechanism, and storage belong to later approved design.

### `AICreditAccount`

| Field group | Required meaning |
|---|---|
| Identity | Stable account ID and immutable account-version reference |
| Owner scope | Authenticated user or approved organization scope; no provider identity |
| Account class | Individual, internal-alpha, family member, corporate member, enterprise member, promotional, or other approved class |
| Lifecycle | Proposed/active/suspended/closed semantics, effective time, reason, and policy version |
| Funding relationship | Approved pool/allocation references and deduction-precedence policy reference |
| Restrictions | Feature, service-level, environment, expiry, and transfer restrictions |
| Projection | Available, reserved, consumed, expired, and disputed credit views with reconciliation status |
| Governance | Created-by source, authorization evidence, timestamps, and audit references |
| Retention/integrity | Retention class, schema version, content/version integrity metadata |

### `AICreditPool`

| Field group | Required meaning |
|---|---|
| Identity | Stable pool ID, pool class, and immutable policy version |
| Sponsor/owner | Approved individual, family, corporate, enterprise, promotional, or internal sponsor scope |
| Allocation | Total granted credits, funding-source references, effective/expiry periods, and restrictions |
| Membership | Authorized account/allocation references and membership-policy version |
| Limits | Pool, child-allocation, feature, member, and time-window quota references |
| Projection | Available, reserved, consumed, allocated, reclaimed, expired, and disputed views |
| Lifecycle | Active, suspended, exhausted, expired, or closed semantics and reason |
| Governance/integrity | Authorization, audit, retention, schema, and integrity references |

### `AICreditReservation`

| Field group | Required meaning |
|---|---|
| Identity | Reservation ID, logical request ID, product idempotency scope, and semantic fingerprint |
| Funding | Complete authorized account/pool source set and applicable allocation references; split-funding policy remains unresolved |
| Authorization | Budget Decision, entitlement, feature, safety, incident, and credit-policy references |
| Amount | Requested and authorized maximum NAJM AI Credits; no provider-native units as user value |
| Estimate | CostEstimate and burn-policy references used before execution |
| Attempts | Authorized attempt/fallback limits and related attempt IDs |
| Lifecycle | Request, active hold, amendment, pending reconciliation, release, expiry, dispute, and close semantics |
| Time | Created/effective/expiry/reconciled timestamps and reservation TTL policy reference |
| Outcome | Final charge, release, pending amount, transaction IDs, and ledger event references |
| Integrity | Version, idempotency result, audit, and retention metadata |

### `AICreditTransaction`

| Field group | Required meaning |
|---|---|
| Identity | Globally unique immutable transaction ID and event type |
| Account effect | Account/pool, direction, NAJM AI Credit amount, and postable category |
| Source/reason | Allocation, reservation, consumption, release, transfer, expiry, adjustment, refund, dispute, or override reason |
| Correlation | Logical request, reservation, usage event, external event, admin action, and original transaction references |
| Policy | Credit, burn-rate, allocation, refund, or override policy versions |
| Time | Occurred, recorded, effective, and optional expiry time |
| Authorization | Actor/system authority, decision reference, and approval evidence |
| Integrity | Idempotency key/fingerprint, schema version, sequence/integrity metadata, and retention class |

### `AIUsageLedgerEvent`

| Field group | Required meaning |
|---|---|
| Identity | Immutable event ID, event family/type, schema version, and integrity metadata |
| Correlation | Logical request, product transaction, attempt, reservation, credit transaction, trace, and audit IDs |
| Actor/scope | Minimized user/account/organization references and environment |
| Capability | NAJM feature, task, service level, outcome, and reason code |
| Policy provenance | Feature, entitlement, safety, incident, budget, credit, burn-rate, prompt, route, and retention versions |
| Execution provenance | Provider/model/adapter registry keys and revisions, provider request ID, and attempt status |
| Usage/cost | ProviderUsageFact, CostEstimate, CostReconciliation, and uncertainty references |
| Credit effect | Reserved, charged, released, adjusted, and refunded amounts plus transaction references |
| Time/retention | Occurred/recorded times, retention class, legal-hold state reference, and de-identification status |

### `ProviderUsageFact`

| Field group | Required meaning |
|---|---|
| Identity | Immutable usage-fact ID, request/attempt IDs, source, and schema version |
| Route | Provider, model, adapter, and registry revision references kept internal |
| Native usage | Labeled quantities exactly as reported or derived, including applicable input/output/cache/reasoning/embedding/modality units |
| Certainty | Known-zero, known, partial, estimated, delayed, or uncertain classification and reason |
| Provider evidence | Provider request ID, usage-report source, and reported time without raw payload retention |
| Cost linkage | Pricing-fact, reported-cost, estimate, and reconciliation references |
| Integrity/retention | Content hash or equivalent integrity evidence, retention class, and audit link |

### `CostEstimate`

| Field group | Required meaning |
|---|---|
| Identity | Estimate ID, logical request/attempt candidate, and immutable version |
| Route assumptions | Provider/model/adapter/prompt versions and capability |
| Usage assumptions | Expected and maximum native units, tool/fallback/retry assumptions, and output/context ceilings |
| Pricing | Effective-dated pricing-fact reference, currency, and completeness status |
| Amount | Expected internal cost and conservative ceiling; never a user price |
| Quality | Confidence, estimation method/version, known limitations, and expiry |
| Policy linkage | Budget and burn-policy versions informed by the estimate |
| Audit/retention | Created time, source, audit reference, and retention class |

### `CostReconciliation`

| Field group | Required meaning |
|---|---|
| Identity | Reconciliation ID, version, and idempotency key |
| Scope | Logical request, attempt, provider billing period, invoice allocation, or other approved scope |
| Inputs | CostEstimate, ProviderUsageFact, pricing-fact, provider-reported cost, and invoice references |
| Results | Estimated, reported, and invoice-reconciled amounts/currencies kept separately |
| Variance | Amount/reason, completeness, uncertainty, and investigation status |
| Credit relationship | Final credit charge and any separately approved customer-adjustment reference |
| Lifecycle | Pending, provisional, reconciled, disputed, corrected, or closed semantics |
| Audit/retention | Source, actor/system, timestamps, adjustment links, integrity, and retention class |

### `BudgetDecision`

| Field group | Required meaning |
|---|---|
| Identity | Decision ID, immutable policy version, logical request, and evaluation time |
| Scope | Actor/account/pool/organization, environment, feature, task, and candidate route |
| Result | Allow, deny, or bounded allow with stable reason codes |
| Ceilings | Internal cost, NAJM AI Credit reservation, attempts, fallback, tool, context, output, and deadline limits |
| Cap provenance | Applicable provider, route, feature, account, pool, environment, and time-window cap references |
| Inputs | Entitlement/feature/safety/incident decisions, CostEstimate, availability, and credit-policy references |
| Validity | Effective/expiry time and re-evaluation conditions |
| Override | Optional authorized admin/emergency decision reference; never an implicit bypass |
| Audit/integrity | Evaluation fingerprint, actor/system, schema, retention, and audit references |

### `MarginSnapshot`

| Field group | Required meaning |
|---|---|
| Identity/scope | Snapshot ID and request, account, product, organization, or period scope |
| Credit facts | Credits allocated, reserved, consumed, adjusted, and refunded as separate service units |
| Revenue facts | Approved allocated gross/net revenue references, if any; never inferred from credits alone |
| Cost facts | Estimated, reported, and invoice-reconciled provider cost plus approved variable-cost allocations |
| Commercial adjustments | Discounts, grants, refunds, disputes, commissions, tax, and FX references when separately approved |
| Result | Named gross/contribution margin measures with formula/policy version |
| Completeness | Estimated/provisional/reconciled status, confidence, missing facts, and variance |
| Time/audit | Effective period, computed time, source-event cutoff, audit, integrity, and retention metadata |

### `AdminCreditOverride`

| Field group | Required meaning |
|---|---|
| Identity | Admin action ID and idempotency fingerprint |
| Administrator | Authenticated admin, verified privilege, organization scope, and approval evidence |
| Target | Account, pool, reservation, quota, or Budget Decision affected |
| Effect | Grant, deduction, release, allocation, expiry correction, bounded budget override, or other approved type and amount |
| Reason/evidence | Stable reason, human justification, case/incident reference, and supporting evidence reference |
| Validity | Requested/effective/expiry times and review deadline |
| Controls | Dual-control status, policy limits, conflict result, and revocation path |
| Outcome | Immutable transaction, Budget Decision, ledger, and audit event references |
| Retention/integrity | Schema version, integrity metadata, and retention class |

### `RefundAdjustment`

| Field group | Required meaning |
|---|---|
| Identity | Adjustment ID, idempotency key, and adjustment type |
| Original facts | Original charge, reservation, usage event, credit transaction, and external commerce references |
| Case | Refund/dispute/support case ID, status, reason, and evidence references |
| Effect | Compensating NAJM AI Credit amount and separately recorded external monetary effect when applicable |
| Decision | Authorized outcome, decision maker, policy version, and approval evidence |
| Lifecycle | Requested, pending, approved, denied, applied, reversed, or closed semantics |
| Outcome | New immutable transaction and ledger/audit event references; original events unchanged |
| Time/retention | Requested/decided/applied times, retention class, integrity, and legal-hold reference |

### `EnterpriseAllocation`

| Field group | Required meaning |
|---|---|
| Identity | Allocation ID, enterprise/organization scope, parent pool, and policy version |
| Beneficiary | Child pool, account, member, team, or cost-center reference |
| Authorization | Contract/entitlement reference, delegated admin authority, and approval evidence |
| Allocation | Credit ceiling, effective period, expiry, reclaim, and rollover policy references |
| Restrictions | Feature/service-level, member, geography/data, and time-window constraints when approved |
| Chargeback | Internal organization cost-center or reporting labels; no provider-native user quota |
| Projection | Allocated, reserved, consumed, remaining, disputed, and reclaimed views |
| Lifecycle | Proposed, active, suspended, expired, reclaimed, or closed semantics |
| Audit/retention | Admin actions, immutable transaction references, schema, integrity, and retention class |

`EnterpriseAllocation` is an architecture target only and is not an MVP
requirement or an approved commercial product.

## Architectural decisions

### AI-CB-001 — Users consume NAJM AI Credits, not provider tokens

- **Decision:** NAJM AI Credits are the only user-facing AI consumption unit;
  provider-native units and costs remain internal facts.
- **Rationale:** Provider-neutral consumption prevents commercial/API lock-in
  and lets NAJM change approved routes without changing customer contracts.
- **Alternatives considered:** Expose provider tokens; provider-branded quotas;
  pass through each provider invoice unit.
- **Accepted trade-offs:** NAJM must govern and explain its own versioned burn
  policy independently of provider pricing.
- **Security impact:** Clients cannot manipulate provider parameters or infer
  secret routing from quota units.
- **Cost impact:** Provider price changes are managed internally rather than
  silently becoming user charges.
- **Scalability impact:** One credit vocabulary spans GLM, Claude, OpenAI,
  Gemini, DeepSeek, Qwen, and future adapters.
- **Migration impact:** Legacy counters remain until migrated; they cannot be
  relabeled as provider-token balances.
- **Implementation priority:** Must implement before any paid launch and must
  govern any alpha credit display.

### AI-CB-002 — Credit reservation before provider execution

- **Decision:** Every budget-governed billable request obtains an atomic,
  idempotent credit reservation before the Gateway may execute a provider
  attempt; explicitly non-billable alpha traffic requires a recorded
  authorization instead.
- **Rationale:** Pre-authorization prevents overspend, negative surprises, and
  concurrent double use of the same balance.
- **Alternatives considered:** Debit only after response; let each Product API
  decrement a counter; allow provider calls while balance is checked later.
- **Accepted trade-offs:** Reservation expiry, pending state, and recovery add
  workflow complexity.
- **Security impact:** Prevents replay and concurrency abuse from spending
  beyond approved capacity.
- **Cost impact:** Bounds provider spend before it occurs.
- **Scalability impact:** Requires atomic or equivalently durable reservation
  semantics across workers.
- **Migration impact:** Existing daily counters continue as legacy behavior
  until a later controlled migration.
- **Implementation priority:** Advisory/non-billable authorization before
  internal alpha; enforced reservation before paid launch.

### AI-CB-003 — Post-execution reconciliation against actual provider usage

- **Decision:** Every execution reconciles the reservation using preserved
  native usage, uncertainty, outcome, and the applicable provider-neutral burn
  policy.
- **Rationale:** Estimates differ from actual input, output, tools, retries,
  partial streams, and fallback attempts.
- **Alternatives considered:** Always charge the reserved maximum; trust only
  the provider invoice; ignore failed-attempt usage.
- **Accepted trade-offs:** Reconciliation can remain pending while provider
  usage is delayed or uncertain.
- **Security impact:** Prevents both silent overcharge and manipulation that
  converts uncertain usage to zero.
- **Cost impact:** Releases unused credits and preserves actual internal spend
  for reporting.
- **Scalability impact:** Attempt facts and logical-request reconciliation can
  process asynchronously while preserving one financial outcome.
- **Migration impact:** Legacy paths require captured usage facts before paid
  migration.
- **Implementation priority:** Usage-fact capture before internal alpha;
  enforced reconciliation before paid launch.

### AI-CB-004 — Immutable ledger is the billing and audit source of truth

- **Decision:** Credit and AI usage effects are append-only immutable events;
  balances, statements, and reports are rebuildable projections.
- **Rationale:** Billing support, refunds, disputes, incidents, and finance
  require reproducible history.
- **Alternatives considered:** Mutable balance only; daily counter as ledger;
  overwrite the original charge after correction.
- **Accepted trade-offs:** More compact event storage and projection
  reconciliation are required.
- **Security impact:** Tampering and unauthorized historical edits become
  detectable and preventable.
- **Cost impact:** Adds small write/storage cost while materially reducing
  dispute and investigation cost.
- **Scalability impact:** Append-only event partitions and derived views scale
  independently.
- **Migration impact:** Existing counters remain separate compatibility data
  and are not imported as invoice-grade facts without evidence.
- **Implementation priority:** Ledger event design and alpha provenance before
  internal alpha; dispute-grade ledger before paid launch.

### AI-CB-005 — Budget Controller is an Orchestrator policy component during MVP

- **Decision:** The Budget Controller remains a logical policy component under
  Orchestrator coordination during MVP; service separation requires later
  approval.
- **Rationale:** Central policy ordering is required now, while a separate
  deployment has no demonstrated scale benefit.
- **Alternatives considered:** Independent billing microservice at MVP;
  provider adapter decides affordability; Product APIs enforce their own caps.
- **Accepted trade-offs:** Clear internal interfaces must be maintained inside
  the initial FastAPI deployment.
- **Security impact:** One deny-dominant policy path prevents modules from
  bypassing budget authorization.
- **Cost impact:** Avoids premature operational infrastructure and network
  overhead.
- **Scalability impact:** The logical contract permits later separation without
  changing Product APIs.
- **Migration impact:** Current modules remain unchanged in Phase 1; later AI
  use cases integrate through the Orchestrator.
- **Implementation priority:** Must implement as a logical boundary before
  internal-alpha provider execution.

### AI-CB-006 — Provider cost and user credit burn are separate concepts

- **Decision:** Effective-dated provider cost facts and provider-neutral credit
  burn policy are stored, versioned, and reconciled separately.
- **Rationale:** Provider cost varies by route and contract, while customer
  value and product policy must remain stable and provider-independent.
- **Alternatives considered:** One credit equals one provider token; direct
  cost pass-through; adapter calculates the customer charge.
- **Accepted trade-offs:** Margin reporting requires explicit revenue, credit,
  and cost mappings.
- **Security impact:** Internal cost and provider routing remain restricted
  from ordinary clients and support roles.
- **Cost impact:** Enables accurate margin analysis and controlled policy
  changes without automatic repricing.
- **Scalability impact:** New providers and unit vocabularies do not change
  user contracts.
- **Migration impact:** The Claude-specific cost model remains a planning
  artifact and cannot seed target burn rates automatically.
- **Implementation priority:** Separation applies before internal alpha;
  finance-grade reconciliation is required before paid launch.

### AI-CB-007 — Idempotency prevents duplicate charge and ledger effects

- **Decision:** Logical requests, attempts, reservations, transactions,
  reconciliation, releases, grants, refunds, and overrides use durable
  idempotency and semantic-fingerprint checks.
- **Rationale:** Client retries, worker restarts, fallbacks, webhook replay, and
  timeouts otherwise create duplicate spend or credits.
- **Alternatives considered:** Best-effort duplicate checks; provider request
  IDs only; trust clients not to retry.
- **Accepted trade-offs:** Idempotency records require retention and conflict
  handling.
- **Security impact:** Prevents replay-based balance manipulation and duplicate
  admin effects.
- **Cost impact:** Avoids duplicate provider calls, charges, grants, and
  refunds.
- **Scalability impact:** Stable keys make at-least-once delivery safe across
  workers and later services.
- **Migration impact:** Legacy calls need compatibility keys before they can
  join the target ledger.
- **Implementation priority:** Must implement before internal alpha.

### AI-CB-008 — Free/Pro legacy counters remain compatibility mechanisms

- **Decision:** Existing Free/Pro scaffolding, subscriptions-disabled behavior,
  and daily/monthly counters remain current compatibility mechanisms until
  migrated; they are not the target credit ledger.
- **Rationale:** Phase 1 cannot change runtime behavior, and relabeling weak
  counters would create false accounting confidence.
- **Alternatives considered:** Replace counters in documentation; infer credit
  balances from counts; enable subscription enforcement now.
- **Accepted trade-offs:** Legacy and target concepts coexist explicitly during
  a later compatibility period.
- **Security impact:** Prevents unsupported counters from authorizing paid
  provider spend.
- **Cost impact:** No commercial or runtime change in Milestone 3.
- **Scalability impact:** A later compatibility adapter can isolate legacy
  sources without contaminating the immutable ledger.
- **Migration impact:** Migration must preserve current access until separately
  approved and validated.
- **Implementation priority:** Binding throughout migration.

### AI-CB-009 — Family, corporate, and enterprise pools are targets, not MVP requirements

- **Decision:** The architecture supports governed shared pools and allocations,
  but MVP requires no family, corporate, or enterprise commercial behavior.
- **Rationale:** Stable scope identifiers and isolation avoid redesign while
  preventing premature product complexity.
- **Alternatives considered:** Individual accounts only forever; build full
  enterprise billing at MVP; let organization admins edit balances directly.
- **Accepted trade-offs:** Future pool policy remains open and cannot be used
  until explicitly approved.
- **Security impact:** Tenant isolation, membership authorization, and bounded
  delegation are mandatory before shared-pool use.
- **Cost impact:** No deferred organization feature incurs runtime or support
  cost now.
- **Scalability impact:** Parent/child allocation concepts support later
  organization growth without provider-branded quotas.
- **Migration impact:** Current Free/Pro users remain individual compatibility
  subjects; no organization inference is made.
- **Implementation priority:** Deferred until an approved product need; only
  stable scope/correlation fields are needed earlier.

### AI-CB-010 — Refunds and disputes use compensating events

- **Decision:** Refunds, dispute outcomes, and corrections append linked
  compensating events; original ledger events are never mutated.
- **Rationale:** Historical truth must show the original charge and why it was
  later adjusted.
- **Alternatives considered:** Edit or delete the charge; reset the account
  balance manually; keep disputes only in external billing notes.
- **Accepted trade-offs:** Statements and reports must present linked original
  and compensating events.
- **Security impact:** Prevents support or admin users from hiding historical
  usage and financial actions.
- **Cost impact:** Supports accurate refund, revenue, cost, and margin
  reporting.
- **Scalability impact:** Append-only adjustments handle retries and external
  event ordering cleanly.
- **Migration impact:** Legacy support actions require explicit opening
  balances or compatibility evidence rather than rewritten history.
- **Implementation priority:** Required before paid launch; conceptual event
  shape required before internal alpha.

## Security considerations

- Only authenticated server-side components may request a Budget Decision,
  reservation, reconciliation, grant, refund, or override.
- Clients, Product APIs, domain engines, prompts, tools, Gateways, and adapters
  cannot write balances or ledger events directly.
- Provider secrets remain adapter-scoped and never enter accounting records.
- Provider-native usage and cost are internal, least-privilege business data;
  users receive only NAJM AI Credit and provider-neutral outcome facts.
- Account and pool access is tenant-isolated and derived from verified actor
  and organization authorization.
- Balance availability and ledger append use atomic or equivalently durable
  concurrency control to prevent double spend.
- Admin and emergency actions require server-verified privilege, bounded
  scope, reason, evidence, idempotency, expiry, and immutable audit.
- Separation of duties applies between commercial policy, credit support,
  provider-cost finance access, and ledger administration; exact roles remain
  open.
- Raw prompts, model outputs, roster details, payment credentials, receipts,
  and unnecessary PII are excluded from ledger and audit by default.
- No financial or credit control may weaken deterministic aviation authority,
  safety classification, grounding, or abstention requirements.

## Cost considerations

- Budget, feature, entitlement, and safety checks should occur before
  expensive context assembly or provider execution where policy permits.
- Every request bounds context, output, tools, retries, fallbacks, concurrency,
  deadline, internal cost, and reservable credits.
- Provider cost facts are effective-dated and preserve currency, unit
  vocabulary, estimate quality, and uncertainty.
- Non-billable alpha traffic still consumes internal provider budget and must
  be measurable.
- Ledger and audit events retain compact facts and references rather than
  token-heavy prompt or response bodies.
- Derived cost and margin reporting may be asynchronous; reservation and
  no-double-spend decisions remain on the pre-execution path.
- The current cost model must be rebuilt from observed usage and current
  vendor facts before it informs production budgets or margin reporting.
- No provider-specific commitment, discount, or routing optimization is
  approved by this document.

## Scalability considerations

- Logical request, attempt, reservation, transaction, and event identifiers
  support partitioned append-only processing.
- Balance projections avoid scanning an entire ledger on every request but
  remain reconcilable to immutable events.
- Hot shared pools require atomic allocation controls, bounded contention,
  and tenant-safe partitioning before organization launch.
- Idempotency and reconciliation survive retries, worker changes, and later
  service separation.
- Provider usage and invoice reconciliation may arrive asynchronously or in
  batches without changing original events.
- Cost/margin analytics do not belong on the synchronous provider-response
  path beyond required durable facts.
- The Budget Controller and AI Credit service remain logical components in the
  MVP deployment; physical separation requires measured throughput,
  availability, or isolation need.
- BigQuery export, a PostgreSQL ledger, and complex enterprise chargeback are
  deferred until scale or reporting needs justify them.

## Migration considerations

- Milestone 3 changes no runtime behavior.
- Existing Free/Pro, subscriptions-disabled, `aiUsage`, `usageCounters`, and
  `rateLimits` behavior remains current compatibility state.
- Existing direct Anthropic/OpenAI paths remain legacy debt and are not
  redirected.
- A later migration must inventory each counter, limit source, reset window,
  tier interpretation, caller, concurrency behavior, and deletion path before
  deciding compatibility mappings.
- Legacy counts cannot become monetary or credit opening balances without an
  explicit, evidenced, owner-approved policy.
- Each migrated AI use case must gain provider-neutral idempotency, Budget
  Decision, reservation/non-billable authorization, attempt usage facts,
  reconciliation, and immutable events behind its existing Product API.
- Public API, authentication, Firebase claims, service-token boundary, and
  current product behavior remain backward-compatible until an approved cutover.
- Rollback returns the feature to its accepted prior application path while
  preserving all ledger, reservation, usage, and adjustment facts already
  created.
- Storage schema, Firestore collections, migrations, and the detailed runtime
  sequencing are not decided in this milestone.

## Delivery classification

This classification states target requirements. It is not a runtime
implementation plan and does not assert that any item exists today.

### Must implement before internal alpha

- Normalized ledger, usage-fact, cost-estimate, and audit event design for
  every alpha-admitted AI capability.
- Explicit non-billable or advisory accounting classification for alpha
  traffic, including the funding/budget owner and validity.
- Logical request, attempt, reservation/authorization, and ledger idempotency
  requirements.
- Versioned `BudgetDecision` shape and bounded provider/feature/environment
  spend policy for admitted routes.
- Provider usage-fact capture with known/partial/uncertain classification.
- Clear compatibility handling for existing Free/Pro,
  subscriptions-disabled, and daily/monthly counters.
- Deny-dominant composition with feature flags, entitlement, aviation safety,
  registries, prompts, and kill switches.
- No customer credit debit unless paid-launch controls are separately approved
  and complete.

### Must implement before paid launch

- Enforced atomic credit balances and pre-execution reservations.
- Post-execution reconciliation, release, uncertain-usage handling, and
  fallback accounting.
- Immutable credit transactions and AI usage ledger with dispute-grade
  provenance.
- User and approved pool quotas with exact policy, expiry, reset, and
  precedence rules.
- Versioned credit burn policies and customer-visible NAJM AI Credit statements.
- Effective-dated provider pricing facts, provider-reported usage, and
  invoice-grade cost reconciliation.
- Refund, compensating adjustment, dispute, and quota-reset events.
- Least-privilege admin override and emergency-credit controls with audited
  approval and expiry.
- Billing-event replay protection and authoritative mapping from separately
  approved commercial products to entitlements and credit grants.
- Cost and margin reporting with approved revenue, cost, tax/commission,
  refund, and allocation policies.
- Approved retention, deletion/de-identification, archive, legal-hold,
  reconciliation, and support procedures.

### Deferred until scale justifies it

- PostgreSQL ledger migration.
- BigQuery analytics export.
- Enterprise invoicing automation.
- Real-time cost optimization across providers.
- Advanced organization-level chargeback.
- Multi-currency commercial pricing.
- Family/corporate/enterprise self-service pool administration.
- Complex rollover, transfer marketplace, or delegated allocation rules.
- Physically separate Budget Controller or AI Credit service deployments.
- Automated invoice ingestion across a large provider catalog.

## Open questions

The following remain unresolved and require explicit later approval:

- Exact credit denomination, numeric burn rates, customer prices, included
  allocations, and rounding.
- Fixed feature burn versus policy-derived burn, including cached,
  deterministic-only, tool, partial, blocked, failed, and uncertain outcomes.
- Reservation TTL, amendment, renewal, overage, negative-balance, late-usage,
  expiry, and pending-accounting rules.
- Which capabilities, if any, enter internal alpha and whether all alpha
  traffic is non-billable.
- Pool selection, deduction precedence, allocation, transfer, reclaim,
  rollover, and expiry policy.
- Individual, family, corporate, and enterprise quota periods, inheritance,
  membership, delegation, and chargeback.
- Budget-cap dimensions, numeric thresholds, reset windows, warning levels,
  owners, and escalation by request, feature, route, provider, environment,
  organization, and time window.
- Provider-reported versus invoice-reconciled cost authority, timing,
  tolerance, and late-adjustment treatment.
- Currency, foreign exchange, tax, store commission, revenue recognition,
  and margin-allocation policy.
- Whether margin snapshots are request-, account-, product-, organization-,
  or period-scoped.
- Admin roles, separation of duties, dual-control thresholds, maximum
  emergency grant, override expiry, and review deadlines.
- Refund/dispute eligibility, customer communication, external billing
  mapping, and cash-versus-credit treatment.
- Exact retention periods, legal bases, data regions, de-identification,
  archival, deletion evidence, and legal-hold authority.
- Exact persistence technology, transaction/atomicity protocol, event ordering,
  collection/table names, schema serialization, indexes, and integrity method.
- Opening-balance and compatibility treatment for legacy counters, if any.
- Exact user response after provider success when accounting persistence is
  temporarily unavailable.

## References

- [AI Platform Overview](AI_PLATFORM_OVERVIEW.md)
- [AI Orchestrator](AI_ORCHESTRATOR.md)
- [AI Gateway and Provider Adapters](AI_GATEWAY_AND_PROVIDER_ADAPTERS.md)
- [AI Provider and Model Registries](AI_REGISTRIES.md)
- [Prompt Registry](PROMPT_REGISTRY.md)
- [AI Feature Flags and Entitlements](AI_FEATURE_FLAGS_AND_ENTITLEMENTS.md)
- [NAJM Master Project Directive](../../NAJM_MASTER_PROJECT_DIRECTIVE.md)
- [Current NAJM Architecture](../../NAJM_ARCHITECTURE.md)
- [Architecture Lock](../ARCHITECTURE_LOCK.md)
- [Infrastructure Cost Model — planning context only](../cost-model.md)
- [Secrets Management](../SECRETS.md)
- [Current subscription models — legacy behavior evidence](../../python_services/subscription_engine/models.py)
- [Current subscription usage tracker — legacy behavior evidence](../../python_services/subscription_engine/usage_tracker.py)
- [Current Python rate limiter — legacy behavior evidence](../../python_services/utils/rate_limiter.py)
- [Current Cloud Functions AI counter — legacy behavior evidence](../../firebase/functions/src/index.ts)
- [Current environment template — legacy configuration evidence](../../.env.example)
- [Phase 0 Readiness Audit](../../plans/NAJM_PRELAUNCH_AUDIT.md)
