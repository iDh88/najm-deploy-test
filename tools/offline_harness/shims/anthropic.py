"""Offline anthropic shim — tests patch the client; this only satisfies import."""
class APIError(Exception): pass
class _Messages:
    def create(self, **kw): raise APIError("offline shim: no network")
class Anthropic:
    def __init__(self, api_key=None, **kw): self.messages = _Messages()
