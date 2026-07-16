"""Offline pytest shim + runner core.

Implements the subset used by this repo's test-suite: @pytest.fixture
(function/session scope, autouse, yield-fixtures), pytest.raises,
pytest.approx, pytest.mark.asyncio / .skip / .parametrize, pytest.skip,
class-based Test* collection, conftest fixtures.

This is a VERIFICATION AID for network-less environments. CI runs real pytest
(see .github/workflows/ci.yml); results from this runner are labelled as
offline-harness results in reports.
"""
from __future__ import annotations
import asyncio
import inspect
import math
from contextlib import contextmanager

__version__ = "offline-shim"

# ── Fixtures ─────────────────────────────────────────────────────────────────

class _Fixture:
    def __init__(self, fn, scope="function", autouse=False, name=None):
        self.fn = fn
        self.scope = scope
        self.autouse = autouse
        self.name = name or fn.__name__

def fixture(fn=None, *, scope="function", autouse=False, name=None):
    def wrap(f):
        f.__pytest_fixture__ = _Fixture(f, scope=scope, autouse=autouse, name=name)
        return f
    return wrap(fn) if fn is not None else wrap

# ── Marks ────────────────────────────────────────────────────────────────────

class _MarkDecor:
    def __init__(self, name, args=(), kwargs=None):
        self.name = name; self.args = args; self.kwargs = kwargs or {}
    def __call__(self, *args, **kwargs):
        if self.name in ("skip", "skipif", "xfail") and args and callable(args[0]) and not kwargs:
            fn = args[0]
            _add_mark(fn, _MarkDecor(self.name))
            return fn
        if args and callable(args[0]) and len(args) == 1 and not kwargs:
            fn = args[0]
            _add_mark(fn, self)
            return fn
        return _MarkDecor(self.name, args, kwargs)

def _add_mark(fn, mark):
    marks = getattr(fn, "__pytest_marks__", [])
    marks.append(mark)
    fn.__pytest_marks__ = marks

class _Mark:
    def __getattr__(self, name):
        return _MarkDecor(name)

mark = _Mark()

def param(*values, id=None):
    return values if len(values) > 1 else values[0]

# ── skip / fail ──────────────────────────────────────────────────────────────

class SkipTest(Exception):
    pass

def skip(reason=""):
    raise SkipTest(reason)

def fail(reason=""):
    raise AssertionError(reason)

skip.Exception = SkipTest

# ── raises ───────────────────────────────────────────────────────────────────

class _RaisesInfo:
    def __init__(self):
        self.value = None
        self.type = None

@contextmanager
def raises(expected, match=None):
    info = _RaisesInfo()
    try:
        yield info
    except expected as e:
        info.value = e
        info.type = type(e)
        if match is not None:
            import re
            if not re.search(match, str(e)):
                raise AssertionError(
                    f"raised {type(e).__name__}({e!r}) but message does not match {match!r}")
        return
    except SkipTest:
        raise
    except Exception as e:
        raise AssertionError(
            f"expected {getattr(expected, '__name__', expected)}, got {type(e).__name__}: {e}") from e
    raise AssertionError(f"did not raise {getattr(expected, '__name__', expected)}")

# ── approx ───────────────────────────────────────────────────────────────────

class _Approx:
    def __init__(self, expected, rel=None, abs=None):
        self.expected = expected
        self.rel = 1e-6 if rel is None else rel
        self.abs = 1e-12 if abs is None else abs
    def _ok(self, a, b):
        return math.isclose(float(a), float(b), rel_tol=self.rel, abs_tol=self.abs)
    def __eq__(self, other):
        e = self.expected
        if isinstance(e, dict):
            return set(e) == set(other) and all(self._ok(other[k], e[k]) for k in e)
        if isinstance(e, (list, tuple)):
            return len(e) == len(other) and all(self._ok(o, x) for o, x in zip(other, e))
        return self._ok(other, e)
    def __req__(self, other):
        return self.__eq__(other)
    def __repr__(self):
        return f"approx({self.expected!r})"

def approx(expected, rel=None, abs=None):
    return _Approx(expected, rel=rel, abs=abs)

# ── Runner support (used by tools/offline_harness/run_tests.py) ─────────────

def _is_async_marked(fn):
    return any(m.name == "asyncio" for m in getattr(fn, "__pytest_marks__", [])) \
        or inspect.iscoroutinefunction(fn)

def _param_sets(fn):
    """Cartesian product across ALL stacked @pytest.mark.parametrize marks
    (real-pytest semantics). Returns [None] for unparametrized tests."""
    mark_sets = []
    for m in getattr(fn, "__pytest_marks__", []):
        if m.name != "parametrize":
            continue
        names = [n.strip() for n in m.args[0].split(",")]
        rows = []
        for row in m.args[1]:
            if len(names) == 1:
                rows.append({names[0]: row})
            else:
                rows.append(dict(zip(names, row)))
        mark_sets.append(rows)
    if not mark_sets:
        return [None]
    combos = [{}]
    for rows in mark_sets:
        combos = [{**c, **r} for c in combos for r in rows]
    return combos

def _skip_mark(fn):
    for m in getattr(fn, "__pytest_marks__", []):
        if m.name == "skip":
            return m.kwargs.get("reason", m.args[0] if m.args else "")
        if m.name == "skipif" and m.args and m.args[0]:
            return m.kwargs.get("reason", "skipif condition true")
    return None

def run_async(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


class MonkeyPatch:
    """Faithful subset of pytest's monkeypatch: setattr/delattr on objects
    or dotted "module.attr" strings, setenv/delenv, setitem/delitem — all
    undone (LIFO) at teardown."""

    def __init__(self):
        self._undo = []

    # attributes
    def setattr(self, target, name, value=None, raising=True):
        import importlib
        if isinstance(target, str) and value is None:
            target, _, name2 = target.rpartition(".")
            value, name = name, name2
            target = importlib.import_module(target)
        had = hasattr(target, name)
        old = getattr(target, name, None)
        if raising and not had:
            raise AttributeError(name)
        self._undo.append(("attr", target, name, had, old))
        setattr(target, name, value)

    def delattr(self, target, name, raising=True):
        had = hasattr(target, name)
        if not had:
            if raising:
                raise AttributeError(name)
            return
        self._undo.append(("attr", target, name, True, getattr(target, name)))
        delattr(target, name)

    # environment
    def setenv(self, name, value):
        import os
        self._undo.append(("env", None, name, name in os.environ,
                           os.environ.get(name)))
        os.environ[name] = str(value)

    def delenv(self, name, raising=True):
        import os
        had = name in os.environ
        if not had:
            if raising:
                raise KeyError(name)
            return
        self._undo.append(("env", None, name, True, os.environ[name]))
        del os.environ[name]

    # mappings
    def setitem(self, mapping, key, value):
        had = key in mapping
        self._undo.append(("item", mapping, key, had,
                           mapping.get(key)))
        mapping[key] = value

    def delitem(self, mapping, key, raising=True):
        had = key in mapping
        if not had:
            if raising:
                raise KeyError(key)
            return
        self._undo.append(("item", mapping, key, True, mapping[key]))
        del mapping[key]

    def undo(self):
        import os
        while self._undo:
            kind, target, name, had, old = self._undo.pop()
            if kind == "attr":
                if had:
                    setattr(target, name, old)
                else:
                    try:
                        delattr(target, name)
                    except AttributeError:
                        pass
            elif kind == "env":
                if had:
                    os.environ[name] = old
                else:
                    os.environ.pop(name, None)
            else:
                if had:
                    target[name] = old
                else:
                    target.pop(name, None)
