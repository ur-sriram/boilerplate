#!/usr/bin/env python3
"""Dynamic MCP profile switcher.

The repository ships MCP configuration in several vendor formats. This script
is the SINGLE implementation that keeps them all in sync; `mcp-profile.sh` and
`mcp-profile.ps1` are thin wrappers around it, so the POSIX and Windows paths
can never drift apart again (they previously did: the .sh version only
updated `opencode.json` and `.antigravity/*`, leaving six other configs
claiming the wrong profile).

Profiles:
    core        graphify only                      (<= 350 tokens)
    ui          graphify + ui-registry             (~750 tokens)
    compression graphify + headroom                (~650 tokens)
    all         graphify + ui-registry + headroom  (~1050 tokens)

Usage:
    python3 scripts/mcp-profile.py core
    python3 scripts/mcp-profile.py ui
    python3 scripts/mcp-profile.py compression
    python3 scripts/mcp-profile.py all
    python3 scripts/mcp-profile.py --status
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SERVERS = ["graphify", "ui-registry", "headroom"]

PROFILES = {
    "core": {"graphify": True, "ui-registry": False, "headroom": False},
    "ui": {"graphify": True, "ui-registry": True, "headroom": False},
    "compression": {"graphify": True, "ui-registry": False, "headroom": True},
    "all": {"graphify": True, "ui-registry": True, "headroom": True},
}


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def update_json(path: Path, enabled_for: dict[str, bool], key: str) -> str | None:
    """Set `key` (e.g. "enabled" / "disabled") per server in a JSON config.

    Handles three shapes:
      {"mcpServers": {"graphify": {...}}}        (Claude Code, Cursor, Kimi)
      {"mcp": {"graphify": {...}}}               (OpenCode, Qoder)
      {"mcpServers": {...}}                      (Antigravity)
    """
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return f"{rel(path)}: unreadable ({error})"

    changed = False
    for container_key in ("mcpServers", "mcp"):
        container = data.get(container_key)
        if not isinstance(container, dict):
            continue
        for server, state in enabled_for.items():
            entry = container.get(server)
            if not isinstance(entry, dict):
                continue
            if key == "disabled":
                entry["disabled"] = not state
            else:
                entry["enabled"] = state
            changed = True

    if not changed:
        return f"{rel(path)}: no MCP server entries found"

    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return f"[OK] Updated {rel(path)} ({key})"


def update_goose_yaml(path: Path, enabled_for: dict[str, bool]) -> str | None:
    """Toggle `enabled:` inside each `extensions:` block of the Goose YAML."""
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    original = text

    lines = text.splitlines()
    current_server = None
    for index, line in enumerate(lines):
        stripped = line.strip()
        match = re.match(r"^([A-Za-z0-9_-]+):\s*$", stripped)
        if match and match.group(1) in enabled_for and line.startswith("  "):
            current_server = match.group(1)
            continue
        if current_server and re.match(r"^enabled:\s*(true|false)\s*$", stripped):
            desired = "true" if enabled_for[current_server] else "false"
            indent = line[: len(line) - len(line.lstrip())]
            lines[index] = f"{indent}enabled: {desired}"
            current_server = None

    if lines == original.splitlines():
        return f"{rel(path)}: no extension entries found"

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return f"[OK] Updated {rel(path)} (extensions.enabled)"


def update_codex_toml(path: Path, enabled_for: dict[str, bool]) -> str | None:
    """Set `enabled = true/false` inside each [mcp_servers.<name>] block.

    The flag is INSERTED when the block does not declare one yet, so a server
    that was always-on (graphify) can actually be switched off.
    """
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Locate each [mcp_servers.<name>] block and its line range.
    blocks: list[tuple[str, int, int]] = []
    for index, line in enumerate(lines):
        header = re.match(r"^\[mcp_servers\.([A-Za-z0-9_-]+)\]\s*$", line.strip())
        if header:
            blocks.append([header.group(1), index, index + 1])  # type: ignore[arg-type]

    for block in blocks:
        name, start = block[0], block[1]
        end = len(lines)
        for index in range(start + 1, len(lines)):
            if lines[index].strip().startswith("["):
                end = index
                break
        block[2] = end  # type: ignore[index]

    changed = False
    # Rewrite from the bottom up so earlier line numbers stay valid.
    for name, start, end in reversed(blocks):
        desired = "true" if enabled_for.get(name, False) else "false"
        existing = None
        for index in range(start + 1, end):
            if re.match(r"^\s*enabled\s*=\s*(true|false)\s*$", lines[index]):
                existing = index
                break
        if existing is not None:
            indent = lines[existing][: len(lines[existing]) - len(lines[existing].lstrip())]
            lines[existing] = f"{indent}enabled = {desired}"
        else:
            insert_at = end
            while insert_at > start + 1 and not lines[insert_at - 1].strip():
                insert_at -= 1
            lines.insert(insert_at, f"enabled = {desired}")
        changed = True

    if not changed:
        return f"{rel(path)}: no [mcp_servers.*] blocks found"

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return f"[OK] Updated {rel(path)} (mcp_servers.enabled)"


def update_kimi_mcp(path: Path, enabled_for: dict[str, bool]) -> str | None:
    """Kimi Code CLI marks off-profile servers as `deferred`."""
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    container = data.get("mcpServers", {})
    for server, state in enabled_for.items():
        entry = container.get(server)
        if isinstance(entry, dict):
            entry["deferred"] = not state
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return f"[OK] Updated {rel(path)} (deferred)"


def _status_json(path: Path, key: str) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    container = data.get("mcpServers") or data.get("mcp") or {}
    states: dict[str, str] = {}
    for server in SERVERS:
        entry = container.get(server)
        if not isinstance(entry, dict):
            states[server] = "?"
            continue
        if key == "disabled":
            states[server] = "off" if entry.get("disabled") else "ON"
        elif key == "deferred":
            states[server] = "deferred" if entry.get("deferred") else "ON"
        else:
            states[server] = "ON" if entry.get("enabled") else "off"
    return states


def _status_yaml(path: Path) -> dict[str, str]:
    """Read Goose extension blocks (2-space indented `name:` keys)."""
    states: dict[str, str] = {server: "?" for server in SERVERS}
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", raw)
        if match:
            current = match.group(1)
            continue
        if current and re.match(r"^\s+enabled:\s*(true|false)\s*$", raw):
            states[current] = "ON" if "true" in raw else "off"
            current = None
    return states


def _status_toml(path: Path) -> dict[str, str]:
    """Read Codex [mcp_servers.<name>] blocks."""
    states: dict[str, str] = {server: "?" for server in SERVERS}
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        header = re.match(r"^\[mcp_servers\.([A-Za-z0-9_-]+)\]\s*$", raw.strip())
        if header:
            current = header.group(1)
            # No explicit flag means enabled by default.
            states[current] = "ON"
            continue
        if raw.strip().startswith("["):
            current = None
            continue
        if current and re.match(r"^\s*enabled\s*=\s*(true|false)\s*$", raw):
            states[current] = "ON" if "true" in raw else "off"
            current = None
    return states


def status() -> int:
    print(f"{'Config':<34}{'graphify':<12}{'ui-registry':<14}{'headroom':<12}")
    print("-" * 72)
    configs = [
        (".mcp.json", "json:disabled"),
        (".agents/mcp.json", "json:enabled"),
        (".cursor/mcp.json", "json:disabled"),
        ("opencode.json", "json:enabled"),
        (".antigravity/mcp_config.json", "json:disabled"),
        (".qoder/settings.json", "json:enabled"),
        (".kimi-code/mcp.json", "json:deferred"),
        (".goose/config.yaml", "yaml"),
        (".codex/config.toml", "toml"),
    ]
    for rel_path, kind in configs:
        path = REPO_ROOT / rel_path
        if not path.exists():
            print(f"{rel_path:<34}{'MISSING':<12}")
            continue
        if kind.startswith("json:"):
            states = _status_json(path, kind.split(":", 1)[1])
        elif kind == "yaml":
            states = _status_yaml(path)
        else:
            states = _status_toml(path)
        print(
            f"{rel_path:<34}{states.get('graphify','?'):<12}"
            f"{states.get('ui-registry','?'):<14}{states.get('headroom','?'):<12}"
        )
    print("-" * 72)
    return 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("--status", "status"):
        return status()

    profile = args[0]
    if profile not in PROFILES:
        print(f"Error: unknown profile '{profile}'. Valid: {', '.join(PROFILES)}", file=sys.stderr)
        return 1

    enabled_for = PROFILES[profile]
    print(f"Switching MCP profile to '{profile}' in {REPO_ROOT}")

    results = [
        update_json(REPO_ROOT / ".mcp.json", enabled_for, "disabled"),
        update_json(REPO_ROOT / ".agents/mcp.json", enabled_for, "enabled"),
        update_json(REPO_ROOT / ".cursor/mcp.json", enabled_for, "disabled"),
        update_json(REPO_ROOT / "opencode.json", enabled_for, "enabled"),
        update_json(REPO_ROOT / ".antigravity/mcp_config.json", enabled_for, "disabled"),
        update_json(REPO_ROOT / ".qoder/settings.json", enabled_for, "enabled"),
        update_kimi_mcp(REPO_ROOT / ".kimi-code/mcp.json", enabled_for),
        update_goose_yaml(REPO_ROOT / ".goose/config.yaml", enabled_for),
        update_codex_toml(REPO_ROOT / ".codex/config.toml", enabled_for),
    ]

    failures = []
    for result in results:
        if result is None:
            continue
        # Anything that is not an explicit [OK] means the adapter was NOT
        # updated — an unreadable file, or a file with no matching entries.
        # Treating those as success made a profile switch silently skip an
        # adapter while still printing "applied to all adapter configs".
        if not result.startswith("[OK]"):
            failures.append(result)
        else:
            print(result)

    if failures:
        for failure in failures:
            print(f"[FAIL] {failure}", file=sys.stderr)
        return 1

    print(f"[OK] MCP profile '{profile}' applied to all adapter configs.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # Normal when the output is piped into `head` and friends.
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(0)
