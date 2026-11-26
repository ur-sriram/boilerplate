#!/usr/bin/env python3
"""
Publish the live demo site to the ``gh-pages`` branch.

The site lives in ``docs/site/`` and is served by GitHub Pages from the
``gh-pages`` branch of the same repository. GitHub Pages needs a
``.nojekyll`` file to serve the files as-is instead of running them through
Jekyll.

Usage:
    GITHUB_TOKEN=<pat> python3 scripts/deploy-demo-pages.py
    GITHUB_TOKEN=<pat> python3 scripts/deploy-demo-pages.py --dry-run

The script talks to the GitHub REST API only, so it never touches the local
git working tree: it creates a blob for every file, builds a tree on top of
the current ``gh-pages`` head, commits it and moves the branch ref.

The token needs the ``repo`` scope. The ``gh-pages`` branch must be published
from Settings -> Pages, with the source set to the ``gh-pages`` branch and
the path ``/ (root)``.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "docs" / "site"
BRANCH = "gh-pages"
API = "https://api.github.com/repos/ur-sriram/boilerplate"
TOKEN = os.environ.get("GITHUB_TOKEN", "")


def api(path, method="GET", data=None, quiet=False):
    """Call the GitHub REST API and return the decoded response."""
    if not TOKEN:
        raise SystemExit("GITHUB_TOKEN is not set")
    request = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "multi-agent-boilerplate",
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        if quiet:
            return None
        sys.stderr.write(error.read().decode(errors="replace") + "\n")
        raise SystemExit(f"{method} {path} failed with HTTP {error.code}")


def collect_files() -> list[tuple[str, bytes]]:
    """Return every publishable file as (path, bytes)."""
    files = [(".nojekyll", b"")]
    for item in sorted(SITE.rglob("*")):
        if not item.is_file():
            continue
        relative = item.relative_to(SITE).as_posix()
        files.append((relative, item.read_bytes()))
    return files


def main() -> int:
    if not SITE.is_dir():
        raise SystemExit(f"site source not found: {SITE}")
    if not (SITE / "index.html").is_file():
        raise SystemExit(f"site entry point not found: {SITE / 'index.html'}")

    files = collect_files()
    print(f"[INFO] Publishing {len(files)} file(s) to the '{BRANCH}' branch:")
    for name, _ in files:
        print(f"  - {name}")

    if "--dry-run" in sys.argv:
        print("[INFO] Dry run — nothing was published.")
        return 0

    entries = []
    for name, content in files:
        blob = api(
            "/git/blobs",
            "POST",
            {"content": base64.b64encode(content).decode(), "encoding": "base64"},
        )
        entries.append(
            {
                "path": name,
                "mode": "100644",
                "type": "blob",
                "sha": blob["sha"],
            }
        )

    head = api(f"/git/ref/heads/{BRANCH}", quiet=True)
    if head is None:
        # First publish: build the tree from scratch, then create the branch.
        tree = api("/git/trees", "POST", {"tree": entries})
        commit = api(
            "/git/commits",
            "POST",
            {"message": "docs: publish the live demo site", "tree": tree["sha"]},
        )
        api(
            "/git/refs",
            "POST",
            {"ref": f"refs/heads/{BRANCH}", "sha": commit["sha"]},
        )
        print(f"[PASS] Created the '{BRANCH}' branch at commit {commit['sha'][:7]}.")
    else:
        parents = [head["object"]["sha"]]
        base_tree = api(f"/git/commits/{parents[0]}")["tree"]["sha"]
        tree = api("/git/trees", "POST", {"base_tree": base_tree, "tree": entries})
        commit = api(
            "/git/commits",
            "POST",
            {
                "message": "docs: publish the live demo site",
                "tree": tree["sha"],
                "parents": parents,
            },
        )
        api(
            f"/git/refs/heads/{BRANCH}",
            "PATCH",
            {"sha": commit["sha"], "force": True},
        )
        print(f"[PASS] Published commit {commit['sha'][:7]} to the '{BRANCH}' branch.")
    print("       If Pages is not enabled yet: Settings -> Pages -> Source:")
    print(f"       Deploy from a branch -> '{BRANCH}' branch -> '/ (root)'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
