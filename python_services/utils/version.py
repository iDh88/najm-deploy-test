"""Single source of truth for the deployed service version.

Consumed by main.py (the FastAPI app version, hence /docs and the OpenAPI
document) and by GET /v1/ai/status (the Profile "AI Status" card). One
constant, so the API, its docs and the app's UI can never disagree about
which build is running.
"""
SERVICE_VERSION = "2.0.0"
