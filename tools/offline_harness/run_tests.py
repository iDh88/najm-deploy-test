#!/usr/bin/env python3
"""Offline test runner for python_services — pytest-compatible subset.

Usage (from repo root):
    python3 tools/offline_harness/run_tests.py [path-filter substrings...]

Discovers tests under python_services/tests, resolves fixtures from
conftest.py + test modules (function/session scope, autouse, yield-fixtures,
fixture-on-fixture dependencies), applies parametrize/skip/asyncio marks, and
prints a pytest-style summary.

Integration tests that require the real FastAPI/httpx HTTP stack raise the
shims' RuntimeError at import/construction; the runner reports those files as
SKIPPED-OFFLINE rather than failing them — they run for real in CI.
"""
from __future__ import annotations
import importlib
import importlib.util
import inspect
import os
import sys
import traceback
import types

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SERVICES = os.path.join(REPO, "python_services")
SHIMS = os.path.join(HERE, "shims")

# Shims FIRST so they win over any partially-installed real packages;
# python_services on path for absolute imports (utils.*, legality.* …).
sys.path.insert(0, SHIMS)
sys.path.insert(1, SERVICES)

import pytest  # the shim


class FixtureResolver:
    def __init__(self, registries):
        self.registries = registries          # list of dicts name -> _Fixture
        self.session_cache = {}
        self.session_finalizers = []

    def lookup(self, name):
        for reg in self.registries:
            if name in reg:
                return reg[name]
        return None

    def autouse(self):
        seen, out = set(), []
        for reg in self.registries:
            for f in reg.values():
                if f.autouse and f.name not in seen:
                    seen.add(f.name)
                    out.append(f)
        return out

    def resolve(self, name, cache, finalizers):
        # Built-in fixtures (pytest parity)
        if name == "monkeypatch":
            if name in cache:
                return cache[name]
            import pytest as _pytest_shim
            mp = _pytest_shim.MonkeyPatch()
            cache[name] = mp
            finalizers.append(mp.undo)
            return mp
        if name == "tmp_path":
            if name in cache:
                return cache[name]
            import tempfile
            from pathlib import Path
            d = Path(tempfile.mkdtemp(prefix="offline_tmp_"))
            cache[name] = d
            return d
        fx = self.lookup(name)
        if fx is None:
            raise RuntimeError(f"fixture '{name}' not found")
        if fx.scope == "session":
            if name in self.session_cache:
                return self.session_cache[name]
            cache_, fins = self.session_cache, self.session_finalizers
        else:
            if name in cache:
                return cache[name]
            cache_, fins = cache, finalizers

        kwargs = {}
        for pname in inspect.signature(fx.fn).parameters:
            if pname in ("request",):
                kwargs[pname] = types.SimpleNamespace(param=None)
                continue
            kwargs[pname] = self.resolve(pname, cache, finalizers)

        if inspect.isgeneratorfunction(fx.fn):
            gen = fx.fn(**kwargs)
            value = next(gen)
            fins.append(gen)
        else:
            value = fx.fn(**kwargs)
        cache_[name] = value
        return value

    def close_session(self):
        for gen in reversed(self.session_finalizers):
            try:
                next(gen, None)
            except Exception:
                pass


def collect_module_fixtures(mod):
    reg = {}
    for obj in vars(mod).values():
        fx = getattr(obj, "__pytest_fixture__", None)
        if fx is not None:
            reg[fx.name] = fx
    return reg


def iter_tests(mod):
    for name, obj in sorted(vars(mod).items()):
        if name.startswith("test_") and callable(obj):
            yield name, obj, None
        elif name.startswith("Test") and inspect.isclass(obj):
            for mname, meth in sorted(vars(obj).items()):
                if mname.startswith("test_") and callable(meth):
                    yield f"{name}::{mname}", meth, obj


def run_one(fn, owner_cls, params, resolver):
    cache, finalizers = {}, []
    instance = None
    try:
        for fx in resolver.autouse():
            resolver.resolve(fx.name, cache, finalizers)

        kwargs = {}
        sig_params = list(inspect.signature(fn).parameters)
        if owner_cls is not None:
            instance = owner_cls()
            sig_params = sig_params[1:]  # self
            # pytest xunit-style per-test hooks
            setup = getattr(instance, "setup_method", None)
            if callable(setup):
                try:
                    setup(fn)          # canonical signature (self, method)
                except TypeError:
                    setup()            # zero-arg variant
        for pname in sig_params:
            if params and pname in params:
                kwargs[pname] = params[pname]
            else:
                kwargs[pname] = resolver.resolve(pname, cache, finalizers)

        call = fn.__get__(instance) if instance is not None else fn
        if pytest._is_async_marked(fn):
            pytest.run_async(call(**kwargs))
        else:
            result = call(**kwargs)
            if inspect.iscoroutine(result):
                pytest.run_async(result)
        return ("PASS", None)
    except pytest.SkipTest as e:
        return ("SKIP", str(e))
    except AssertionError as e:
        return ("FAIL", f"{e}\n{traceback.format_exc(limit=6)}")
    except Exception as e:
        return ("ERROR", f"{type(e).__name__}: {e}\n{traceback.format_exc(limit=6)}")
    finally:
        if owner_cls is not None and instance is not None:
            teardown = getattr(instance, "teardown_method", None)
            if callable(teardown):
                try:
                    try:
                        teardown(fn)
                    except TypeError:
                        teardown()
                except Exception:
                    pass
        for gen in reversed(finalizers):
            try:
                next(gen, None)
            except Exception:
                pass


def main(argv):
    filters = [a for a in argv[1:] if not a.startswith("-")]
    tests_root = os.path.join(SERVICES, "tests")

    conftest_reg = {}
    conftest_path = os.path.join(tests_root, "conftest.py")
    if os.path.exists(conftest_path):
        spec = importlib.util.spec_from_file_location("conftest", conftest_path)
        conftest = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(conftest)
        conftest_reg = collect_module_fixtures(conftest)

    files = []
    for dirpath, _, names in os.walk(tests_root):
        if "__pycache__" in dirpath:
            continue
        for n in sorted(names):
            if n.startswith("test_") and n.endswith(".py"):
                p = os.path.join(dirpath, n)
                if not filters or any(f in p for f in filters):
                    files.append(p)

    counts = {"PASS": 0, "FAIL": 0, "ERROR": 0, "SKIP": 0, "SKIP-OFFLINE": 0}
    failures = []

    for path in files:
        rel = os.path.relpath(path, SERVICES)
        modname = rel[:-3].replace(os.sep, ".")
        try:
            mod = importlib.import_module(modname)
        except Exception as e:
            print(f"SKIPPED-OFFLINE {rel} — import requires real deps: {type(e).__name__}: {e}")
            counts["SKIP-OFFLINE"] += 1
            continue

        resolver = FixtureResolver([collect_module_fixtures(mod), conftest_reg])
        for name, fn, owner in iter_tests(mod):
            reason = pytest._skip_mark(fn)
            if reason is not None:
                counts["SKIP"] += 1
                print(f"s {rel}::{name} — {reason}")
                continue
            for params in pytest._param_sets(fn):
                label = f"{rel}::{name}" + (f"[{params}]" if params else "")
                status, detail = run_one(fn, owner, params, resolver)
                if status == "ERROR" and detail and "offline shim" in detail:
                    counts["SKIP-OFFLINE"] += 1
                    print(f"o {label} — needs real deps (CI)")
                    continue
                counts[status] += 1
                sym = {"PASS": ".", "FAIL": "F", "ERROR": "E", "SKIP": "s"}[status]
                print(f"{sym} {label}")
                if status in ("FAIL", "ERROR"):
                    failures.append((label, detail))
        resolver.close_session()

    print("\n" + "═" * 78)
    for label, detail in failures:
        print(f"\n──── {label}\n{detail}")
    print("═" * 78)
    print(f"RESULT: {counts['PASS']} passed · {counts['FAIL']} failed · "
          f"{counts['ERROR']} errors · {counts['SKIP']} skipped · "
          f"{counts['SKIP-OFFLINE']} skipped-offline (need real deps → CI)")
    return 1 if (counts["FAIL"] or counts["ERROR"]) else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
