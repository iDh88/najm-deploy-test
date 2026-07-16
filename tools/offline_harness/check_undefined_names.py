#!/usr/bin/env python3
"""Undefined-name checker (ruff F821 approximation) using stdlib `symtable`.

Purpose: this repo's CI enforces `ruff check --select E9,F63,F7,F82` as a
BLOCKING step. In network-restricted environments where ruff cannot be
installed, this script provides a best-effort equivalent for the F821 class
(undefined names) so the tree can be pre-verified before pushing.

Heuristics (kept deliberately conservative to avoid false positives):
  * A name referenced in any scope that is not local, free, parameter,
    imported, or defined at module level, and is not a builtin, is reported.
  * `__all__`-only names, star-imports, and dynamic globals() writes are not
    modelled — files using them (none in this repo at time of writing) may
    need manual review.

Exit code 0 = clean, 1 = findings.
"""
from __future__ import annotations
import builtins
import symtable
import sys
from pathlib import Path

BUILTINS = set(dir(builtins)) | {
    "__file__", "__name__", "__doc__", "__package__", "__spec__",
    "__loader__", "__builtins__", "__debug__", "__annotations__",
    "__dict__", "__class__", "WindowsError",
}


def module_level_names(table: symtable.SymbolTable) -> set[str]:
    names = set()
    for sym in table.get_symbols():
        if sym.is_assigned() or sym.is_imported():
            names.add(sym.get_name())
    for child in table.get_children():
        names.add(child.get_name())
    return names


def walk(table: symtable.SymbolTable, mod_names: set[str],
         findings: list[tuple[str, str]], path: str) -> None:
    for sym in table.get_symbols():
        name = sym.get_name()
        if not sym.is_referenced():
            continue
        if (sym.is_local() or sym.is_parameter() or sym.is_imported()
                or sym.is_free()):
            continue
        # falls through to global resolution
        if name in mod_names or name in BUILTINS:
            continue
        # class-scope implicit names
        if name in ("__qualname__", "__module__", "super", "self", "cls"):
            continue
        findings.append((path, f"{table.get_name()}: undefined name '{name}'"))
    for child in table.get_children():
        walk(child, mod_names, findings, path)


def check_file(path: Path) -> list[tuple[str, str]]:
    src = path.read_text(encoding="utf-8")
    if "import *" in src:
        return [(str(path), "uses star-import — manual review required")]
    try:
        table = symtable.symtable(src, str(path), "exec")
    except SyntaxError as e:
        return [(str(path), f"SyntaxError: {e}")]
    findings: list[tuple[str, str]] = []
    walk(table, module_level_names(table), findings, str(path))
    return findings


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(".")
    files = [p for p in root.rglob("*.py") if "__pycache__" not in p.parts]
    all_findings: list[tuple[str, str]] = []
    for f in sorted(files):
        all_findings.extend(check_file(f))
    for path, msg in all_findings:
        print(f"{path}: {msg}")
    print(f"\nchecked {len(files)} files — "
          f"{len(all_findings)} finding(s)")
    return 1 if all_findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
