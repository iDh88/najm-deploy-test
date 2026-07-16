# Zero-Knowledge Credential Model — PERMANENT PLATFORM RULE

**Status:** MANDATORY. Adopted by owner directive. Applies to **every** roster
provider integration, present and future (CAE Crew Access, Sabre, Jeppesen,
AIMS, NetLine, Lufthansa Systems, ICS, PDF, Excel, email import, …).

> **The safest credential is the credential that NAJM never possesses.**

Changing this model is an **architectural decision requiring explicit owner
approval** (see `OWNER_DECISION_REQUEST.md` → ODR-004). It must never happen
as a side effect of configuration.

---

## 1. The rule

NAJM's backend must never know, receive, store, cache, log, or persist a
user's personal roster credentials whenever a secure client-side architecture
is technically possible.

The backend is **not a credential vault**. It is responsible for authenticated
NAJM identity, normalized roster imports, processing, analytics, legality,
salary, AI and recommendations — nothing else.

## 2. The only allowed flow (client-orchestrated / zero-knowledge)

```
User enters PRN + password ONCE
        ↓
Stored in iOS Keychain / Android Keystore   (flutter_secure_storage,
        ↓                                    hardware-backed where available)
Credentials remain ONLY on the device
        ↓
RosterConnector authenticates DIRECTLY with the official provider
        ↓
Roster downloaded locally
        ↓
Roster NORMALIZED ON THE DEVICE            (ics_normalizer.dart)
        ↓
NORMALIZED ROSTER ONLY is uploaded         (payload_kind: "normalized")
        ↓
Backend processes it — and never receives a credential
```

Two consequences worth stating plainly, because they are features, not
side effects:

* **The raw calendar never leaves the phone.** A crew feed also carries
  private events — medical appointments, family birthdays. Device-side
  normalization drops them; NAJM never sees them.
* **The feed URL never leaves the phone either.** ICS subscription links
  routinely embed a personal token, so the URL is treated as a credential.

## 3. The walls (defence in depth — each independently sufficient)

| # | Wall | Where |
|---|---|---|
| 1 | Credentials only in the secure enclave; namespaced; wiped on disconnect | `credential_manager.dart` |
| 2 | Device normalizes; only normalized rosters are uploadable by app clients (raw `ics` from a device client is **422**) | `roster_sync/router.py` |
| 3 | **Inbound guard** — every raw request body is scanned *before parsing*; any credential-shaped key ⇒ 422 | `assert_no_credentials` |
| 4 | **Outbound guard** — every roster-sync response is screened; a field named `refreshToken` cannot quietly appear in an API payload | `assert_no_credentials_out` |
| 5 | **Log redaction** — passwords, tokens, `Authorization: Bearer …`, JWTs, cookies redacted automatically at the logging layer | `utils/logging_config.py` (`SecretRedactionFilter`) |
| 6 | **Firestore rules** — `rosterSources` / `rosterVersions` owner-read, service-write; `syncEvents` service-only | `firebase/firestore.rules` |

**Forbidden field names** (directive, verbatim — enumerated in code so the rule
is auditable, then generalized to fragments so `providerPassword`,
`refresh_token`, `session-cookie` variants are all caught): `password`,
`secret`, `credential`, `token`, `authHeader`, `authorization`,
`sessionCookie`, `refreshToken`, `providerPassword`, `providerSecret`,
`providerCredential`. `PRN` is included as a credential fragment.

*Precision note:* the `Authorization: Bearer <Firebase ID token>` **request
header** is NAJM's own user identity — not a roster-provider credential. It is
untouched by the payload walls and is redacted from logs by wall 5.

## 4. Backend receives only

normalized roster · provider id · sync metadata · timestamps · sync status ·
import checksum · version id.

## 5. Session behaviour (log in once — and mean it)

```
App restart → credentials restored from Keychain/Keystore
            → automatic background synchronization
            → NO additional login
```
Implemented by `RosterSyncBootstrap`, mounted **above every route** in
`app/app.dart`. This mount is the feature: without it the `SyncScheduler`
exists but nobody starts it, credentials survive a restart, and still nothing
syncs. Re-authentication is required only when the user changes their
password, the account is revoked, they disconnect the provider, secure storage
is cleared, or the device is reset.

## 6. Disconnect

Erases every locally stored credential for that provider (and refresh/auth
state), leaves **imported roster history intact**, and leaves no orphan keys.
Runs even if the server call fails.

## 7. The two supported models (both, simultaneously)

| Model | Credentials | When |
|---|---|---|
| **Client provider** (default, preferred) | User's — device-only, zero-knowledge | ICS today; any future official device-auth flow (e.g. CAE `device_oauth`) |
| **Server provider** (dedicated adapter) | **NAJM's own enterprise service credentials** from the secret manager — never user passwords | Only if an official enterprise API exists **and** ODR-004 is approved |

Approval is **per provider**, never platform-wide: approving an enterprise
adapter for CAE does not weaken the zero-knowledge model for anyone else.
Enforcement: `owner_approved_server_orchestration()` — without
`ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL` the provider reports
`requires_owner_approval` and refuses to activate, even with the API base URL
and mode configured.

## 8. CAE adapter status

No public CAE API is assumed. The adapter is **pluggable, with no hardcoded
endpoints, no reverse-engineered auth, and no placeholder that implies the
integration exists**. It reports `pending_official_integration`, stores **no
credentials**, and the platform compiles, tests, and ships fully with the
adapter inactive (`TestNoHardcodedProviderEndpoints`).

## 9. Parser parity — the hazard this model created, and its guard

Moving normalization onto the device means **two** ICS implementations exist:
the canonical `roster_sync/ics_parser.py` and the device
`ics_normalizer.dart`. Drift between them would silently give crew a
different roster than the backend would have produced — with every suite
green.

Both are therefore pinned to **one shared fixture**:

```
test_fixtures/roster_sync/ics_golden.ics    ← the input
test_fixtures/roster_sync/ics_golden.json   ← expected legs, GENERATED from
                                              the canonical Python parser
```

asserted on both sides — `tests/unit/test_ics_parity.py` (runs here) and
`test/unit/ics_normalizer_test.dart` (runs in CI). Divergence becomes a failing
build. Fixture durations are quarter-hour multiples on purpose: Python rounds
half-to-even and Dart rounds half-away-from-zero, so any duration landing on an
exact half-hundredth could pass server-side and fail on a phone.

## 10. Acceptance criteria → evidence

| Directive criterion | Evidence (executed) |
|---|---|
| Credentials never leave the device | `credential_manager.dart` + `roster_sync_test.dart` (ICS token `SECRET123` never appears in any error or payload; CAE pending stores **nothing**) |
| Backend cannot reconstruct credentials | Inbound + outbound guards; `TestCredentialWalls` — every forbidden field name rejected in and out |
| Automatic sync works after app restart | `RosterSyncBootstrap` mounted in `app/app.dart`; triggers on app start, resume, and connectivity regained |
| User logs in only once | Credentials restored from the secure enclave; no re-prompt (§5) |
| Credentials survive normal restarts | Keychain/Keystore persistence (`PlatformSecureStore`) |
| Disconnect securely erases credentials | `wipeProvider` — namespaced, scoped, history preserved (`roster_sync_test.dart`) |
| Backend processes normalized roster only | Router rejects raw `ics` from device clients (422); golden parity guard (§9) |
| Future providers follow the same model unless explicitly approved | `RosterConnector` interface + `owner_approved_server_orchestration()` + ODR-004 |
