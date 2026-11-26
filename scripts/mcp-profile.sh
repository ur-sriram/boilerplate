#!/usr/bin/env sh
# Dynamic MCP Profile Switcher (POSIX wrapper).
#
# The implementation lives in scripts/mcp-profile.py so the POSIX and Windows
# paths can never drift. The previous inline .sh version only updated
# `opencode.json` and `.antigravity/*`, leaving six other adapter configs on
# the wrong profile.
#
# Usage: ./scripts/mcp-profile.sh <core|ui|compression|all>
#        ./scripts/mcp-profile.sh --status

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

PROFILE="${1:-core}"

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    echo "[FAIL] Python is required to switch MCP profiles." >&2
    exit 1
fi

exec "${PYTHON_BIN}" "${PROJECT_ROOT}/scripts/mcp-profile.py" "${PROFILE}"
