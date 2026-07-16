class AsyncClient:
    def __init__(self, *a, **k):
        raise RuntimeError("offline shim: httpx requires network stack — run in CI.")
