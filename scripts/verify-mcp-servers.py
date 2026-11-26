#!/usr/bin/env python3
"""MCP server smoke test.

Every MCP server this boilerplate configures is launched for real, completes
the MCP handshake, and is asked for its tool list. A server that cannot start
is a dead entry in every adapter config - and that is exactly what happened:
`uvx --from graphifyy graphify-mcp` was configured in all nine adapters but
died with "ModuleNotFoundError: No module named 'mcp'", so the "core" MCP
profile had no working server at all.

This script is the proof that the MCP CodeMode workflow is workable rather
than merely documented.

Usage:
    python3 scripts/verify-mcp-servers.py                 # every canonical server
    python3 scripts/verify-mcp-servers.py graphify        # one server
    python3 scripts/verify-mcp-servers.py --timeout 300   # longer startup budget
    python3 scripts/verify-mcp-servers.py --list          # show what would run

Exit codes:
    0 = every requested server started and exposed at least one tool
    1 = a server failed to start, failed the handshake, or exposed no tools
    2 = bad arguments
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from adapter_mcp import CANONICAL_MCP, REQUIRED_CACHE_ENV  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TIMEOUT = 240

# The environment every configured server is launched with: the project-local
# cache paths, so a smoke test never writes into the user's home directory.
PROJECT_ENV = {
    "UV_CACHE_DIR": ".cache/uv",
    "UV_DATA_DIR": ".cache/uv-data",
    "UV_TOOL_DIR": ".cache/uv-tools",
    "XDG_CACHE_HOME": ".cache",
    "XDG_DATA_HOME": ".cache/xdg-data",
    "npm_config_cache": ".cache/npm",
}


class McpClient:
    """A minimal MCP stdio client: handshake, then tools/list."""

    def __init__(self, argv: list[str], timeout: int) -> None:
        self.argv = argv
        self.timeout = timeout
        self.process: subprocess.Popen | None = None
        self.lines: list[str] = []
        self.stderr: list[str] = []

    def start(self) -> None:
        env = dict(os.environ)
        env.update(PROJECT_ENV)

        self.process = subprocess.Popen(
            self.argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            cwd=str(REPO_ROOT),
            bufsize=1,
        )

        threading.Thread(target=self._pump_stdout, daemon=True).start()
        threading.Thread(target=self._pump_stderr, daemon=True).start()

    def _pump_stdout(self) -> None:
        assert self.process and self.process.stdout
        for line in self.process.stdout:
            self.lines.append(line)

    def _pump_stderr(self) -> None:
        assert self.process and self.process.stderr
        for line in self.process.stderr:
            self.stderr.append(line)

    def send(self, payload: dict) -> None:
        assert self.process and self.process.stdin
        self.process.stdin.write(json.dumps(payload) + "\n")
        self.process.stdin.flush()

    def await_response(self, request_id: int, deadline: float) -> dict | None:
        while time.time() < deadline:
            for line in list(self.lines):
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if message.get("id") == request_id:
                    return message
            time.sleep(0.25)
        return None

    def stop(self) -> None:
        if not self.process:
            return
        try:
            self.process.kill()
            self.process.wait(timeout=10)
        except Exception:
            pass

    def stderr_tail(self, limit: int = 600) -> str:
        return "".join(self.stderr).strip()[-limit:]


def probe(server: str, argv: list[str], timeout: int) -> tuple[bool, list[str], str]:
    """Start one server, shake hands, and return (ok, tool names, detail)."""
    client = McpClient(argv, timeout)
    try:
        client.start()
    except FileNotFoundError as exc:
        return False, [], f"executable not found: {exc}"

    deadline = time.time() + timeout
    try:
        client.send(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "boilerplate-smoke-test", "version": "1"},
                },
            }
        )

        response = client.await_response(1, deadline)
        if response is None:
            return False, [], f"no initialize response within {timeout}s"
        if "error" in response:
            return False, [], f"initialize error: {json.dumps(response['error'])[:200]}"

        client.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        client.send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})

        tools_response = client.await_response(2, time.time() + timeout)
        if tools_response is None:
            return False, [], f"no tools/list response within {timeout}s"
        if "error" in tools_response:
            return False, [], f"tools/list error: {json.dumps(tools_response['error'])[:200]}"

        tools = [tool.get("name", "?") for tool in tools_response.get("result", {}).get("tools", [])]
        if not tools:
            return False, [], "server started but exposed no tools"
        return True, tools, ""
    finally:
        client.stop()


def main() -> int:
    args = sys.argv[1:]

    timeout = DEFAULT_TIMEOUT
    if "--timeout" in args:
        index = args.index("--timeout")
        try:
            timeout = int(args[index + 1])
            del args[index : index + 2]
        except (IndexError, ValueError):
            print("error: --timeout needs a number of seconds", file=sys.stderr)
            return 2

    if "--list" in args:
        for server, argv in CANONICAL_MCP.items():
            print(f"{server:<14}{' '.join(argv)}")
        return 0

    requested = [a for a in args if not a.startswith("-")]
    servers = requested or list(CANONICAL_MCP)

    unknown = [s for s in servers if s not in CANONICAL_MCP]
    if unknown:
        print(f"error: unknown server(s) {unknown}", file=sys.stderr)
        return 2

    print(f"MCP smoke test (timeout {timeout}s per server)")
    print("-" * 78)

    failures = 0
    for server in servers:
        argv = CANONICAL_MCP[server]
        print(f"[....] {server:<12} {' '.join(argv)}", flush=True)

        ok, tools, detail = probe(server, argv, timeout)
        if ok:
            print(f"[PASS] {server:<12} {len(tools)} tool(s): {', '.join(tools[:8])}")
            if len(tools) > 8:
                print(f"       ...and {len(tools) - 8} more")
        else:
            failures += 1
            print(f"[FAIL] {server:<12} {detail}")

    print("-" * 78)
    if failures:
        print(f"[FAIL] {failures} of {len(servers)} MCP server(s) failed to start.")
        return 1

    print(f"[PASS] All {len(servers)} MCP server(s) started and exposed tools.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
