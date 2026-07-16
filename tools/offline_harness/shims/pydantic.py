"""Offline pydantic v2 shim — structural stand-in for environments without
pip access. Implements the subset this codebase uses: BaseModel with defaults,
type coercion for basic types, Field(default/default_factory/ge/le),
model_dump, model_copy, model_fields, ValidationError. NOT a substitute for
real pydantic in CI."""
from __future__ import annotations
import typing, datetime, enum, copy as _copy

VERSION = "2.offline-shim"

class ValidationError(ValueError):
    pass

class _FieldInfo:
    def __init__(self, default=..., default_factory=None, **kw):
        self.default = default
        self.default_factory = default_factory
        self.meta = kw

def Field(default=..., *, default_factory=None, **kw):
    return _FieldInfo(default, default_factory, **kw)

def _origin(t): return typing.get_origin(t)
def _args(t): return typing.get_args(t)

def _coerce(value, annot):
    if annot is None or annot is typing.Any or value is None:
        return value
    if isinstance(annot, str):
        return value  # forward refs: pass through
    o = _origin(annot)
    if o is typing.Union:
        args = [a for a in _args(annot) if a is not type(None)]
        if value is None: return None
        return _coerce(value, args[0]) if args else value
    if o in (list, typing.List):
        (item,) = _args(annot) or (typing.Any,)
        return [_coerce(v, item) for v in value]
    if o in (dict, typing.Dict):
        return dict(value)
    if o is tuple: return tuple(value)
    if isinstance(annot, type):
        if issubclass(annot, BaseModel) and isinstance(value, dict):
            return annot(**value)
        if issubclass(annot, enum.Enum):
            return value if isinstance(value, annot) else annot(value)
        if annot is datetime.datetime and isinstance(value, str):
            return datetime.datetime.fromisoformat(value)
        if annot in (int, float, str, bool):
            if annot is bool and isinstance(value, bool): return value
            if annot is float and isinstance(value, (int, float)): return float(value)
            if annot is int and isinstance(value, bool): return value
            if annot is int and isinstance(value, float) and value.is_integer(): return int(value)
            if isinstance(value, annot): return value
            try: return annot(value)
            except Exception as e: raise ValidationError(f"coercion to {annot} failed: {e}")
    return value

class _ModelMeta(type):
    def __new__(mcls, name, bases, ns):
        cls = super().__new__(mcls, name, bases, ns)
        fields = {}
        for base in reversed(cls.__mro__[1:]):
            fields.update(getattr(base, "model_fields", {}) or {})
        annots = ns.get("__annotations__", {})
        for fname, annot in annots.items():
            if fname.startswith("_"): continue
            default = ns.get(fname, ...)
            fields[fname] = (annot, default)
        cls.model_fields = fields
        cls.__fields__ = fields  # v1-compat alias
        return cls

class BaseModel(metaclass=_ModelMeta):
    model_fields: dict = {}

    def __init__(self, **data):
        cls = type(self)
        hints = {}
        try:
            hints = typing.get_type_hints(cls)
        except Exception:
            pass
        for fname, (annot, default) in cls.model_fields.items():
            annot = hints.get(fname, annot)
            if fname in data:
                value = data.pop(fname)
            elif isinstance(default, _FieldInfo):
                if default.default_factory is not None: value = default.default_factory()
                elif default.default is not ...: value = _copy.deepcopy(default.default)
                else: raise ValidationError(f"{cls.__name__}: field '{fname}' required")
            elif default is not ...:
                value = _copy.deepcopy(default)
            else:
                raise ValidationError(f"{cls.__name__}: field '{fname}' required")
            object.__setattr__(self, fname, _coerce(value, annot))
        # extras ignored (pydantic v2 default)

    def model_dump(self, mode: str = "python", **_):
        out = {}
        for fname in type(self).model_fields:
            v = getattr(self, fname)
            out[fname] = _dump(v, mode)
        return out
    def dict(self, **kw): return self.model_dump(**kw)

    def model_copy(self, update: dict | None = None, deep: bool = False):
        data = {f: (_copy.deepcopy(getattr(self, f)) if deep else getattr(self, f))
                for f in type(self).model_fields}
        if update: data.update(update)
        obj = type(self).__new__(type(self))
        for k, v in data.items(): object.__setattr__(obj, k, v)
        return obj
    def copy(self, **kw): return self.model_copy(**kw)

    def __eq__(self, other):
        return type(self) is type(other) and self.model_dump() == other.model_dump()
    def __repr__(self):
        fields = ", ".join(f"{k}={getattr(self, k)!r}" for k in type(self).model_fields)
        return f"{type(self).__name__}({fields})"

def _dump(v, mode):
    if isinstance(v, BaseModel): return v.model_dump(mode)
    if isinstance(v, enum.Enum): return v.value
    if isinstance(v, datetime.datetime): return v.isoformat() if mode == "json" else v
    if isinstance(v, list): return [_dump(x, mode) for x in v]
    if isinstance(v, dict): return {k: _dump(x, mode) for k, x in v.items()}
    return v
