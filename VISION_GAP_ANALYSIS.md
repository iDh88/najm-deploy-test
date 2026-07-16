# VISION GAP ANALYSIS — AI + Advanced Manual Filters
**Against:** "NAJM Vision — AI + Advanced Manual Filters (Core Product Architecture)"
**Repository state:** v1.3.0-dev (post filter-engine implementation) · 2026-07-11

This maps every vision pillar to code, three-way honest: **SHIPPED** (in this
repo, tested), **PARTIAL** (exists with gaps named), **PLANNED** (not built;
phase assigned). No pillar is marked shipped on intent.

---

## 1. The Golden Rule — "AI is NOT the search engine"

**SHIPPED — enforced by construction, not convention.**
`python_services/filter_engine/` is the single search authority:

* Every search — Manual, AI, Hybrid — is a `FilterQuery` of clauses that must
  validate against the registry (`schema.validate_clause`). The AI has no
  other door: its output is translated (`ai_bridge.from_filter_response`)
  into ordinary clauses and validated like a human's.
* `hybrid.merge()` implements "manual filters always have priority" literally:
  manual clauses are locked; an AI clause targeting a locked filter_id is
  **dropped and reported with the reason** — never merged, never averaged.
* AI failure can never block search: extraction errors degrade to
  manual-clauses-only with an honest `ai_summary`.
* Locked by 33 executed tests (`tests/unit/test_filter_engine.py`),
  including the lock-precedence and invalid-AI-clause truth tables.

## 2. Professional Filtering Engine

| Vision requirement | Status | Where / gap |
|---|---|---|
| Modular, easily extensible | **SHIPPED** | One `FilterDef` entry in `registry.py` = a new filter everywhere (engine, catalog endpoint, client UI, AI mapping). IDs are stable API. |
| Dozens→hundreds of filters | **PARTIAL** | **34 ACTIVE** filters across all 8 vision categories today, grounded in real `flightLines` fields (incl. leg-derived: red-eye, haul, time-of-day, consecutive duty days, per-layover hours, per-rest intervals). **14 registered REQUIRES_FIELD** with the missing data named (RR/RT/HD codes, deadhead flags, countries table, bonus, fatigue join, approval probability) — visible in the catalog as pending, never faked. Growing the count is parser work + one registry line each. |
| Fast, cache-friendly | **SHIPPED** | Clauses compile once per request; per-line extractor memoisation (ten leg-derived clauses parse legs once); single short-circuit pass. |
| Server-side filtering | **SHIPPED** | `POST /v1/lines/search` (token-pinned identity; Firestore `flightLines` per user+month, or inline lines for service callers). |
| Client-side refinement | **PARTIAL** | The existing client sort/`filteredLinesProvider` remains as refinement; the dynamic catalog (`GET /v1/lines/filters`) is served and modeled client-side (`filter_models.dart`) — the refinement UI itself is Phase C. |
| Real-time updates | **PLANNED (Phase D)** | Search is request/response; live re-search on roster change = Firestore listener → re-query. |
| Fully testable, independent from AI | **SHIPPED** | `engine.py` is pure dict-in/dict-out; the whole suite runs with zero AI. |

## 3. Mode 1 — Manual

**Server SHIPPED / UI PLANNED (Phase C).** Every catalog control type maps to
a clause kind (range/sets/bool/enum). The client renders Manual Mode from the
catalog endpoint, so a server deploy ships new filters without an app
release. `filter_models.dart` + `line_search_service.dart` are the wired
contract; the screens are the remaining work.

## 4. Mode 2 — AI

**SHIPPED (server path end-to-end).** "I want Europe with weekends off" →
the existing tuned LLM extraction (`ai/nlp_router.handle_filter_intent`) →
deterministic bridge → validated clauses → engine → ranked, explained
results. The chat endpoint now ALSO returns `filter_query` (registry-validated
clauses + rejected list) alongside the legacy `filter_result`, so the app can
hand the assistant's answer straight to `/v1/lines/search`.
Known bounds, stated: extraction quality is the shipped prompt's; requests
touching REQUIRES_FIELD filters are declined with the reason (e.g. "easy
schedules" maps to rest/duty clauses; "bonus eligible" is reported pending).

## 5. Mode 3 — Hybrid (flagship)

**SHIPPED (server semantics) / UI PLANNED (Phase C).**
`clauses` (locked) + `ai_instruction` in one request. The response's
`applied` block gives the UI everything the vision demands: manual clauses,
AI clauses that ran, and **every dropped AI clause with its reason** — the
"AI respected your filters" panel is a rendering task, not a logic task.
"Optimize for lowest fatigue" → rank-mode inference (`rest`), which an
explicit user mode always overrides.

## 6. Explainable AI — "never black box"

**SHIPPED as a response-shape guarantee.** Every result carries:
`matched_filters` (why it's in the set, with per-clause manual/ai source),
`component_scores` (salary / rest_quality / international_pct /
overtime_potential / dest_preference / regularity), `total_score`, and
`explanation` — the ranked reasons list (EN; AR string exists in the scorer)
for ✓-style rendering. The scorer's `generate_explanation` predated this
pass; it was extended additively to expose the reasons as a list.

## 7. Advanced Ranking Engine

**PARTIAL.** Shipped: transparent weighted composite with three modes
(money / rest / balanced — `ranking/scorer.py MODE_WEIGHTS`), full breakdown
in every response, mode inference in Hybrid. This pass also re-pointed the
scorer's rest heuristic floor at the canonical rules source (was a stale
hardcoded 10.0 — the P0-1 class of drift).
Gaps → **Phase B**: user-configurable custom weights (API slot exists:
`SearchRequest.rank_mode` becomes a weights object), and the vision's extra
signals (trade value, approval chance, career goals) which depend on the
predictor outputs below.

## 8. Smart Recommendation Engine (learning)

**PARTIAL.** Exists today: `preference_engine/` + `behavioral_learning/`
(behavior events, preference profiles, rebuild jobs) and `auto_bid/`
suggestions — but centred on **trades**, not line search. **Phase D** joins
them: search/selection events feed the preference profile; the profile emits
*suggested clause sets* ("You usually prefer Europe with Friday off") that
enter search as ordinary AI-source clauses — the golden rule already covers
them. Consent surface required (vision: "with user permission").

## 9. Data gaps blocking specific vision filters (parser work)

`REQUIRES_FIELD` registry entries name each one: duty-type codes (RR/RT/HD,
reserve/standby/training), deadhead flags, carry-over hours, bonus flags,
IATA→country mapping, crew-composition data, fatigue-score join from
PDF-intelligence, approval-probability persistence. Each unblocks by adding
the field in `parser/` (or a mapping table) and flipping the registry entry
to ACTIVE — no engine changes.

---

## Phased roadmap

| Phase | Scope | Depends on |
|---|---|---|
| **A (this pass — DONE)** | Filter engine + registry (34 active / 14 pending), 3-mode `/v1/lines/search`, hybrid lock semantics, AI bridge + chat `filter_query`, transparent ranking + reasons, catalog endpoint, Dart contract + service, 33 tests, OpenAPI | — |
| **B** | Custom rank weights; fatigue-score join (intelligence ⇄ lines); approval-probability as ranking signal (from auto_bid predictor) | A |
| **C** | Flutter UI: Manual filter sheet rendered from the catalog; Hybrid "AI optimize" bar on the lines screen; applied/dropped-AI disclosure panel; saved filter presets | A |
| **D** | Learning loop: search/selection events → preference profile → proactive suggested clause sets (opt-in); real-time re-search | A, C |
| **E** | Parser fields for the 14 pending filters; country mapping table | parser roadmap |
