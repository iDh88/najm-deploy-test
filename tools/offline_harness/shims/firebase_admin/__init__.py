"""Offline firebase_admin shim — import-satisfying; tests patch utils.firebase
accessors with MagicMock, so nothing here performs I/O."""
_apps = {}
def initialize_app(credential=None, options=None, name="[DEFAULT]"):
    _apps[name] = object(); return _apps[name]
def get_app(name="[DEFAULT]"): return _apps.get(name)
