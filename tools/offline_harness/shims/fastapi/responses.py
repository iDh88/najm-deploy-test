class JSONResponse:
    def __init__(self, content=None, status_code=200, **kw):
        self.body = content; self.status_code = status_code
class Response(JSONResponse): pass
