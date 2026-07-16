# Offline Verification Harness

Purpose-built tooling that let the release-remediation pass **execute** the
Python test-suite, typecheck the Cloud Functions TypeScript, and lint-guard
the tree inside a network-isolated container (no pip/npm installs possible).

**This harness is a verification aid, not the source of truth.** CI
(`.github/workflows/ci.yml`) runs the real toolchain — pytest, real
FastAPI/pydantic/firebase-admin, `tsc` against real `node_modules`,
`flutter analyze` + `flutter test`, and the Firebase emulator rules tests.
Harness results are labelled as such wherever they appear in reports.

## Contents

| Path | What it is |
|---|---|
| `run_tests.py` | Mini-pytest: discovers `python_services/tests`, resolves conftest/module fixtures (function+session scope, autouse, yield), applies `parametrize`/`skip`/`asyncio` marks, prints a pytest-style summary. Tests whose imports need the real HTTP stack are reported **SKIPPED-OFFLINE**, never silently passed. |
| `shims/` | Import-satisfying stand-ins for third-party packages (`pydantic` v2 subset, `fastapi` decorators/DI markers, `pytest`, `pytz` over zoneinfo, `firebase_admin` constants, `anthropic`, `httpx`, `openpyxl`, `pdfplumber`, `uvicorn`). Shims raise a clearly-marked `"offline shim"` error on any operation that would need network/IO, which the runner converts into SKIPPED-OFFLINE. |
| `ts_stubs/` | Structural `.d.ts` declarations for `firebase-functions` (v1 entrypoint), `firebase-admin`, `axios`, and minimal Node globals, plus `tsconfig.offline.json`. Enables `tsc -p ts_stubs/tsconfig.offline.json` to strict-typecheck `firebase/functions/src` with no `node_modules`. |
| `check_undefined_names.py` | stdlib-`symtable` approximation of ruff **F821** (undefined names). Used to pre-verify the tree before `ruff check` became a blocking CI step. |

## Running

```bash
# From the repository root:
python3 tools/offline_harness/run_tests.py            # whole suite
python3 tools/offline_harness/run_tests.py legality   # filter by substring
python3 tools/offline_harness/check_undefined_names.py python_services
cd tools/offline_harness/ts_stubs && tsc -p tsconfig.offline.json
```

Always run from the paths shown — several checks walk relative paths.
(The remediation itself was briefly misled by running a `lib/`-relative Dart
check from the wrong directory; see FINAL_RELEASE_REPORT.md "process notes".)

## Fidelity notes (read before trusting a green run)

* **Shims are structural, not behavioral.** A green harness run proves the
  business logic executes and asserts correctly against faithful data
  models; it does not prove HTTP routing, serialization details, or SDK
  behavior. That's CI's job.
* The `pytz` shim implements `localize`/`normalize` on zone objects because
  production code paths call them on naive datetimes. An earlier shim
  without them passed the suite (whose fixtures are tz-aware) while
  diverging from production — the fix is kept as a cautionary example of
  why shims must mirror the *used* surface, not just import.
* The TS stubs intentionally model `firebase-functions/v1` (this codebase
  uses the 1st-gen builder API, which in `firebase-functions@^5` lives under
  the `/v1` entrypoint) and non-optional `QueryDocumentSnapshot.data()`,
  matching the real typings' strictness.
* **Run path-walking checkers from the directory they expect.** The Dart
  import checker walks `lib/` relative to cwd; invoked from the repo root it
  walks nothing and reports a false "0 unresolved" (this exact false negative
  briefly masked 20 broken imports during remediation — pass 2 changelog).
  Any green result that reports **0 files scanned** is a wrong-cwd run, not a
  clean tree.
