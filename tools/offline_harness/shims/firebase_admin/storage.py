def bucket(name=None, app=None):
    raise RuntimeError("offline shim: storage.bucket — tests must patch utils.firebase.get_storage")
