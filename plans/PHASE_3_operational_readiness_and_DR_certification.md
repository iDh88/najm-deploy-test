# PHASE 3 — Operational Readiness & Disaster Recovery Certification
**Goal:** prove — by execution, not assertion — that Najm CIP is safe to launch: every user function, every admin
function, every engine, performance under load, backup/restore, disaster recovery, and a *practical* rollback.

> This phase is a **gate**. It is not "done" until every **must-pass** row below is checked with evidence (a log, a
> screenshot, a test run, or a recording) and the sign-off block at the end is completed. Rows are tagged
> **[auto]** (scriptable/CI) or **[manual]** (device/console). **P0 blockers from `NAJM_PRELAUNCH_AUDIT.md` must be
> resolved before this phase can pass** — a green Phase 3 over an unresolved F3/F4 would certify a false result.

## Entry criteria (do these first)
- [ ] **F3 + F4 resolved** — one authoritative, config-driven FTL source; admin editor enforced; cross-consistency test green.
- [ ] `flutter analyze`, `tsc --noEmit`, `pytest`, and the Firestore-rules emulator all pass locally.
- [ ] A dedicated **staging** project mirrors production config (this phase runs on staging, then a smoke subset on prod).

---

## 3.1 User-function certification
| # | Scenario | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| U1 | Sign up → land in pending | [manual] | New account created; status pending; blocked from gated screens | ☐ |
| U2 | Approved user gains access after token refresh | [manual] | After approval + `getIdToken(true)`, gated screens load | ☐ |
| U3 | Suspended user loses access promptly | [manual] | After suspend, user is denied on next action (verifies F2 fix / token revoke) | ☐ |
| U4 | Browse & filter flight lines (rank-scoped) | [manual] | Only same-rank lines visible | ☐ |
| U5 | **Rest Calculator** — legal / marginal / illegal duty | [auto+manual] | Correct verdict; **numbers match the single FTL source** (F3) | ☐ |
| U6 | Fatigue score for a WOCL-penetrating duty | [auto] | Score rises with WOCL/timezone load; level label correct | ☐ |
| U7 | Trade **search** returns ranked candidates | [auto] | Results ranked; each passes legality; scores populated | ☐ |
| U8 | Trade **create bid** | [manual] | Bid persisted; appears on board; counterpart notified | ☐ |
| U9 | Trade **update bid** | [manual] | Edit persists; stale state not shown | ☐ |
| U10 | Trade **accept** | [manual] | State → matched/pendingConfirm; both schedules updated; legality re-checked | ☐ |
| U11 | Trade **reject** | [manual] | State → rejected; initiator notified | ☐ |
| U12 | Trade **withdraw / cancel** | [manual] | State → withdrawn/cancelled; board updated | ☐ |
| U13 | **Auto-Bid** suggest (money / rest / balanced) | [auto] | Ranking shifts sensibly per mode; top-N submit works when enabled | ☐ |
| U14 | **Ask-Najm AI** — FTL question | [auto] | Answer uses the single FTL source; **no invented numbers**; cites/refuses correctly | ☐ |
| U15 | AI daily limit reached | [auto] | 429 at the configured limit (post-F1: value read from config, not env) | ☐ |
| U16 | **Knowledge search** with citation | [auto+manual] | Query returns passage from the correct manual **with a citation**; wrong-manual answer does not occur | ☐ |
| U17 | Salary/layover calculators | [auto] | Values match reference fixtures | ☐ |
| U18 | Account deletion (self) | [manual] | All per-user collections + Storage removed; Auth removed last; idempotent | ☐ |

## 3.2 Admin-function certification (the Admin Smoke Test you asked for)
| # | Scenario | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| A1 | Login as super-admin / limited-admin | [manual] | Correct role shown; privilege-scoped nav | ☐ |
| A2 | **Approve** a pending user | [manual] | Claim + doc updated; user notified; removed from queue | ☐ |
| A3 | **Reject** a user | [manual] | Claim `rejected`; refresh tokens revoked (F2); notified | ☐ |
| A4 | **Suspend** a user | [manual] | Claim `suspended`; revoked; access denied on next action | ☐ |
| A5 | **Create limited admin / revoke / edit privileges** | [manual] | Privilege changes take effect immediately | ☐ |
| A6 | **Edit a Legality Rule** and see it enforced | [auto+manual] | Change to `adminConfig/ftlRules` **actually changes** Rest + Trade + AI results (verifies F4 fix) | ☐ |
| A7 | **Toggle a Feature Flag** off | [auto] | Gated feature becomes unavailable in **both** Python and Cloud Functions paths (verifies F8) | ☐ |
| A8 | **Subscription master switch** on/off | [auto] | Feature-gate behaviour flips consistently everywhere | ☐ |
| A9 | **Set AI daily limit** from panel | [auto] | New limit takes effect without redeploy (verifies F1) | ☐ |
| A10 | **Upload a manual** (Knowledge) | [manual] | Upload → index → searchable + citable; version diff on replace (verifies F9 UI) | ☐ |
| A11 | **Send a notification** | [manual] | Delivered to targeted users | ☐ |
| A12 | View analytics / logs | [manual] | Populated; no PII/secrets leaked (PDPL) | ☐ |

## 3.3 Engine certification (Trade / Rest / AI / Knowledge)
| # | Check | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| E1 | **Cross-engine FTL consistency** | [auto] | Rest, Trade-legality, and AI grounding all read identical FTL numbers (the F3/F11 catcher) | ☐ |
| E2 | Legality — forward & backward rest, cumulative 7/28-day | [auto] | Violations/warnings correct at boundaries | ☐ |
| E3 | Fatigue — FRMS scoring monotonic in known factors | [auto] | Higher WOCL/tz-delta ⇒ higher fatigue | ☐ |
| E4 | Trade recommendation — legality gate | [auto] | No illegal candidate ranked above threshold | ☐ |
| E5 | Knowledge — grounded retrieval eval | [auto] | On a fixture manual, top passage is correct for N queries; citation present; **hallucination rate 0 on the eval set** | ☐ |
| E6 | AI — cite-or-refuse | [auto] | For an un-grounded rule, model refuses/points to manual rather than inventing | ☐ |

## 3.4 Push-notification certification (all states)
| # | State | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| N1 | **Foreground** | [manual] | In-app banner shown; payload correct | ☐ |
| N2 | **Background** | [manual] | System notification delivered | ☐ |
| N3 | **Killed app** | [manual] | Delivered; tap cold-starts app | ☐ |
| N4 | **Badge** count | [manual] | Badge increments/clears correctly | ☐ |
| N5 | **Deep link** | [manual] | Tapping routes to the correct screen (trade/approval/etc.) | ☐ |

## 3.5 Offline certification
| # | Scenario | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| O1 | Go offline → cached lines/bids still visible | [manual] | Cached data shown with age; **verifies F13 (Hive adapters registered) or the surface is removed** | ☐ |
| O2 | Queue an action offline → reconnect | [manual] | Queued action syncs; success banner; no duplicate | ☐ |
| O3 | Recovery after crash mid-sync | [manual] | No data loss/corruption; idempotent replay | ☐ |

## 3.6 Performance / load
| # | Test | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| P1 | Trade search under concurrency | [auto] | p95 latency within target at N concurrent users (set N from expected peak) | ☐ |
| P2 | AI endpoint under burst | [auto] | Rate-limit holds; no 5xx storms; graceful 429s | ☐ |
| P3 | `weeklyProfileRebuild` at full user count | [auto] | Completes within the 540 s budget; pages **all** users (no silent 500 cap) | ☐ |
| P4 | Firestore hot paths | [auto] | No unbounded query; indexes present for every composite query used | ☐ |
| P5 | Cold start (Cloud Run) | [auto] | Acceptable first-request latency; min-instances tuned if needed | ☐ |

## 3.7 Backup & restore
| # | Step | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| B1 | Scheduled Firestore export configured | [manual] | Exports run on schedule to a separate bucket | ☐ |
| B2 | **Restore drill** into a scratch project | [manual] | Data restored and app functional against it | ☐ |
| B3 | Storage (manuals) backup | [manual] | Objects recoverable; index re-buildable | ☐ |
| B4 | Config recovery | [manual] | `subscriptionConfig/main` and `adminConfig/ftlRules` restorable to a known-good state | ☐ |

## 3.8 Disaster-recovery scenarios (inject the failure)
| # | Injected failure | Type | Expected behaviour | ✔ |
|---|---|---|---|---|
| D1 | Python service down | [manual] | App degrades gracefully; no data loss; clear user messaging | ☐ |
| D2 | `INTERNAL_SERVICE_TOKEN` unset | [manual] | Service calls fail **closed** (503), not open | ☐ |
| D3 | Anthropic API outage | [manual] | AI returns a friendly retry message; rest of app unaffected | ☐ |
| D4 | Embeddings provider outage | [manual] | Knowledge search degrades safely; no crash | ☐ |
| D5 | Bad config pushed (e.g. wrong FTL value) | [manual] | Caught by validation/consistency test; rollback path clear (ties to B4) | ☐ |
| D6 | Corrupted deploy | [manual] | Health check fails; traffic not shifted | ☐ |

## 3.9 Rollback — **practical, not theoretical**
| # | Component | Type | Pass criteria | ✔ |
|---|---|---|---|---|
| R1 | Firestore rules rollback | [manual] | Previous rules re-deployed and verified live | ☐ |
| R2 | Cloud Functions rollback | [manual] | Previous version restored; triggers intact | ☐ |
| R3 | Cloud Run revision rollback | [manual] | Traffic shifted to prior revision; health green | ☐ |
| R4 | Mobile staged-rollout halt | [manual] | Rollout paused/rolled back in store console | ☐ |
| R5 | **Full dry-run** of the runbook | [manual] | The team executes `plans/phase2/rollback-runbook.md` end-to-end on staging and times it | ☐ |

---

## Monitoring & alerting (must exist before launch)
- [ ] Error-rate and latency alerts on Cloud Run + Cloud Functions.
- [ ] Alert on spikes in 403/429/503 (auth/limits/fail-closed).
- [ ] Log-based alert if an **unconfigured feature key** is denied (signals a config typo — F-gate logs this).
- [ ] Alert if the **FTL consistency check** ever fails in CI/health (regression guard for F3).
- [ ] Uptime checks on `/health`.

## Certification sign-off
This phase is complete only when all **must-pass** rows are checked with evidence and the P0 audit findings are closed.

| Role | Name | Date | Signature |
|---|---|---|---|
| Engineering owner | | | |
| Safety/ops reviewer (FTL numbers confirmed authoritative) | | | |
| Project owner | | | |

**Evidence bundle:** attach the CI run, the emulator run, the load-test report, the restore-drill log, the rollback
dry-run timing, and the device recordings for §3.4/§3.5. Store alongside this file in the Master Archive.
