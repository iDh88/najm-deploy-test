# NAJM AI Platform — Architecture Decision Backlog

**Status:** Active decision backlog
**Last updated:** 2026-07-19

This backlog records unresolved architecture decisions that must pass a future
Gate A before implementation. An entry is not an approved contract or an
authorization to modify protected AI Platform files.

## AIDB-001 — Authoritative business commit source

**State:** Deferred; Gate A required
**Origin:** Phase 6 final Gate B review

### Verified current evidence

- `AIOrchestratorResponse.may_commit_business_transaction` exists.
- Its protected validator permits `True` only when
  `status is AIRequestStatus.COMPLETED`.
- The protected contracts do not identify which service or decision is
  authoritative for setting the field.
- `CreditReservationRef` carries reservation evidence data but does not prove
  that an authoritative reservation operation completed.
- `LedgerEventType.RESERVATION` is an observational ledger event family. It
  does not reserve a balance and cannot authorize a business commit.

### Required future decision

Before authoritative reservation or transaction-commit behavior is added,
Gate A must define:

- The authoritative service or decision.
- The evidence and correlation contract.
- Expiry, replay, and idempotency semantics.
- Failure and uncertain-outcome behavior.
- The relationship between reservation evidence and product transaction
  commit permission.

## AIDB-002 — Fallback route authorization evidence

**State:** Deferred; Gate A required
**Origin:** Phase 6 final Gate B review

### Verified current evidence

- `GatewayFallbackPolicy` contains ordered `GatewayAttemptPlan` values.
- Its protected validation enforces shared request and feature identities,
  unique attempt identifiers, and fallback reasons after the primary attempt.
- Its documentation describes attempts as pre-approved.
- It contains no explicit approval identifier or per-route authorization
  evidence.
- Phase 6 accepts the policy as externally supplied and does not discover,
  authorize, add, replace, reorder, or expand fallback routes.

### Required future decision

Before dynamic routing or authoritative fallback approval is added, Gate A
must define:

- The authority that approves each route.
- The approval identifier and immutable policy version evidence.
- Route scope, expiry, capability, region, data-handling, safety, and budget
  binding.
- Retry and uncertain-execution constraints.
- Audit and ledger correlation requirements.
