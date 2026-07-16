"""Offline FastAPI shim — decorators/DI markers so modules import and unit
tests exercise business logic. No HTTP stack; the integration tests that need
TestClient are skipped offline (see tools/offline_harness/README.md)."""
from __future__ import annotations
import inspect

class HTTPException(Exception):
    def __init__(self, status_code: int, detail=None, headers=None):
        self.status_code = status_code
        self.detail = detail
        self.headers = headers
        super().__init__(f"{status_code}: {detail}")

class _ParamMarker:
    def __init__(self, default=..., **kw):
        self.default = default
        self.meta = kw
def Header(default=..., **kw): return default if default is not ... else None
def Query(default=..., **kw): return default if default is not ... else _ParamMarker(...)
def Form(default=..., **kw): return default if default is not ... else _ParamMarker(...)
def File(default=..., **kw): return _ParamMarker(default, **kw)
def Body(default=..., **kw): return default if default is not ... else _ParamMarker(...)

class Depends:
    def __init__(self, dependency=None): self.dependency = dependency

class UploadFile:
    def __init__(self, filename="", file=None, content_type=""):
        self.filename = filename; self.file = file; self.content_type = content_type
    async def read(self): return self.file.read() if self.file else b""

class BackgroundTasks:
    def __init__(self): self.tasks = []
    def add_task(self, fn, *a, **k): self.tasks.append((fn, a, k))

class _Route:
    def __init__(self, path, endpoint, methods): 
        self.path, self.endpoint, self.methods = path, endpoint, methods

class APIRouter:
    def __init__(self, **kw): self.routes = []
    def _reg(self, method, path, **kw):
        def deco(fn):
            self.routes.append(_Route(path, fn, [method])); return fn
        return deco
    def get(self, path, **kw): return self._reg("GET", path, **kw)
    def post(self, path, **kw): return self._reg("POST", path, **kw)
    def put(self, path, **kw): return self._reg("PUT", path, **kw)
    def patch(self, path, **kw): return self._reg("PATCH", path, **kw)
    def delete(self, path, **kw): return self._reg("DELETE", path, **kw)
    def include_router(self, other, prefix="", **kw):
        for r in other.routes: self.routes.append(_Route(prefix + r.path, r.endpoint, r.methods))

class Request:
    def __init__(self, headers=None): self.headers = headers or {}

class FastAPI(APIRouter):
    def __init__(self, **kw):
        super().__init__()
        self.middleware = []
        self.lifespan = kw.get("lifespan")
    def add_middleware(self, mw, **kw): self.middleware.append((mw, kw))

class status:
    HTTP_200_OK = 200; HTTP_401_UNAUTHORIZED = 401
    HTTP_403_FORBIDDEN = 403; HTTP_404_NOT_FOUND = 404
