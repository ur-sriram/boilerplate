#!/usr/bin/env python3
"""Adapter parity verifier.

Checks that every AI-coding-agent adapter in this repository is wired to the
same canonical capabilities:

  * rules          -> references AGENTS.md (or the shared rule files)
  * MCP            -> the canonical server invocations (graphify / ui-registry / headroom)
  * hooks          -> protect-config / rtk-filter / session-start
  * slash commands -> the 8 canonical commands distributed from .agents/commands/
  * skills         -> a junction that RESOLVES into .agents/skills (or native access)

This exists because the parity claims in AGENTS.md and docs/agents/*.md were
never enforced: several adapters shipped with wrong MCP invocations, a hook
schema their runtime does not implement, or no slash commands at all.

Exit codes:
  0 = every hard requirement satisfied (soft gaps are reported, not fatal)
  1 = a hard requirement failed
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

CANONICAL_COMMANDS = [
    "build-fix",
    "plan",
    "refactor-clean",
    "review",
    "simplify",
    "tdd",
    "test",
    "verify",
]

CANONICAL_MCP = {
    "graphify": ["--from", "graphifyy", "graphify-mcp"],
    "ui-registry": ["-y", "ui-registry-mcp@0.7.1"],
    "headroom": ["--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"],
}

HOOK_MARKERS = {
    "protect-config": "protect-config",
    "rtk-filter": "rtk-filter",
    "session-start": "session-start",
}


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def adapter_specs() -> list[dict]:
    """Each adapter: name, config files, command dir, whether MCP is supported."""
    return [
        {
            "name": "Claude Code",
            "configs": [".claude/settings.json", "CLAUDE.md"],
            "command_dir": ".claude/commands",
            "command_suffix": ".md",
            "mcp": ".mcp.json",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "OpenCode",
            "configs": ["opencode.json"],
            "command_dir": ".opencode/commands",
            "command_suffix": ".toml",
            "mcp": "opencode.json",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "Cursor",
            "configs": [".cursor/rules/core.mdc"],
            "command_dir": ".cursor/commands",
            "command_suffix": ".md",
            "mcp": ".cursor/mcp.json",
            "mcp_required": True,
            "hooks": False,
        },
        {
            "name": "Codex CLI",
            "configs": [".codex/config.toml"],
            "command_dir": ".codex/prompts",
            "command_suffix": ".md",
            "mcp": ".codex/config.toml",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "Qoder",
            "configs": [".qoder/settings.json"],
            "command_dir": ".qoder/commands",
            "command_suffix": ".md",
            "mcp": ".qoder/settings.json",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "Kimi Code CLI",
            "configs": [".kimi/config.toml"],
            "command_dir": ".kimi/commands",
            "command_suffix": ".md",
            "mcp": ".kimi-code/mcp.json",
            "mcp_required": True,
            "hooks": False,
        },
        {
            "name": "Goose CLI",
            "configs": [".goose/config.yaml", ".goose/hooks.json"],
            "command_dir": ".goose/commands",
            "command_suffix": ".md",
            "mcp": ".goose/config.yaml",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "Antigravity",
            "configs": [".antigravity/settings.json", ".antigravity/hooks.json"],
            "command_dir": ".antigravity/commands",
            "command_suffix": ".md",
            "mcp": ".antigravity/mcp_config.json",
            "mcp_required": True,
            "hooks": True,
        },
        {
            "name": "JetBrains Junie",
            "configs": [".junie/playbook.md"],
            "command_dir": ".junie/commands",
            "command_suffix": ".md",
            "mcp": None,
            "mcp_required": False,
            "hooks": False,
        },
        {
            "name": "Cline / Roo Code",
            "configs": [".clinerules"],
            "command_dir": ".cline/commands",
            "command_suffix": ".md",
            "mcp": None,
            "mcp_required": False,
            "hooks": False,
        },
        {
            "name": "Windsurf",
            "configs": [".windsurfrules"],
            "command_dir": ".windsurf/commands",
            "command_suffix": ".md",
            "mcp": None,
            "mcp_required": False,
            "hooks": False,
        },
        {
            "name": "GitHub Copilot",
            "configs": [".github/copilot-instructions.md"],
            "command_dir": ".github/prompts",
            "command_suffix": ".prompt.md",
            "mcp": ".mcp.json",
            "mcp_required": True,
            "hooks": False,
        },
    ]


def check_mcp(adapter: dict) -> list[str]:
    """Hard errors: a configured MCP server that drifts from the canonical one."""
    errors: list[str] = []
    mcp_path = adapter.get("mcp")
    if not mcp_path:
        return errors
    full = REPO_ROOT / mcp_path
    if not full.exists():
        errors.append(f"{adapter['name']}: MCP config '{mcp_path}' is missing")
        return errors

    text = read(full)
    for server, expected in CANONICAL_MCP.items():
        if server not in text:
            errors.append(f"{adapter['name']}: MCP server '{server}' missing from {mcp_path}")
            continue
        for token in expected:
            if token not in text:
                errors.append(
                    f"{adapter['name']}: MCP server '{server}' in {mcp_path} is missing "
                    f"the canonical argument '{token}'"
                )
    return errors


def check_hooks(adapter: dict) -> list[str]:
    """Verify hook wiring.

    OpenCode implements hooks as plugins rather than a hooks config, so its
    plugin sources are inspected instead.

    A hook config that only invokes PowerShell is a failure: the repository
    targets Linux/macOS too, and a PowerShell-only hook silently no-ops there.
    A config that ALSO declares a POSIX variant (Antigravity's
    `posix_command`) is accepted.
    """
    errors: list[str] = []
    if not adapter.get("hooks"):
        return errors

    if adapter["name"] == "OpenCode":
        plugin_dir = REPO_ROOT / ".opencode" / "plugins"
        # Include the file names: OpenCode's hook equivalents are identified
        # by plugin file name (config-protection.js, rtk-interceptor.js, ...).
        blob = "\n".join(
            [p.name + "\n" + read(p) for p in sorted(plugin_dir.glob("*.js"))]
        )
        # OpenCode expresses the same three hooks as plugins.
        opencode_markers = {
            "protect-config": "config-protection",
            "rtk-filter": "rtk-interceptor",
            "session-start": "session-start",
        }
        for hook, marker in opencode_markers.items():
            if marker not in blob:
                errors.append(f"{adapter['name']}: hook '{hook}' is not wired")
        return errors

    blob = "\n".join(read(REPO_ROOT / cfg) for cfg in adapter["configs"])
    for hook, marker in HOOK_MARKERS.items():
        if marker not in blob:
            errors.append(f"{adapter['name']}: hook '{hook}' is not wired")

    # Ignore comment lines when looking for a PowerShell-only invocation.
    code_lines = [
        line for line in blob.splitlines() if not line.lstrip().startswith(("#", "//"))
    ]
    code_blob = "\n".join(code_lines)
    has_posix_variant = "posix_command" in code_blob or "run-hook.mjs" in code_blob
    if "powershell" in code_blob.lower() and not has_posix_variant:
        errors.append(
            f"{adapter['name']}: hooks still invoke PowerShell only — POSIX hosts get no guardrails"
        )
    return errors


def check_commands(adapter: dict) -> list[str]:
    errors: list[str] = []
    directory = REPO_ROOT / adapter["command_dir"]
    if not directory.exists():
        errors.append(f"{adapter['name']}: command directory '{adapter['command_dir']}' is missing")
        return errors
    suffix = adapter["command_suffix"]
    present = set()
    for path in directory.glob(f"*{suffix}"):
        name = path.name[: -len(suffix)] if suffix and path.name.endswith(suffix) else path.stem
        present.add(name)
    missing = [c for c in CANONICAL_COMMANDS if c not in present]
    if missing:
        errors.append(f"{adapter['name']}: missing slash command(s) {missing}")
    return errors


def check_rules(adapter: dict) -> list[str]:
    errors: list[str] = []
    blob = "\n".join(read(REPO_ROOT / cfg) for cfg in adapter["configs"])
    if "AGENTS.md" not in blob:
        errors.append(f"{adapter['name']}: does not reference AGENTS.md")
    return errors


def check_skills() -> list[str]:
    errors: list[str] = []
    canonical = (REPO_ROOT / ".agents" / "skills").resolve()
    for rel in [
        ".claude/skills",
        ".cursor/skills",
        ".windsurf/skills",
        ".cline/skills",
        ".codex/skills",
        ".qoder/skills",
    ]:
        link = REPO_ROOT / rel
        if not link.is_symlink():
            errors.append(f"skills junction '{rel}' is not a symlink")
            continue
        try:
            resolved = link.resolve()
        except OSError:
            errors.append(f"skills junction '{rel}' does not resolve")
            continue
        if resolved != canonical:
            errors.append(f"skills junction '{rel}' points at '{resolved}', expected '{canonical}'")
    return errors


def main() -> int:
    errors: list[str] = []
    rows: list[tuple[str, str, str, str, str]] = []

    for adapter in adapter_specs():
        rule_err = check_rules(adapter)
        mcp_err = check_mcp(adapter)
        hook_err = check_hooks(adapter)
        cmd_err = check_commands(adapter)

        errors.extend(rule_err + mcp_err + hook_err + cmd_err)
        rows.append(
            (
                adapter["name"],
                "OK" if not rule_err else "MISSING",
                "OK" if not mcp_err else ("N/A" if not adapter.get("mcp") else "DRIFT"),
                "OK" if not hook_err else ("N/A" if not adapter.get("hooks") else "MISSING"),
                "OK" if not cmd_err else "MISSING",
            )
        )

    skill_err = check_skills()
    errors.extend(skill_err)

    print("Adapter parity matrix")
    print("-" * 78)
    print(f"{'Adapter':<20}{'Rules':<12}{'MCP':<12}{'Hooks':<12}{'Commands':<12}")
    print("-" * 78)
    for name, rules, mcp, hooks, cmds in rows:
        print(f"{name:<20}{rules:<12}{mcp:<12}{hooks:<12}{cmds:<12}")
    print("-" * 78)
    print(f"Skill junctions: {'OK' if not skill_err else 'FAIL'}")
    print()

    if errors:
        print(f"[FAIL] {len(errors)} adapter parity problem(s):")
        for err in errors:
            print(f"  - {err}")
        return 1

    print("[PASS] All adapters meet the documented parity contract.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
