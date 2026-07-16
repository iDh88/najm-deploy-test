"""
utils/logging_config.py — structured, PDPL-safe logging (Phase 2 / T6).

Design stance:
  The reliable PDPL control is *not logging* roster/PII in the first place
  (names, crew ids, schedules, salary). Regex redaction of arbitrary names is
  unreliable, so this module (a) emits structured JSON logs with a request-id
  field for correlation, and (b) applies a backstop filter that scrubs obvious
  SECRETS (bearer tokens, JWT-like and long hex strings) which must never reach
  logs. Treat PII avoidance as a code-review rule; treat this as the safety net.

Adopt by calling `setup_logging()` once at startup.
"""
import json
import logging
import os
import re
from contextvars import ContextVar

# Correlation id available to every log record within a request.
request_id_var: ContextVar[str] = ContextVar("request_id", default="-")

# Backstop patterns for SECRETS (not a substitute for not logging PII).
_SECRET_PATTERNS = [
    (re.compile(r"Bearer\s+[A-Za-z0-9._\-]+", re.I), "Bearer [REDACTED]"),
    (re.compile(r"eyJ[A-Za-z0-9._\-]{20,}"), "[JWT_REDACTED]"),          # JWTs
    (re.compile(r"\b[A-Fa-f0-9]{32,}\b"), "[HEX_REDACTED]"),            # tokens/hashes
    # Zero-Knowledge directive: automatic key=value redaction for
    # password / token / secret / authorization / cookie / credential /
    # session / prn — any "key: value" or "key=value" shape, quoted or not.
    (re.compile(
        r"(?P<key>['\"]?(?:[A-Za-z0-9_\-]*"
        r"(?:password|passwd|secret|token|credential|authorization|"
        r"cookie|session|prn)[A-Za-z0-9_\-]*)['\"]?\s*[:=]\s*)"
        r"['\"]?[^'\",;\s}]+['\"]?",
        re.I), r"\g<key>[REDACTED]"),
]


def _redact(text: str) -> str:
    for pat, repl in _SECRET_PATTERNS:
        text = pat.sub(repl, text)
    return text


class SecretRedactionFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            record.msg = _redact(record.msg)
        if record.args:
            try:
                record.args = tuple(
                    _redact(a) if isinstance(a, str) else a for a in record.args
                )
            except Exception:
                pass
        return True


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "request_id": request_id_var.get(),
            "msg": record.getMessage(),
        }
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def setup_logging() -> None:
    """Configure root logging. JSON in production, plain text in development."""
    level = os.getenv("LOG_LEVEL", "INFO").upper()
    handler = logging.StreamHandler()
    handler.addFilter(SecretRedactionFilter())
    if os.getenv("ENV") == "development":
        handler.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)s %(name)s [%(request_id)s] %(message)s"
            if False else "%(asctime)s %(levelname)s %(name)s %(message)s"
        ))
    else:
        handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
