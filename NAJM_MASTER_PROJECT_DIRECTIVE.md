# NAJM_MASTER_PROJECT_DIRECTIVE.md
**The supreme reference for the Najm Crew Intelligence Platform (CIP).**
Any decision, plan, or change must conform to this document unless the project owner changes it explicitly.

> Language note: this governance file is written in English to match the codebase and the product's English-only UI
> principle. An Arabic version can be produced on request. Where this document states a rule as *must*, it is binding;
> where it states *should*, it is a strong default that may be overridden with a documented reason.
>
> Status note: this is the **target state**. The current gap between this directive and the code is tracked in
> `plans/NAJM_PRELAUNCH_AUDIT.md`. The directive is the north star; the audit is the map of where we are today.

---

## 1. Project Vision
Najm is an operational intelligence platform for airline crew. It helps crew members **trade schedules safely, check
duty/rest legality, understand fatigue risk, and get grounded answers from official manuals** — fast, on mobile, and
without guesswork. It solves three problems: (1) legality and fatigue are hard to compute by hand and easy to get
wrong; (2) schedule trading is opaque and time-consuming; (3) operational knowledge is buried in PDFs. The guiding
principle behind every feature: **reduce the chance that a tired or misinformed crew member makes an unsafe or illegal
decision.**

## 2. Product Philosophy
- **English UI only.** All interface text is English. Full **Unicode** support for Arabic/multilingual *data* (names,
  airports, manual content) is required — but the UI chrome is not translated unless localization is a committed feature.
- **Safety first.** When safety and convenience conflict, safety wins.
- **The AI must never hallucinate.** Regulatory numbers come from the app's configured rules, never from the model's memory.
- **Knowledge before assumptions.** Prefer the Knowledge Engine and the user's own data over generic answers.
- **User trust over convenience.** No dark patterns, no fake capability, no control that doesn't actually control.

## 3. Architecture Principles
- **Single Source of Truth.** Every fact (account status, a feature flag, an FTL threshold) has exactly one
  authoritative home. Caches (e.g. token claims) are allowed but must be reconcilable to the source.
- **Clean, modular, domain-driven.** Engines are independent modules with clear inputs/outputs.
- **Backward compatibility.** Do not break existing behaviour unless explicitly asked.
- **Fail closed.** On misconfiguration or missing credentials, deny — never silently allow.
- **Security by default.** Every endpoint authenticated; least privilege everywhere.

## 4. (reserved)

## 5. Master Project Archive Policy
- **One project ZIP.** There is a single Master Archive. Updates modify **that** project — no standalone "phase" ZIPs,
  no patch ZIPs.
- The **latest ZIP is the only official one.** Older archives are historical only.
- Every release updates **`VERSION.md`** (append-only) and passes an **integrity check** (no orphan files, no dead refs).
- No release deletes anything until its impact has been analysed and recorded.

## 6. Code Quality Rules
No duplicate code · no hardcoded business rules (policy/safety/limits belong in config) · no magic numbers in policy
logic · no dead code · no undocumented TODOs · no secrets in source · no debug code in shipped paths.
*(Algorithm-tuning constants — ranking/scoring weights — may live in code, but must be named, commented, and test-covered.)*

## 7. Security Standards
Firebase Auth + custom claims · central account approval · authentication on every route · authorization by least
privilege · structured, **secret-redacting** logging · **PDPL** compliance (no roster/PII in logs; complete,
idempotent account deletion) · service-to-service calls fail closed and use constant-time token comparison.

## 8. Configuration Management
Anything expected to change without a code release **must** be read from the **Admin Panel** or the **database**, not
hard-coded. This explicitly includes: AI limits · rest/FTL rules · trade rules · feature flags · subscription features ·
notification templates · safety thresholds · AI prompts where practical. **Rule of thumb:** *policy, safety, and
commercial limits → config; algorithm tuning → code + tests.* A configuration surface that is shown to an admin **must
actually take effect** — a UI that writes to a collection no engine reads is a defect, not a feature.

## 9. Admin Panel Philosophy
The Admin Panel is the control centre. It should cover: users · admins & privileges · AI limits · rules (and they must
be enforced) · features/flags · subscriptions/RevenueCat · notifications · logs · analytics · **manual/knowledge
upload** · company policies · FTL/airports/airlines/operational reference data. **Every control must be wired to real,
enforced behaviour.**

## 10. AI Principles
Never hallucinate · always ground in configured rules and the user's data · cite when possible · refuse when uncertain
· Manual/Knowledge Engine first · company policy overrides generic knowledge · never state a regulatory number that
isn't in the grounded rule set or the user's data.

## 11. Knowledge Engine
Every uploaded manual is **Operational Knowledge**, not just a PDF. Required: index · search · citation · versioning ·
replace-old-version with change diff · archive · metadata. Uploads are admin-gated and must be reachable **from the
Admin Panel UI**, not only via API.

## 12. Trade Engine Standards
Every operation is reviewed and safe: search · bid · auto-bid · withdraw · accept · reject · cancel · ranking. Every
recommendation must pass legality and consider fatigue. Trade legality and rest legality must use the **same** rule
source (see §8 SSOT).

## 13. Rest Engine
Covers FTL · legality · fatigue · risk · reserve · positioning · company rules · regulatory rules. There is exactly
**one** FTL rule source shared with the Trade Engine and the AI. Rule values are config, seeded by in-code defaults.

## 14. RevenueCat Strategy
Launch **FREE** with `subscriptions_enabled=false`. RevenueCat-ready data model. Future billing = **Apple IAP +
Google Play** via RevenueCat. **No Stripe, no HyperPay.** Feature gating and subscription config are admin-controlled.

## 15. Performance Standards
Lazy loading · pagination · caching · background jobs / Cloud Tasks · query optimization · offline sync. No unbounded
queries (paginate all "all users" jobs). Parallelise N+1 reads.

## 16. Testing Policy
Unit · integration · UI/widget · smoke · regression · security · load. **Every safety rule has a test, and there is a
cross-engine consistency test** so two engines can never disagree about the same regulation. New engines ship with tests.

## 17. Operational Readiness
Before any release: build · deploy · monitoring · alerts · rollback (proven, not theoretical) · backup · restore ·
disaster recovery. Formalised in `plans/PHASE_3_operational_readiness_and_DR_certification.md`.

## 18. Documentation Standards
Any change updates, as applicable: `VERSION.md` · `CHANGELOG` · `NAJM_ARCHITECTURE.md` · API docs · admin docs. Docs
must not claim behaviour the code doesn't have (e.g. "configurable via Firestore" when it isn't).

## 19. Future Development Rules
Every new feature passes: (1) analysis → (2) architecture review → (3) security review → (4) performance review →
(5) implementation → (6) self-review → (7) verification → (8) documentation.

## 20. Permanent Claude Rules
- Never work on an old copy of the project — always use the **latest Master Archive**.
- Never create more than one ZIP; update the same project.
- Never delete anything before analysing its impact.
- Never break backward compatibility unless explicitly asked.
- Always review changes before delivery.
- If something can't be verified in the isolated environment (build, tests, emulator), **say so plainly** and provide
  the exact local verification checklist.
- Treat this document as the highest authority; any new decision must conform to it unless the owner changes it.
- **Never present a control, setting, or capability as working unless it is actually wired and enforced.**
- **For safety-critical values (FTL/rest/fatigue), never guess the authoritative number — ask the owner.**

---
### Companion documents
- `NAJM_ARCHITECTURE.md` — technical architecture, services, data model, flows, dependencies.
- `plans/NAJM_PRELAUNCH_AUDIT.md` — current state vs this directive (the gap list).
- `plans/PHASE_3_operational_readiness_and_DR_certification.md` — pre-launch certification.
