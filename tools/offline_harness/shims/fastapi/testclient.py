class TestClient:
    def __init__(self, app, **kw):
        raise RuntimeError(
            "offline shim: fastapi.testclient.TestClient requires real FastAPI. "
            "Integration tests are skipped offline — run them in CI.")
