# NAJM CIP — Pre-Launch Business-Logic & Configuration Audit
**Date:** 2026-07-08 · **Scope:** the full `najm_complete` Master Archive · **Auditor pass:** Opus (this session)

> This is the *comprehensive business-logic review* that Phases 0–2 did not produce. Phases 0–2 focused on
> security and structure; this pass reads the engines, the configuration surfaces, the admin control plane, and
> the test coverage, and answers the open questions directly with file/line evidence.
>
> **Environment caveat (unchanged from earlier phases):** this pass is *static* — the container has no network,
> no Dart/TS toolchain, no Firebase emulator, and Python service deps are not importable, so nothing was compiled
> or executed here. Every claim below is grounded in the source that is in the archive. The *real* gate is your
> local `flutter analyze` / `tsc --noEmit` / `pytest` / rules-emulator run plus the staging smoke test.

## Severity legend
| Tag | Meaning |
|---|---|
| **P0 — Blocker** | Safety-relevant or data-integrity; fix before any launch. |
| **P1 — High** | Real gap between intended behaviour and actual behaviour; fix before or immediately after launch. |
| **P2 — Medium** | Should fix; not launch-blocking on its own. |
| **P3 — Low / Cleanup** | Cosmetic, hygiene, or acknowledged debt. |

---

## PART A — Direct answers to your three questions

### A1. `AI_DAILY_FREE_LIMIT` — Admin Panel or `.env`?
**It is still an environment variable. It is NOT editable from the Admin Panel.** It is read in two independent
places, both from the process environment:
- `python_services/ai/nlp_router.py:297` → `limit = int(os.getenv("AI_DAILY_FREE_LIMIT", "50"))`
- `firebase/functions/src/index.ts:287` → `const dailyLimit = parseInt(process.env.AI_DAILY_FREE_LIMIT || "50", 10)`
- Declared in `.env.example:33` → `AI_DAILY_FREE_LIMIT=50`

There is a perfectly good Firestore-backed config system next door (`subscriptionConfig/main`, edited through the
Admin Panel), but this limit was never wired into it. Changing it today requires a redeploy in **two** services.
→ See finding **F1**.

### A2. `accountStatus` — is there a Single Source of Truth, or only Firebase Claims?
**There is no single source of truth for authorization. Both enforcement layers trust the token claim only.**
- Python: `python_services/utils/auth.py` → `if claims.get("accountStatus") != "approved": raise 403`. The code
  comment itself notes: *"Claims propagate on ID-token refresh, so a just-approved user may need a token refresh."*
- Firestore rules: `firebase/firestore.rules:33-35` → `request.auth.token.accountStatus == 'approved'`.

The Firestore **user document also stores** `accountStatus` (written alongside the claim in
`firebase/functions/src/admin_setup.ts`), but that document is **never consulted for an authorization decision** —
it is effectively write-only for authz. So the field exists in two places, and the *authoritative* one for access
control is the slow one (the claim), which lags until the user's ID token refreshes (up to ~1 hour, or until app
restart). Consequences:
- A **suspended** user keeps access until their token refreshes (unless refresh tokens are revoked — they are not; see F2).
- A **just-approved** user is blocked from the Python layer until their token refreshes.
→ See finding **F2**.

### A3. Are there Limits / Feature Flags / AI Limits / Rest Rules / Trade Rules still hardcoded that should move to Admin/DB?
**Yes — and one category of it is safety-critical.** Full inventory in **PART D (Configuration Ownership Matrix)**.
The short version:

| Category | Where it lives now | Should it move? |
|---|---|---|
| Subscription master switch, feature access, usage limits, plans, trial | **Firestore + Admin Panel** ✅ already correct | — |
| `AI_DAILY_FREE_LIMIT` | `.env` (two services) | **Yes** → config doc (F1) |
| **FTL / rest / FDP / duty legality rules** | **Hardcoded in TWO conflicting files** | **Yes — P0** (F3, F4) |
| Auto-bid mode weights, ranking weights, compatibility weights, score thresholds | Hardcoded (Python) | *Mostly no* — these are algorithm-tuning parameters, not policy. Acceptable in code **if** covered by tests. Optionally expose a few high-level knobs later. (F6) |
| Notification templates (titles/bodies) | Hardcoded strings in Cloud Functions | Optional → templates collection (F7) |
| Feature flags for Auto-Bid / Analytics / Smart Search / Knowledge | **Do not exist as flags** | Add keys if you intend to gate them (F5) |

**Important nuance:** not everything *should* move to the database. Ranking/scoring weights are tuned numeric
parameters; over-exposing them to admin editing usually causes more harm (a mistuned weight silently degrades every
recommendation) than value. The rule of thumb this audit applies: **policy, safety, and commercial limits → config;
algorithm tuning → code + tests.** The problem is not that *everything* is hardcoded; it's that the **safety rules
are hardcoded and inconsistent**, while a UI implies they're editable.

---

## PART B — Findings register (severity-ranked)

### F3 · P0 · Two conflicting definitions of the same FTL/rest regulations
The platform contains **two independent, hardcoded rule sets for the same safety regulations, and they disagree
materially.** There are literally two classes both named `LegalityEngine`.

| Regulation | `legality/engine.py` (`DEFAULT_RULES`) | `rest_engine/rules.py` (`CABIN_STANDARD`) |
|---|---|---|
| Min rest — domestic | **14.0 h** | 600 min = **10.0 h** |
| Min rest — international | **15.0 h** | 660 min = **11.0 h** |
| Max FDP — domestic (1 leg) | **12.0 h** | 840 min = **14.0 h** |
| Max daily block | **8.0 h** | 510 min = **8.5 h** |
| Rule reference string | `"GACA-…"` / GOM 7.5.3 | `"GACA 121 — …"` |

**Which one the crew member sees depends on the screen** (both routers are mounted and reachable by the app —
`python_services/main.py:90` `/v1/legality`, `:112` `/v1/rest`):
- **Rest & Legality screen** → `/v1/rest/*` → `rest_engine` → **10 h / 11 h** minimum rest.
- **Trade legality check** (`/v1/legality/check-trade`, `/check-bid`, called from `flutter_app/lib/core/services/ai_service.dart`) → `/v1/legality/*` → **14 h / 15 h**.
- **Ask-Najm AI** grounds its regulatory answers on `legality/engine.py`'s `DEFAULT_RULES` (`ai/nlp_router.py:20` `from legality.engine import DEFAULT_RULES as _FTL`) → tells users **14 h / 15 h**.

So the Rest Calculator can call a duty "legal" against a 10 h rest minimum while the AI and the trade checker use a
14 h minimum — for the same crew member, same regulation. In a fatigue/safety product whose stated first principle is
"Safety First / AI must never hallucinate," this is the single most important thing to fix.
**Evidence:** `python_services/legality/engine.py:16-26,44-79`; `python_services/rest_engine/rules.py:28-67`; `python_services/rest_engine/legality.py:11,75`; `python_services/ai/nlp_router.py:20,81-93`; `python_services/main.py:90,112`.
**Fix:** collapse to **one** rule source (see PART G — requires one domain decision from you: which numbers are authoritative). Both docstrings already *claim* "configurable via Firestore / no hardcoded values in business logic" — make that true: one `adminConfig/ftlRules` document, in-code constants as the fallback default, every engine + the AI read from it, and a cross-consistency test that fails if the two ever diverge again.

### F4 · P0 · The Admin "Legality Rules" editor changes nothing
The Admin Panel has a **Legality Rules** page with an **Edit Legality Rule** modal
(`admin_panel/index.html:288-289, 421-423, 586`). It reads and writes a Firestore collection **`legalityRules`**
(`admin_panel/index.html:983` `db.collection('legalityRules').get()`, `:1017` `…doc(id).update(...)`).
**No backend engine reads `legalityRules`.** The legality engine uses hardcoded `DEFAULT_RULES`; the rest engine
uses hardcoded `RulesProfile`; the AI grounds on `DEFAULT_RULES`. A super-admin can open the page, change the minimum
rest, save it, watch it persist — and every engine keeps using the hardcoded value. This is the most dangerous kind of
gap: **an illusion of control over safety-critical parameters.**
**Evidence:** `admin_panel/index.html:981-1020`; absence of any `legalityRules` read in `python_services/` (grep: only the collection write in the panel and the Firestore-rules entry exist).
**Fix:** wire the engines to read the same document the panel writes (this is the delivery mechanism for F3's single source). Until then, either hide the page or add a banner: "Preview only — not yet enforced."

### F1 · P2 · `AI_DAILY_FREE_LIMIT` not admin-controllable + duplicated
As A1. Two env reads that must be kept in sync manually; not exposed to the admin.
**Fix:** add `aiDailyFreeLimit` to the config document served by `subscription_engine/config_service.py`; have both
`nlp_router.py` and the Cloud Function read it (env value becomes the seed default only). Add an admin control next to the subscription master switch.

### F2 · P1 · `accountStatus` refresh-lag has no mitigation
As A2. Standard Firebase pattern to bound the lag is missing: **suspend/reject do not revoke refresh tokens**
(`admin_setup.ts` sets the claim via `setCustomUserClaims` and writes the doc, but never calls
`admin.auth().revokeRefreshTokens(uid)`).
**Fix (layered):**
1. On suspend/reject, call `revokeRefreshTokens(uid)` so the next token refresh (and Firestore-rules `auth.token.auth_time` check) forces re-auth — cheap, closes the suspend gap.
2. Treat the **Firestore user doc as the source of truth** and the claim as a cache for the *most sensitive* server actions (e.g. anything that moves a trade to a committed state), reading the doc when the decision must be current. Keep claims for the hot path.
3. Client already can refresh — after approval, force `getIdToken(true)` once so the just-approved user isn't stuck.

### F5 · P2 · Feature-flag taxonomy is incomplete
Only five feature keys exist (`subscription_engine/config_service.py:22-27`): `trade_engine`, `rest_calculator`,
`fatigue_engine`, `operational_ai`, `layover_intelligence`. There is **no** flag for **Auto-Bid**, **Analytics**,
**Smart Search**, or **Knowledge Center** as distinct capabilities. Also, the feature-gate system (Firestore) and the
`SUBSCRIPTIONS_ENABLED` env read in Cloud Functions are **two different mechanisms** (see F8).
**Fix:** decide the canonical capability list; add the missing keys; route every capability check through
`FeatureGate.can_access` so "is X on?" has exactly one answer.

### F8 · P2 · `SUBSCRIPTIONS_ENABLED` split-brain
The master switch is read **two ways**:
- Python: from Firestore `subscriptionConfig/main` (`config.subscriptions_enabled`) — the admin-editable path.
- Cloud Functions: from the **environment** (`firebase/functions/src/index.ts:345` `process.env.SUBSCRIPTIONS_ENABLED !== "true"`).

Flip the switch in the Admin Panel and the Python feature gate updates, but the Cloud Function branch still obeys the
env var — they can disagree.
**Fix:** the Cloud Function should read the same Firestore config (it already has admin SDK access), or both should
read one source. Remove the divergent env read.

### F9 · P1 · Knowledge Engine has a full backend but no Admin-Panel UI to drive it
The Knowledge Engine backend is genuinely complete: extraction, chunking, embeddings, vector store, retrieval,
versioning + diff, and **admin-gated upload/replace endpoints** with a real privilege check
(`knowledge_engine/router.py:41-60` require `superAdmin` or `admin + manage_knowledge_base`; `POST /documents`,
`POST /documents/{id}/versions`). **But the Admin Panel exposes no Knowledge/Manuals page** — its navigation is
Dashboard, Approvals, Users, Lines, Trades, Bids, Notifications, Admins, Legality, Analytics. "Upload Flight Lines"
(`upload_lines`) is for rosters, not manuals. So an admin cannot upload a GOM/manual from the panel; they'd have to
call the API by hand.
**Fix:** add a Knowledge/Manuals page (upload, list, version history, activate/rollback) that calls the existing
endpoints. The hard part (the engine) is done.

### F10 · P1 · No tests for the highest-risk surfaces
See PART E for the full matrix. Headlines:
- **Flutter app: zero tests** (`flutter_app/test/unit` and `/widget` are empty directories).
- **Cloud Functions: zero tests** — including the PDPL account-deletion pipeline and the approval/suspend triggers.
- **Push notifications: no test** (foreground/background/killed/badge/deep-link all unverified).
- **Admin Panel: no smoke test.**
- The FTL engines *are* tested, but **in isolation**, which is exactly why F3 slipped through — see F11.

### F11 · P1 · The test suite *enforces* the F3 inconsistency instead of catching it
`python_services/tests/unit/test_rest_engine.py:55` asserts `DEFAULT_PROFILE.min_rest_domestic_mins == 600` (the 10 h
value), while `tests/unit/test_legality.py` exercises the 14 h engine. Both suites pass independently; neither knows the
other exists. Green tests, contradictory safety rules. Additionally, `tests/unit/test_knowledge_engine.py` mocks/skips
embeddings and network, so chunking + cosine similarity are covered but **end-to-end retrieval quality and citation
correctness are not** — which is the part that matters for the "no hallucination" guarantee.
**Fix:** add a cross-consistency test (one authoritative rule set; assert both engines and the AI grounding read the
same numbers) and a small grounded-retrieval eval against a fixture manual.

---

## PART C — Engine-by-engine status

Legend: **Works** = code path is coherent and reachable · **Tested** = has automated coverage · **Config-driven** =
key parameters are data, not code · **Admin-controllable** = editable from the Admin Panel.

| Engine / Subsystem | Works (static) | Tested | Config-driven | Admin-controllable | Notes |
|---|---|---|---|---|---|
| Trade Engine (search/recommend) | Yes | Thin (integration only) | Weights hardcoded | No | `recommendation_engine` + `compatibility_scoring`; see F6 |
| Trade lifecycle (bid/withdraw/accept/reject/cancel) | Yes (rules + functions) | **No engine-level test** | — | Board/award visible in panel | Firestore-rules-enforced; needs the F10 lifecycle tests |
| Auto-Bid | Yes | **No** | `MODE_WEIGHTS` hardcoded | No | `auto_bid/engine.py:75` |
| Rest Calculator | Yes | Yes (`test_rest_engine`) | **Hardcoded** | **No (editor is dead — F4)** | Uses the 10 h/11 h rule set |
| Legality (trade) | Yes | Yes (`test_legality`) | **Hardcoded** | **No (editor is dead — F4)** | Uses the 14 h/15 h rule set — conflicts with Rest (F3) |
| Fatigue | Yes | Yes (in `test_rest_engine`) | Thresholds hardcoded | No | `rest_engine/fatigue.py`; thresholds in `rules.py` |
| AI Assistant | Yes | Grounding eval only | Grounds on hardcoded FTL | Prompt in code | Cite-or-refuse design is sound; **source it grounds on is wrong (F3)** |
| Knowledge Engine | Yes (full) | Partial (plumbing only — F11) | Yes (docs are data) | **No UI (F9)** | Backend is the strongest part of the system |
| Subscription / Feature Gate | Yes | Yes (`test_subscription_engine`) | **Yes** ✅ | **Yes** ✅ | The reference example of "done right" |
| Admin — user lifecycle | Yes | **No** | — | Yes | approve/reject/suspend + admin mgmt in Cloud Functions |
| Authentication / Approval | Yes | Identity unit tests (proven) | — | Via user lifecycle | **Claims-only enforcement (F2)** |
| Notifications (push) | Wired | **No** | Templates hardcoded | Send-ad-hoc only | No automated push test (F10); templates in code (F7) |
| Offline / Sync | Partial | **No** | — | — | UI + providers exist, but Hive cache adapters are commented out (`main.dart:62-63`) — line/bid caching likely non-functional (F13) |

---

## PART D — Configuration Ownership Matrix
*"Where does each knob actually live, and can the admin turn it?"*

| Knob | Current source | Admin-editable? | Recommended target | Finding |
|---|---|---|---|---|
| Subscriptions on/off (Python) | Firestore `subscriptionConfig/main` | ✅ Yes | keep | — |
| Subscriptions on/off (Cloud Functions) | **env `SUBSCRIPTIONS_ENABLED`** | ❌ No | read Firestore config | F8 |
| Feature access (per feature) | Firestore config | ✅ Yes | keep | — |
| Usage limits (per feature) | Firestore config | ✅ Yes | keep | — |
| Plans / trial | Firestore config | ✅ Yes | keep | — |
| `AI_DAILY_FREE_LIMIT` | **env (×2 services)** | ❌ No | config doc | F1 |
| **FTL min rest / FDP / duty / block** | **hardcoded ×2, conflicting** | ❌ No (dead editor) | one `adminConfig/ftlRules` | **F3, F4** |
| WOCL window | hardcoded (`rules.py`, `timezone_utils.py`) | ❌ No | with FTL config | F3 |
| Fatigue thresholds | hardcoded (`rules.py`) | ❌ No | with FTL config (or keep + test) | F3/F6 |
| Auto-bid weights | hardcoded (`auto_bid/engine.py:75`) | ❌ No | keep in code + test | F6 |
| Ranking weights / overtime threshold | hardcoded (`ranking/scorer.py:19,119`) | ❌ No | keep in code + test | F6 |
| Compatibility weights / score cutoffs | hardcoded (`compatibility_scoring/scorer.py:59`, `recommendation_engine/engine.py:26`) | ❌ No | keep in code + test | F6 |
| Notification templates | hardcoded strings (Cloud Functions) | ❌ No | optional templates collection | F7 |

---

## PART E — Test coverage matrix

| Area | Automated test today | Verdict |
|---|---|---|
| Python — identity/auth | `test_auth_identity.py` (proven 5/5 in Phase 1) | ✅ good |
| Python — legality (14h engine) | `test_legality.py` (500 lines) | ✅ good, but isolated (F11) |
| Python — rest/fatigue (10h engine) | `test_rest_engine.py` (381 lines) | ✅ good, but **locks in the conflicting value** (F11) |
| Python — knowledge | `test_knowledge_engine.py` (196 lines) | ⚠️ plumbing only; no grounded-retrieval eval (F11) |
| Python — subscription/feature gate | `test_subscription_engine.py` | ✅ good |
| Python — parser/ranking/preference/route | present | ✅ reasonable |
| Python — AI grounding | `eval/test_ai_grounding.py` (66 lines) | ⚠️ small; grounds on the wrong source (F3) |
| Python — trade search API | `test_trade_search_api.py` (141 lines) | ⚠️ thin; no bid-lifecycle |
| **Cross-engine FTL consistency** | **none** | ❌ **missing — the F3 catcher** |
| **Flutter (unit + widget)** | **none (empty dirs)** | ❌ missing |
| **Cloud Functions (incl. deletion pipeline, triggers)** | **none** | ❌ missing |
| **Push notifications** | **none** | ❌ missing |
| **Admin Panel smoke** | **none** | ❌ missing |

---

## PART F — Status of your named cleanup items

| Item | Status now | Evidence |
|---|---|---|
| Replace real Najm logo | **Still placeholder** — 240×240 6.4 KB PNG present | `flutter_app/assets/images/najm_logo.png` |
| Remove dead Arabic toggle | **Still live and wired** — Settings switches `Locale('ar')`; contradicts English-only; `localeProvider` not persisted (`TODO: Load from Hive`) | `settings_screen.dart:192-204`; `app/app.dart:62-64` |
| Delete `stripeCustomerId` from models | **Still present** (needs `build_runner` locally) | `flutter_app/lib/core/models/models.dart:40` |
| Decide on Hive | **Initialized but incomplete** — boxes open, but cache adapters commented out; offline caching of lines/bids likely non-functional | `flutter_app/lib/main.dart:40-63` |
| Review Account-Deletion field names | **Unverified against data model** (as flagged) — a wrong field only under-deletes; the pipeline itself is untested (F10) | `firebase/functions/src/index.ts` deletion pipeline |
| Accessibility / UI pass | Guidance-only from Phase 2; not applied | `plans/phase2/production-readiness.md` |

(These are tracked as **F12** logo/UI, **F13** Hive/offline, **F14** stripe field, **F15** deletion field names, **F16** Arabic toggle — all P2/P3 except the deletion-pipeline test which rolls up into F10.)

---

## PART G — Prioritised remediation roadmap

### The one decision only you can make (needed before F3/F4)
**Which FTL numbers are authoritative for your operation — the `legality/engine.py` set (14 h / 15 h / 12 h, cited to
GOM 7.5.3) or the `rest_engine` set (10 h / 11 h / 14 h)?** My read: the `legality/engine.py` values look like the real
company GOM numbers (they match the `HOME_BASE_REST_MIN=14` / `INTERNATIONAL_REST_MIN=15` constants and cite a specific
GOM table), while the `rest_engine` values look like generic placeholder defaults — **but this is a regulatory fact about
your airline, not something I should guess.** Confirm the authoritative set and I'll unify to it.

### P0 (before any launch)
1. **F3 + F4 — unify FTL into one config-driven source.** Pick the authoritative numbers; create `adminConfig/ftlRules`
   (seeded from in-code defaults); make `legality/engine.py`, `rest_engine`, and the AI grounding all read it; point the
   Admin "Legality Rules" editor at that same document; add the F11 cross-consistency test.

### P1 (before launch, or the first hotfix after)
2. **F2** — revoke refresh tokens on suspend/reject; read the Firestore user doc for the most sensitive server actions.
3. **F9** — add the Knowledge/Manuals admin page (endpoints already exist).
4. **F10/F11** — add: Cloud Functions tests (deletion pipeline + approval/suspend), a bid-lifecycle test, a grounded-retrieval eval, and at least smoke-level Flutter widget tests for the critical screens.

### P2 (fast-follow)
5. **F1** — move `AI_DAILY_FREE_LIMIT` into the config document; admin control.
6. **F8** — remove the Cloud Functions env read of `SUBSCRIPTIONS_ENABLED`; read Firestore config.
7. **F5** — finalise the feature-flag taxonomy; add the missing capability keys.
8. **F13** — decide Hive: either finish the cache adapters (register them, persist locale) or remove the offline-cache
   surface so it doesn't imply functionality that isn't there.
9. **F7** — optionally move notification templates to a collection.

### P3 (cleanup)
10. **F12** real logo · **F14** drop `stripeCustomerId` via `build_runner` · **F15** reconcile deletion field names ·
    **F16** remove the Arabic toggle (or commit to real localization) · accessibility pass.

---

## PART H — What this pass could NOT verify (must be checked locally)
Because the container can't build or run anything, the following remain **your** gate:
- `flutter analyze` — the app has never been compiled here; codegen (`build_runner`) not run.
- `tsc --noEmit` on Cloud Functions.
- `pytest python_services/tests` — service deps aren't importable here.
- Firestore-rules emulator suite.
- The staging smoke test in `plans/phase2/rollback-runbook.md`.
- Anything requiring a device: push delivery, offline behaviour, deep links (these become **Phase 3** — see
  `plans/PHASE_3_operational_readiness_and_DR_certification.md`).

**Bottom line:** the plumbing (auth, subscriptions/feature-gate, knowledge backend, logging, deletion design) is in
good shape and several parts are genuinely well done. The launch risk is concentrated in **one place: the safety-rule
layer is hardcoded, internally inconsistent (F3), and fronted by an admin editor that does nothing (F4).** Fix that one
thing properly and the rest is a prioritised, non-scary list.
