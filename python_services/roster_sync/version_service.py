"""roster_sync/version_service.py — dedup + version history + leg diffs.

Spec: "Download only changed schedules. Avoid duplicate imports. Maintain
version history."

  * Checksum: sha256 over a canonical projection of the legs — identical
    rosters hash identically regardless of provider field ordering.
  * Dedup: an import whose checksum equals the latest stored version is a
    DUPLICATE — recorded as an analytics event, no write, previous roster
    untouched.
  * Diff: legs keyed by (flightNumber, departure-date, origin); added /
    removed / changed counts stored per version so the status screen can say
    "v3: +2 flights, 1 retimed".
"""
from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from typing import Optional

from .schema import NormalizedLeg, NormalizedRoster, VersionEntry


def _leg_key(leg: NormalizedLeg) -> tuple:
    return (leg.flightNumber, leg.departureLT.date().isoformat(), leg.origin)


def _leg_fingerprint(leg: NormalizedLeg) -> str:
    return "|".join([
        leg.flightNumber, leg.origin, leg.destination, leg.legType,
        leg.departureLT.isoformat(), leg.arrivalLT.isoformat(),
        f"{leg.blockHours:.2f}", leg.aircraftType,
        str(leg.layover), f"{leg.layoverHours:.2f}",
    ])


def roster_checksum(roster: NormalizedRoster) -> str:
    canon = "\n".join(sorted(_leg_fingerprint(l) for l in roster.legs))
    return hashlib.sha256(
        f"{roster.period}|{roster.year}\n{canon}".encode()).hexdigest()


def diff_rosters(prev: Optional[NormalizedRoster],
                 new: NormalizedRoster) -> dict:
    if prev is None:
        return {"added": len(new.legs), "removed": 0, "changed": 0}
    old = {_leg_key(l): _leg_fingerprint(l) for l in prev.legs}
    cur = {_leg_key(l): _leg_fingerprint(l) for l in new.legs}
    added = sum(1 for k in cur if k not in old)
    removed = sum(1 for k in old if k not in cur)
    changed = sum(1 for k, fp in cur.items()
                  if k in old and old[k] != fp)
    return {"added": added, "removed": removed, "changed": changed}


# ── Firestore-backed history ─────────────────────────────────────────────────

def _doc_id(user_id: str, provider_id: str, period: str) -> str:
    return f"{user_id}_{provider_id}_{period}".replace("/", "_")


def latest_version(db, user_id: str, provider_id: str,
                   period: str) -> Optional[dict]:
    doc = db.collection("rosterVersions").document(
        _doc_id(user_id, provider_id, period)).get()
    if not getattr(doc, "exists", False):
        return None
    data = doc.to_dict() or {}
    versions = data.get("versions") or []
    return versions[-1] if versions else None


def record_version(db, user_id: str, provider_id: str, period: str,
                   entry: VersionEntry,
                   normalized_snapshot: dict) -> int:
    """Append a version entry (+ the normalized snapshot for future diffs).
    Returns the version number written."""
    ref = db.collection("rosterVersions").document(
        _doc_id(user_id, provider_id, period))
    doc = ref.get()
    data = doc.to_dict() if getattr(doc, "exists", False) else {}
    versions = list(data.get("versions") or [])
    entry_dict = entry.model_dump()
    entry_dict["at"] = entry.at.isoformat()
    versions.append(entry_dict)
    ref.set({
        "userId": user_id,
        "providerId": provider_id,
        "period": period,
        "versions": versions,
        "latestChecksum": entry.checksum,
        "latestSnapshot": normalized_snapshot,   # canonical legs for diffing
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    })
    return entry.version


def next_version_number(db, user_id: str, provider_id: str,
                        period: str) -> int:
    latest = latest_version(db, user_id, provider_id, period)
    return (int(latest["version"]) + 1) if latest else 1


def snapshot_to_roster(snapshot: Optional[dict]) -> Optional[NormalizedRoster]:
    if not snapshot:
        return None
    try:
        return NormalizedRoster(**snapshot)
    except Exception:  # corrupt/old snapshot → treat as no previous
        return None


def load_previous_roster(db, user_id: str, provider_id: str,
                         period: str) -> Optional[NormalizedRoster]:
    doc = db.collection("rosterVersions").document(
        _doc_id(user_id, provider_id, period)).get()
    if not getattr(doc, "exists", False):
        return None
    return snapshot_to_roster((doc.to_dict() or {}).get("latestSnapshot"))
