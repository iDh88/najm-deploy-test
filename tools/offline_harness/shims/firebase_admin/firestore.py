SERVER_TIMESTAMP = object()
class Increment:
    def __init__(self, n): self.n = n
class ArrayUnion:
    def __init__(self, values): self.values = values
class ArrayRemove:
    def __init__(self, values): self.values = values
class Query:
    DESCENDING = "DESCENDING"; ASCENDING = "ASCENDING"
def client(app=None):
    raise RuntimeError("offline shim: firestore.client — tests must patch utils.firebase.get_firestore")
