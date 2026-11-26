#!/usr/bin/env python3
"""
Publish the live demo site to the ``gh-pages`` branch.

The site lives in ``docs/site/`` and is served by GitHub Pages from the
``gh-pages`` branch of the same repository. GitHub Pages needs a
``.nojekyll`` file to serve the files as-is instead of running them through
Jekyll.

Usage:
    python3 scripts/deploy-demo-pages.py            # publish the current site
    python3 scripts/deploy-demo-pages.py --dry-run  # show what would be pushed

The script only touches the ``gh-pages`` branch; ``main`` is never modified.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "docs" / "site"
BRANCH = "gh-pages"


def run(args, cwd=None, check=True):
    """Run a git command and return its output."""
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"git {' '.join(args)} failed with code {result.returncode}")
    return result.stdout.strip()


def build_site(target: Path) -> None:
    """Copy the site into *target* and add the files Pages needs."""
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(SITE, target)
    (target / ".nojekyll").write_text("", encoding="utf-8")


def main() -> int:
    dry_run = "--dry-run" in sys.argv

    if not SITE.is_dir():
        raise SystemExit(f"site source not found: {SITE}")
    if not (SITE / "index.html").is_file():
        raise SystemExit(f"site entry point not found: {SITE / 'index.html'}")

    workdir = Path(tempfile.mkdtemp(prefix="demo-pages-"))
    payload = workdir / "site"
    build_site(payload)

    files = sorted(p.relative_to(payload).as_posix() for p in payload.rglob("*") if p.is_file())
    print(f"[INFO] Publishing {len(files)} file(s) to the '{BRANCH}' branch:")
    for name in files:
        print(f"  - {name}")

    if dry_run:
        print("[INFO] Dry run — nothing was pushed.")
        shutil.rmtree(workdir, ignore_errors=True)
        return 0

    if run(["rev-parse", "--verify", BRANCH], check=False):
        print(f"[INFO] Branch '{BRANCH}' exists — rebuilding it from scratch.")
        run(["checkout", "--orphan", BRANCH])
        run(["rm", "-rf", "."])
    else:
        run(["checkout", "--orphan", BRANCH])

    for name in files:
        source = payload / name
        target = Path(name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    run(["add", "--all"])
    run(["commit", "-m", "docs: publish the live demo site"])
    run(["push", "--force", "origin", f"{BRANCH}:{BRANCH}"])

    print(f"[PASS] Published to the '{BRANCH}' branch.")
    print("       If Pages is not enabled yet, turn it on in Settings → Pages.")
    shutil.rmtree(workdir, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
