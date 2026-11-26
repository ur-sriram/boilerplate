#!/usr/bin/env python3
"""Verify the vendored Spec Kit files against their recorded checksums.

`.specify/integrations/speckit.manifest.json` records the SHA-256 of every
vendored Spec Kit file. Nothing in the repository verified that manifest, so
local edits to the vendored engine (or a partial/broken checkout) went
unnoticed.

This script checks that:
  * every file listed in the manifest exists,
  * every file matches its recorded SHA-256,
  * every file present under .specify/ (excluding machine-local state) is
    listed in the manifest.

Exit codes:
  0 = manifest and files agree
  1 = missing file, checksum mismatch, or untracked file
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SPECIFY_DIR = REPO_ROOT / ".specify"
MANIFEST_PATH = SPECIFY_DIR / "integrations" / "speckit.manifest.json"

# Machine-local / generated paths that are intentionally not tracked.
IGNORED_PREFIXES = (
    ".specify/feature.json",
    ".specify/integrations/packages",
    ".specify/integrations/packages.json",
    ".specify/presets",
    ".specify/extensions",
    ".specify/templates/overrides",
    ".specify/scripts/powershell/__pycache__",
    ".specify/scripts/bash/__pycache__",
)

# The Spec Kit CLI installs into scripts/ and templates/. Those trees must be
# fully tracked. The remaining .specify/ paths (integration.json, workflows/,
# memory/) are repository-level additions to the upstream engine and are
# checked by the repository's own test-bootstrap suite instead.
CLI_MANAGED_PREFIXES = (
    ".specify/scripts/",
    ".specify/templates/",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    if not MANIFEST_PATH.exists():
        print(f"[FAIL] Manifest not found: {MANIFEST_PATH}", file=sys.stderr)
        return 1

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    tracked: dict[str, str] = manifest.get("files", {})

    problems: list[str] = []
    checked = 0

    for rel_path, expected in sorted(tracked.items()):
        full = REPO_ROOT / rel_path
        if not full.exists():
            problems.append(f"missing vendored file: {rel_path}")
            continue
        actual = sha256(full)
        checked += 1
        if actual != expected:
            problems.append(
                f"checksum mismatch: {rel_path}\n"
                f"    expected {expected}\n"
                f"    actual   {actual}"
            )

    # Every vendored file must be tracked, so a locally dropped script cannot
    # masquerade as part of the upstream engine.
    for full in sorted(SPECIFY_DIR.rglob("*")):
        if not full.is_file():
            continue
        rel = full.relative_to(REPO_ROOT).as_posix()
        if rel in tracked:
            continue
        if any(rel.startswith(prefix) for prefix in IGNORED_PREFIXES):
            continue
        if not any(rel.startswith(prefix) for prefix in CLI_MANAGED_PREFIXES):
            continue
        problems.append(f"untracked file inside a CLI-managed tree: {rel}")

    if problems:
        print(f"[FAIL] Spec Kit integrity check found {len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print(f"[PASS] Spec Kit manifest verified: {checked} vendored file(s) match their checksums.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
