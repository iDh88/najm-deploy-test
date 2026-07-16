# Najm Local Run

## Why `localhost:3000` did not open from your Chrome

The server started inside the Codex workspace. Your computer's Chrome treats
`localhost` as your own machine, not the Codex container.

## Browse the admin panel quickly

Open:

```text
admin_panel/index.html
```

The admin panel includes a local development mode with mocked Firebase data, so
you can browse the dashboard without Firebase credentials.

## Run on your own machine

From the project root:

```bash
cd python_services
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ENV=development \
INTERNAL_SERVICE_TOKEN=dev-token \
ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000 \
ANTHROPIC_API_KEY=dev-placeholder \
PYTHONPATH=.venv/lib/python3.12/site-packages \
python -m uvicorn main:app --host 0.0.0.0 --port 8080
```

In a second terminal:

```bash
cd admin_panel
npm run dev
```

Then open:

```text
http://localhost:3000
```

## Notes

- Flutter and Firebase CLI were not available in the Codex runtime.
- The local admin panel keeps production Firebase behavior intact, but falls
  back to mock data when opened locally or when Firebase config is still
  `REPLACE_*`.
