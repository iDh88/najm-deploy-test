# OWNER DECISION REQUEST — Regulatory Values Requiring Confirmation

**Status:** OPEN — release is GO-WITH-CONDITIONS until each item below is signed off.
**Scope note:** ODR-001…003 are regulatory (FTL) values. ODR-004 is an *architectural*
decision gate mandated by the Zero-Knowledge Credential Directive.
**Why this document exists:** The remediation directive forbids *guessing* regulatory
values. Where the repository contained conflicting or unverifiable Flight Time
Limitation (FTL) numbers, the engineering pass unified them on the **most
conservative, best-cited value already present in the project** and recorded the
decision here for the accountable owner (safety/compliance) to confirm or amend.

Nothing in this document invents a regulation. Every default now lives in ONE
place — `python_services/legality/rules_source.py` (`CANONICAL_DEFAULTS`) — and
every value can be changed **at runtime, without a deploy**, from the admin
panel (Firestore collection `legalityRules`, now actually read by all three
legality engines and by the AI assistant's grounding block).

---

## ODR-001 — Minimum rest, annual block cap, augmented rest, monthly-duty comparator

**Conflict found (pre-remediation):**

| Value | `legality/engine.py` (cited "GOM 7.5.3 Table F") | `rest_engine/rules.py` (uncited) | `intelligence/.../legality_checker.py` (uncited) | Flutter constants | AI grounding |
|---|---|---|---|---|---|
| Min rest, domestic | **14 h** | 10 h | 10 h | 14 h | 14 h |
| Min rest, international | **15 h** | 11 h | 11 h | 15 h | 15 h |
| Annual block hours | **900 h** | 1000 h | 1000 h | 900 h | 900 h |

At runtime the same pairing could be ruled **LEGAL by one engine and ILLEGAL by
another** (proven in the forensic audit). This is the P0-1 safety defect.

**Unified default (implemented):** 14 h domestic / 15 h international / 18 h
augmented-crew rest, emergency floor 10 h, annual cap **900 h** — i.e. the set
that (a) carries the project's only regulatory citation, (b) appears in 3 of 4
sources, and (c) is the **stricter/safer** direction in every case.

**Also standardized:** monthly-duty *warning* fires at **≥ 90 %** of the limit
(was a mix of `>` and `>=` at 0.90).

**Owner must confirm:**
1. 14/15/18/10 h rest minima match the current Saudia GOM / GACA OM-A tables in force.
2. Annual block cap is 900 h (not 1000 h).
3. Warning threshold ≥ 90 % is acceptable.

**If any value differs:** do NOT edit code — set the corrected value in the
admin panel (`legalityRules`), or run `scripts/seed_legality_rules.py --force`
after editing `CANONICAL_DEFAULTS`. Propagation ≤ 300 s (TTL), or call
`POST` deploy-restart / `legality.rules_source.invalidate_cache()`.

---

## ODR-002 — FDP limit model: flat cap vs. sector-count table

**Conflict found:** `legality/engine.py` used flat caps (12/13/14 h);
`rest_engine` used a report-time × sector-count table (max 14 h for 1–2
sectors, decreasing 30 min/sector to a floor); the intelligence checker used a
third variant. A 6-sector domestic day could pass the flat cap while breaching
the table.

**Unified default (implemented):** the **conservative intersection** — effective
FDP limit = `min(flat cap for leg type, sector-count table value with
early-report −30 min and WOCL −60 min reductions, floor 8 h)`. Both models are
kept and the stricter answer always wins. Cockpit profiles retain their
stricter table.

**Owner must confirm:** whether the operative GOM uses (a) flat caps, (b) the
Table-F sector matrix, or (c) both. If a single model is authoritative, tell us
which; disabling the other is a one-line change in
`rules_source.fdp_limit_minutes()` and is intentionally NOT admin-editable
(structural, not numeric).

---

## ODR-003 — Split-duty rest discount (REMOVED pending confirmation)

**Found:** `intelligence/utils/legality_checker.py` silently reduced required
rest by up to 50 % of ground-break time on "split duty" days. No citation, not
implemented in the other two engines, and it *lowers* a safety requirement.

**Implemented:** the discount is **removed** — split-duty days now require the
full canonical minimum rest. This is fail-safe (never under-estimates rest).

**Owner must confirm:** whether a split-duty rest credit exists in the operative
GOM. If yes, provide the exact formula + citation and we will implement it in
`rules_source` (one place) with tests.

---

## Sign-off

| ODR | Decision (confirm / amend + value) | Name / role | Date |
|---|---|---|---|
| ODR-001 | | | |
| ODR-002 | | | |
| ODR-003 | | | |

> Engineering note: the regression test `tests/unit/test_engine_consistency.py`
> fails the build if the three engines ever disagree again on minimum rest or a
> legality verdict for the same input. Changing values via `legalityRules` keeps
> them consistent by construction (single loader).

---

## ODR-004 — Server-orchestrated roster sync (server-managed credentials)

**Category:** Architecture (not regulatory). Raised by the **Zero-Knowledge
Credential Model** directive, which states:

> "Changing from client-managed credentials to server-managed credentials is
> considered an architectural decision. It MUST NOT happen automatically. It
> MUST require explicit approval from the project owner."

**Why this gate exists:** NAJM's default and preferred trust model is
zero-knowledge — *"the safest credential is the credential that NAJM never
possesses."* The device authenticates, the device normalizes, and only a
normalized roster reaches the backend. A future **official CAE enterprise
API** may instead require NAJM's own service credentials server-side. That is
a legitimate, supported model (the directive explicitly requires both to be
supportable) — but it moves NAJM from *cannot* possess credentials to *does*
possess them, and that transition may never happen by ops config alone.

**How it is enforced in code (already implemented):** setting
`CAE_INTEGRATION_BASE_URL` + `CAE_INTEGRATION_MODE=enterprise_service` is
**not sufficient**. The provider stays `requires_owner_approval` — refusing to
activate — unless the owner's explicit approval reference is also present:

```
ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL="<owner>/<date>/<approval-ref>"
```

Without it the connector reports its honest pending state and syncs continue
through the zero-knowledge (device) path. Tests:
`TestZeroKnowledgeTrustModel`, `TestNoHardcodedProviderEndpoints`.

**Owner must decide (only when an official CAE enterprise integration is
actually on the table):**

1. **Approve or refuse** server-orchestrated sync for `cae_crew_access`. If
   refused, NAJM waits for a device-side official flow (`device_oauth`) and
   the zero-knowledge model is preserved end-to-end.
2. If approved: confirm that CAE-issued **service** credentials (not user PRN
   passwords) will be held in the secret manager, and name the accountable
   owner + date for the approval string above.
3. Confirm the dual-model expectation: client-orchestrated providers (ICS
   today; any future device-auth provider) **remain** zero-knowledge even
   after an enterprise adapter is approved — approval is per-provider, never
   platform-wide.

**Nothing is blocked today.** CAE has no official public API; the connector is
pending, no credentials are stored for it, and ICS + manual upload serve users
in the meantime. This ODR exists so the switch, if it ever comes, is a
recorded owner decision rather than an environment variable someone set on a
Tuesday.

