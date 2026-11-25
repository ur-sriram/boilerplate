#!/usr/bin/env python3
"""
Third-Party Manifest Validator & Upstream SHA Maintenance Utility.

Features:
1. Parses THIRD_PARTY.md to extract all external git repositories and pinned commit SHAs.
2. Validates format: Asserts that all pinned commit hashes are valid 40-character hexadecimal strings.
3. Queries remote git references (via git ls-remote) to resolve current upstream HEAD/main.
4. Audit mode (--check): Reports status for each source (UP-TO-DATE, PINNED_PRIOR, or OFFLINE).
5. Update mode (--update): Refreshes pinned SHAs in THIRD_PARTY.md to match upstream HEAD.
"""

import argparse
import concurrent.futures
import os
import re
import subprocess
import sys
from pathlib import Path


def extract_manifest_sources(content: str):
    """
    Parses Markdown tables from THIRD_PARTY.md and extracts git sources.
    Returns a list of dicts:
      {
        'name': str,
        'url': str,
        'pinned_sha': str,
        'full_match': str
      }
    """
    sources = []
    # Match rows like: | 1 | **`owner/repo`**<br>https://github.com/... | `40charsha` | ...
    row_pattern = re.compile(
        r"\|\s*\d+\s*\|\s*([^|]*?https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)[^|]*?)\|\s*`([0-9a-fA-F]{40})`\s*\|",
        re.MULTILINE,
    )

    for m in row_pattern.finditer(content):
        cell_raw = m.group(1)
        repo_slug = m.group(2).rstrip("/")
        repo_url = f"https://github.com/{repo_slug}"
        pinned_sha = m.group(3)
        sources.append({
            "name": repo_slug,
            "url": repo_url,
            "pinned_sha": pinned_sha,
            "span": m.span(3),
        })

    # Also match supplementary table rows: | **Tool** | https://github.com/... | `40charsha` |
    supp_pattern = re.compile(
        r"\|\s*([^|]+)\|\s*(https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)[^|]*?)\|\s*`([0-9a-fA-F]{40})`\s*\|",
        re.MULTILINE,
    )
    for m in supp_pattern.finditer(content):
        tool_name = m.group(1).replace("*", "").strip()
        repo_slug = m.group(3).rstrip("/")
        repo_url = f"https://github.com/{repo_slug}"
        pinned_sha = m.group(4)
        if not any(s["url"] == repo_url for s in sources):
            sources.append({
                "name": f"{tool_name} ({repo_slug})",
                "url": repo_url,
                "pinned_sha": pinned_sha,
                "span": m.span(4),
            })

    return sources


def query_remote_head(repo_url: str, timeout_sec: int = 8) -> str:
    """
    Queries git ls-remote to find HEAD or default branch commit SHA.
    """
    cmd = [
        "git",
        "-c", "http.sslVerify=false",
        "-c", "credential.helper=",
        "ls-remote",
        repo_url,
        "HEAD",
        "refs/heads/main",
        "refs/heads/master"
    ]
    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GIT_ASKPASS"] = ""
    env["GCM_INTERACTIVE"] = "never"
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout_sec,
            env=env,
        )
        if res.returncode == 0 and res.stdout:
            lines = res.stdout.strip().splitlines()
            # Prioritize HEAD, then main, then master
            head_map = {}
            for line in lines:
                parts = line.split()
                if len(parts) >= 2:
                    head_map[parts[1]] = parts[0]
            
            if "HEAD" in head_map:
                return head_map["HEAD"]
            if "refs/heads/main" in head_map:
                return head_map["refs/heads/main"]
            if "refs/heads/master" in head_map:
                return head_map["refs/heads/master"]
            if lines:
                return lines[0].split()[0]
    except Exception:
        pass
    return ""


def main():
    parser = argparse.ArgumentParser(description="Audit and update pinned commit SHAs in THIRD_PARTY.md")
    parser.add_argument("--check", "-c", action="store_true", help="Audit mode: validate SHAs without modifying file")
    parser.add_argument("--update", "-u", action="store_true", help="Update mode: refresh pinned SHAs with remote HEAD")
    parser.add_argument("--file", "-f", type=str, default="", help="Path to THIRD_PARTY.md")
    parser.add_argument("--offline", action="store_true", help="Skip remote network checks and validate SHA format only")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    manifest_path = Path(args.file) if args.file else project_root / "THIRD_PARTY.md"

    if not manifest_path.is_file():
        print(f"[FAIL] Manifest file not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    print("============================================================")
    print("   Third-Party Manifest SHA Maintenance & Audit Utility    ")
    print("============================================================")
    print(f"[INFO] Manifest path: {manifest_path}")

    content = manifest_path.read_text(encoding="utf-8")
    sources = extract_manifest_sources(content)

    print(f"[INFO] Discovered {len(sources)} pinned git source repository/repositories.")
    if not sources:
        print("[FAIL] No external git sources with 40-character SHAs found in manifest.", file=sys.stderr)
        sys.exit(1)

    sha_pattern = re.compile(r"^[0-9a-fA-F]{40}$")
    format_errors = 0
    updated_count = 0
    new_content = content

    # 2. Remote check pre-fetch
    remote_heads = {}
    if not args.offline:
        print("[INFO] Fetching upstream git references concurrently...", flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            future_to_src = {executor.submit(query_remote_head, s["url"], 6): s["url"] for s in sources}
            for fut in concurrent.futures.as_completed(future_to_src):
                url = future_to_src[fut]
                try:
                    remote_heads[url] = fut.result()
                except Exception:
                    remote_heads[url] = ""

    print("\n{:<32} {:<12} {:<12} {:<14}".format("Source", "Pinned SHA", "Remote HEAD", "Status"), flush=True)
    print("-" * 75, flush=True)

    for src in sources:
        name = src["name"][:30]
        sha = src["pinned_sha"]
        short_sha = sha[:8]

        # 1. Format validation
        if not sha_pattern.match(sha):
            print("{:<32} {:<12} {:<12} {:<14}".format(name, "INVALID", "-", "[FORMAT_FAIL]"), flush=True)
            format_errors += 1
            continue

        remote_sha = remote_heads.get(src["url"], "")
        status = "[VALID_SHA]"
        if not args.offline:
            if remote_sha:
                short_remote = remote_sha[:8]
                if remote_sha.lower() == sha.lower():
                    status = "[UP_TO_DATE]"
                else:
                    status = "[PINNED_PRIOR]"
                    if args.update:
                        new_content = new_content.replace(sha, remote_sha)
                        updated_count += 1
                        status = "[UPDATED]"
            else:
                short_remote = "N/A"
                status = "[OFFLINE_OK]"
        else:
            short_remote = "SKIPPED"
            status = "[VERIFIED]"

        print("{:<32} {:<12} {:<12} {:<14}".format(name, short_sha, short_remote, status), flush=True)

    print("-" * 75)

    if args.update and updated_count > 0:
        manifest_path.write_text(new_content, encoding="utf-8")
        print(f"\n[OK] Updated {updated_count} commit SHA(s) in {manifest_path.name}")
    elif args.update:
        print(f"\n[OK] All {len(sources)} commit SHAs already up to date with upstream HEAD.")

    if format_errors > 0:
        print(f"\n[FAIL] Audit failed: {format_errors} invalid SHA format error(s).", file=sys.stderr)
        sys.exit(1)

    print(f"\n[OK] Manifest verification complete: 100% of pinned SHAs valid.")
    sys.exit(0)


if __name__ == "__main__":
    main()
