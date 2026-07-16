#!/usr/bin/env python3
"""
Seed the Firestore ``legalityRules`` collection with the canonical FTL defaults.

Purpose
-------
The admin panel edits documents in ``legalityRules`` and (since remediation
pass 2) the Python legality engines actually READ them via
``legality.rules_source.get_effective_rules()``.  A fresh project has an
empty collection, which is fine (engines fall back to canonical defaults),
but seeding makes every rule visible and editable in the admin panel with
correct metadata.

Behaviour
---------
* **Idempotent**: existing documents are never overwritten unless
  ``--force`` is passed.  A previously admin-edited ``value`` is preserved.
* Missing metadata fields (description/unit/legType/severity) are back-filled
  on existing docs without touching ``value`` or ``enabled``.
* Writes are batched; a summary is printed.

Usage
-----
    GOOGLE_APPLICATION_CREDENTIALS=svc.json python scripts/seed_legality_rules.py [--force] [--dry-run]

Run from the repository root or ``python_services/`` — the script fixes up
``sys.path`` itself.
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timezone

# Make python_services importable regardless of CWD.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PY_SERVICES = os.path.join(os.path.dirname(_HERE), "python_services")
for p in (_PY_SERVICES, os.path.dirname(_HERE)):
    if p not in sys.path:
        sys.path.insert(0, p)

from legality.rules_source import CANONICAL_DEFAULTS, RULE_METADATA, RULES_BASE_VERSION  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed legalityRules with canonical defaults (idempotent).")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite existing documents (resets admin edits to canonical defaults).")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be written without touching Firestore.")
    args = parser.parse_args()

    import firebase_admin
    from firebase_admin import credentials, firestore

    if not firebase_admin._apps:
        cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        cred = credentials.Certificate(cred_path) if cred_path else credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    col = db.collection("legalityRules")
    existing = {doc.id: (doc.to_dict() or {}) for doc in col.stream()}

    created, updated_meta, skipped, forced = [], [], [], []
    batch = db.batch()
    now = datetime.now(timezone.utc).isoformat()

    for rule_id, default_value in sorted(CANONICAL_DEFAULTS.items()):
        meta = RULE_METADATA.get(rule_id, {})
        full_doc = {
            "value": default_value,
            "enabled": True,
            "description": meta.get("description", rule_id),
            "unit": meta.get("unit", ""),
            "legType": meta.get("legType", "both"),
            "severity": meta.get("severity", "blocking"),
            "source": RULES_BASE_VERSION,
            "updatedAt": now,
            "updatedBy": "seed_legality_rules.py",
        }
        ref = col.document(rule_id)

        if rule_id not in existing:
            created.append(rule_id)
            if not args.dry_run:
                batch.set(ref, full_doc)
        elif args.force:
            forced.append(rule_id)
            if not args.dry_run:
                batch.set(ref, full_doc)
        else:
            # Back-fill only missing metadata; never touch value/enabled.
            current = existing[rule_id]
            patch = {k: v for k, v in full_doc.items()
                     if k in ("description", "unit", "legType", "severity", "source")
                     and not current.get(k)}
            if patch:
                updated_meta.append(rule_id)
                if not args.dry_run:
                    batch.set(ref, patch, merge=True)
            else:
                skipped.append(rule_id)

    if not args.dry_run and (created or updated_meta or forced):
        batch.commit()

    orphans = sorted(set(existing) - set(CANONICAL_DEFAULTS))
    prefix = "[dry-run] " if args.dry_run else ""
    print(f"{prefix}legalityRules seed complete — base version: {RULES_BASE_VERSION}")
    print(f"  created:            {len(created):>3}  {created}")
    print(f"  metadata backfill:  {len(updated_meta):>3}  {updated_meta}")
    print(f"  forced overwrite:   {len(forced):>3}  {forced}")
    print(f"  unchanged:          {len(skipped):>3}")
    if orphans:
        print(f"  WARNING — docs not in canonical set (ignored by engines): {orphans}")
    print("Note: engines cache rules for LEGALITY_RULES_TTL_SECONDS (default 300s); "
          "restart services or wait for TTL to see changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
