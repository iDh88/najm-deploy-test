# NAJM — Secrets Management

**Owner:** platform/DevOps · **ADRs:** 003 (secrets), 004 (auth), 000 (portability)
**Rule:** secrets live in **Secret Manager** (cloud) or **`.env`** (local) — never in
source, images, logs, or any client. Firebase *web* API keys are public
identifiers and are **not** secrets.

---

## 1. Secret inventory

This table records current runtime consumers. Provider-specific rows describe
the legacy monolithic deployment; they do not authorize the target call path.

| Secret | Env var (runtime) | Secret Manager id | Consumed by | Purpose |
|---|---|---|---|---|
| Service token | `INTERNAL_SERVICE_TOKEN` | `internal-service-token` | Python (`utils/auth`), Functions | Cloud Functions → Python service-to-service auth |
| Anthropic key | `ANTHROPIC_API_KEY` | `anthropic-api-key` | Python (`ai/`) | Claude — assistant, filters, explanations |
| OpenAI key | `OPENAI_API_KEY` | `openai-api-key` | Python (`knowledge_engine/embeddings.py`) | Knowledge-base embeddings (optional feature) |
| Admin bootstrap | `ADMIN_SETUP_TOKEN` | `admin-setup-token` | Functions (`admin_setup.ts`), `scripts/setup_super_admin.sh` | One-time super-admin bootstrap |

**Local-only (not a Secret Manager secret):** `GOOGLE_APPLICATION_CREDENTIALS`
— a path to a service-account key file used **only** in local development.
In the cloud the service authenticates via **Application Default Credentials
(ADC)** — the Cloud Run runtime service account — so no key file exists there.

### Approved target provider-secret boundary

- Provider credentials remain environment-specific, server-side Secret Manager
  secrets. Only the corresponding Provider Adapter may resolve or use a
  provider credential in the approved target architecture.
- Flutter, admin clients, Product APIs, domain engines, Cloud Functions, tools,
  the AI Orchestrator, and the AI Gateway must never receive provider secret
  values. Provider and Model Registries store only opaque logical credential-
  binding identifiers, never secret values or secret-bearing URIs.
- Provider secrets must not enter prompts, RAG, memory, caches, Firestore
  control-plane records, telemetry, provider payload logs, error messages, or
  audit-event content.
- The same boundary applies to GLM, Claude, OpenAI, Gemini, DeepSeek, Qwen, and
  any future provider. Documenting this pattern does not approve or enable a
  provider.
- Logical adapter isolation is mandatory even while adapters share one
  FastAPI deployment. Narrower runtime IAM follows only if a later approved
  physical separation supports it.

Phase 1 does not change secret values, grants, commands, or runtime behavior.
The current direct Anthropic/OpenAI consumers and shared runtime identity
remain legacy implementation facts until separately migrated.

---

## 2. Sourcing model per environment

| Environment | Secrets from | Firebase creds | Notes |
|---|---|---|---|
| **local** | `.env` (git-ignored) | Emulators need none; ADC via `gcloud auth application-default login` only if hitting real GCP | `start.sh` runs against `demo-najm` emulators — credential-free |
| **dev** | Secret Manager in `cip-najm-dev` | Cloud Run runtime SA (ADC) | — |
| **staging** | Secret Manager in `cip-najm-staging` | Cloud Run runtime SA (ADC) | prod mirror |
| **prod** | Secret Manager in `cip-najm` | Cloud Run runtime SA (ADC) | — |

The Python service reads every value via `os.environ`, so `--set-secrets`
injects them transparently — **no application code changes** to move a value
between `.env` and Secret Manager.

---

## 3. Local development

```bash
cp .env.example .env          # setup.sh does this automatically if .env is absent
# Fill in the SECRETS block. For emulator-only local work you can leave the
# cloud keys as placeholders — the assistant/KB features just stay "unconfigured".
```

`.env` is git-ignored (verified) and scanned by gitleaks in CI. Never commit it.

---

## 4. Cloud: creating & granting secrets (manual — run yourself)

> These commands **create real secrets** and are intentionally NOT run by any
> script or agent. Run them once per target project (`cip-najm-dev`,
> `cip-najm-staging`, `cip-najm`). Replace `PROJECT` and the value placeholders.

Create a secret (value read from stdin, never from your shell history):

```bash
PROJECT=cip-najm     # or cip-najm-dev / cip-najm-staging

for name in internal-service-token anthropic-api-key openai-api-key admin-setup-token; do
  gcloud secrets create "$name" --project "$PROJECT" --replication-policy=automatic 2>/dev/null || true
done

# Add a version with the actual value (example for one secret):
printf %s "REPLACE_WITH_REAL_VALUE" | \
  gcloud secrets versions add anthropic-api-key --project "$PROJECT" --data-file=-
```

Generate a strong `internal-service-token`:

```bash
printf %s "$(openssl rand -hex 32)" | \
  gcloud secrets versions add internal-service-token --project "$PROJECT" --data-file=-
```

Grant the **Cloud Run runtime service account** read access (so the running
service can resolve `--set-secrets`):

```bash
RUNTIME_SA="$(gcloud run services describe cip-python-services \
  --project "$PROJECT" --region me-central1 \
  --format='value(spec.template.spec.serviceAccountName)')"
# If the service does not exist yet, use the default compute SA:
#   RUNTIME_SA="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')-compute@developer.gserviceaccount.com"

for name in internal-service-token anthropic-api-key openai-api-key admin-setup-token; do
  gcloud secrets add-iam-policy-binding "$name" --project "$PROJECT" \
    --member "serviceAccount:${RUNTIME_SA}" \
    --role roles/secretmanager.secretAccessor
done
```

The **deployer** service account (used by `deploy.yml` via WIF) also needs
`roles/secretmanager.secretAccessor` (noted in the workflow header).

---

## 5. Rotation

Secrets use `:latest` in `deploy.yml`, so rotation is: add a new version, then
redeploy (or restart the service to pick it up).

```bash
printf %s "NEW_VALUE" | gcloud secrets versions add anthropic-api-key --project "$PROJECT" --data-file=-
# then trigger the gated Deploy workflow for python-services (or:)
gcloud run services update cip-python-services --project "$PROJECT" --region me-central1
```

Disable a leaked version:

```bash
gcloud secrets versions disable VERSION --secret anthropic-api-key --project "$PROJECT"
```

---

## 6. Required GitHub Actions repo variables (for deploy.yml)

| Variable | Example |
|---|---|
| `vars.GCP_PROJECT_ID` | `cip-najm` |
| `vars.GCP_REGION` | `me-central1` |
| `vars.GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/…/providers/…` |
| `vars.GCP_SERVICE_ACCOUNT` | `deployer@cip-najm.iam.gserviceaccount.com` |
| `vars.ALLOWED_ORIGINS` | `https://cip-najm.web.app,https://cip-najm.firebaseapp.com` |

No **secrets** are stored in GitHub Actions — deploy auth uses Workload Identity
Federation (keyless), and app secrets come from Secret Manager at runtime.

---

## 7. Guarantees & scanning

- **Client isolation:** the Flutter and Admin clients reference **no** server
  secret (verified; enforced in CI — see the client-secret check in `ci.yml`).
  The client only receives the public `AI_SERVICE_URL` build arg and public
  Firebase web config.
- **Secret scanning:** `security.yml` runs **gitleaks** on every push/PR over
  full history, plus CodeQL. After the initial import, run once manually:
  `gitleaks detect --source . --log-opts="--all"`.
- **Never** paste a real secret into a commit, PR, issue, log line, or this doc.
