#!/usr/bin/env python3
"""Canonical MCP contracts and per-vendor config parsing.

Every AI-coding-agent adapter in this repository has to launch the SAME MCP
servers, but each vendor spells the config differently - and each spelling
has its own schema. This module owns that knowledge so both the verifier
(scripts/verify-adapters.py) and the smoke test
(scripts/verify-mcp-servers.py) agree on what "correct" means.

The canonical invocation of every server, as a full argv vector:

    graphify     uvx --from graphifyy[mcp] graphify-mcp
    ui-registry  npx -y ui-registry-mcp@0.7.1
    headroom     uvx --from headroom-ai[mcp] headroom mcp serve

`graphifyy` is installed with its `mcp` extra on purpose. The bare package
does not depend on the MCP SDK, so `uvx --from graphifyy graphify-mcp` dies
with "ModuleNotFoundError: No module named 'mcp'" and the server never
starts - it is configured in every adapter but was dead code everywhere.
"""

from __future__ import annotations

import json
import re
import tomllib
from pathlib import Path

CANONICAL_MCP = {
    "graphify": ["uvx", "--from", "graphifyy[mcp]", "graphify-mcp"],
    "ui-registry": ["npx", "-y", "ui-registry-mcp@0.7.1"],
    "headroom": ["uvx", "--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"],
}

# Every MCP server must keep its package caches inside the project, so that
# importing this boilerplate never writes to the user's home directory.
REQUIRED_CACHE_ENV = {
    "UV_CACHE_DIR",
    "UV_DATA_DIR",
    "UV_TOOL_DIR",
    "XDG_CACHE_HOME",
    "XDG_DATA_HOME",
    "npm_config_cache",
}

# Per-vendor MCP config schemas.
#
#   claude   JSON   { "command": "<exe>", "args": [...], "env": {...} }
#   opencode JSON   { "type": "local", "command": ["<exe>", ...], "environment": {...} }
#   goose    YAML   extensions.<name>.{cmd, args, envs}
#   codex    TOML   [mcp_servers.<name>] { command = "<exe>", args = [...], env = {...} }
#
# A config written in the WRONG shape for its runtime is silently discarded
# by that runtime rather than reported as an error. OpenCode behaved exactly
# that way: its `command`/`args`/`env` entries were dropped, OpenCode logged
# "Ignoring MCP config entry without type", and all three servers silently
# never started.
MCP_SCHEMAS = {
    "claude": {"format": "json", "command_style": "split", "env_key": "env"},
    "opencode": {"format": "json", "command_style": "array", "env_key": "environment"},
    "goose": {"format": "goose", "command_style": "split", "env_key": "envs"},
    "codex": {"format": "toml", "command_style": "split", "env_key": "env"},
}


def parse_goose_extensions(text: str) -> dict[str, dict]:
    """Parse the `extensions:` block of .goose/config.yaml.

    PyYAML is not guaranteed to be present in every environment this
    repository is used from, and the Goose file uses a small, fixed subset of
    YAML, so that subset is parsed directly instead of adding a dependency.
    """
    servers: dict[str, dict] = {}
    current: dict | None = None
    section: str | None = None
    in_extensions = False

    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        stripped = raw.strip()

        if indent == 0:
            in_extensions = stripped.startswith("extensions:")
            current = None
            section = None
            continue
        if not in_extensions:
            continue

        if indent == 2 and stripped.endswith(":"):
            current = {"cmd": None, "args": [], "envs": {}}
            servers[stripped[:-1]] = current
            section = None
            continue
        if current is None:
            continue

        if indent == 4:
            key, _, value = stripped.partition(":")
            value = value.strip().strip('"').strip("'")
            if key == "cmd":
                current["cmd"] = value
                section = None
            elif key == "args":
                section = "args"
            elif key == "envs":
                section = "envs"
            else:
                section = None
            continue

        if section == "args" and stripped.startswith("-"):
            current["args"].append(stripped[1:].strip().strip('"').strip("'"))
            continue
        if section == "envs":
            key, _, value = stripped.partition(":")
            current["envs"][key.strip()] = value.strip().strip('"').strip("'")

    return servers


def extract_mcp_entries(path: Path, schema_name: str) -> tuple[dict[str, dict], list[str]]:
    """Read an MCP config and return ({server: {argv, env}}, schema problems).

    `argv` is the normalised command vector, so an OpenCode-style array and a
    Claude-style `command` + `args` pair compare equal once parsed. That
    normalisation is what makes the parity check meaningful across vendors -
    but the SHAPE is still validated, because a wrongly shaped entry is
    exactly what a runtime silently drops.
    """
    schema = MCP_SCHEMAS[schema_name]
    text = path.read_text(encoding="utf-8", errors="replace")
    errors: list[str] = []

    if schema["format"] == "json":
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            return {}, [f"is not valid JSON ({exc})"]
        container = data.get("mcpServers") or data.get("mcp") or {}
    elif schema["format"] == "toml":
        try:
            data = tomllib.loads(text)
        except tomllib.TOMLDecodeError as exc:
            return {}, [f"is not valid TOML ({exc})"]
        container = data.get("mcp_servers", {})
    else:
        container = parse_goose_extensions(text)

    entries: dict[str, dict] = {}
    for name, entry in container.items():
        if not isinstance(entry, dict):
            errors.append(f"server '{name}' is not an object")
            continue

        if schema["format"] == "goose":
            argv = ([entry["cmd"]] if entry.get("cmd") else []) + list(entry.get("args", []))
            env = entry.get(schema["env_key"], {}) or {}
        elif schema["command_style"] == "array":
            command = entry.get("command")
            if isinstance(command, str):
                errors.append(
                    f"server '{name}' sets 'command' to a string; the {schema_name} schema "
                    f"requires 'command' to be an array of strings"
                )
                continue
            if not isinstance(command, list):
                errors.append(f"server '{name}' has no 'command' array")
                continue
            if entry.get("type") != "local":
                errors.append(f"server '{name}' must declare 'type': 'local'")
            argv = [str(part) for part in command]
            env = entry.get(schema["env_key"], {}) or {}
        else:
            command = entry.get("command")
            if not isinstance(command, str):
                errors.append(f"server '{name}' has no 'command' string")
                continue
            argv = [command] + [str(part) for part in entry.get("args", [])]
            env = entry.get(schema["env_key"], {}) or {}

        entries[name] = {"argv": argv, "env": env}

    return entries, errors


def find_server(path: Path, schema_name: str, server: str) -> tuple[dict | None, list[str]]:
    """Return (entry, problems) for one server in one config."""
    entries, errors = extract_mcp_entries(path, schema_name)
    return entries.get(server), errors
