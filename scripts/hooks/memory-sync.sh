#!/usr/bin/env sh
# ==============================================================================
# Claude-Mem Episodic Memory Sync Hook (POSIX / Linux / macOS)
#
# Recalls the project's cross-session episodic memory and prints it as
# session context.
#
# WHY THE LAUNCHER IS CALLED INSTEAD OF REIMPLEMENTED HERE
# The store lives in .repo/claude-mem/ and is covered by unit tests.
# Every entry point - this script, its PowerShell twin, the cross-platform
# dispatcher and the OpenCode plugin - therefore invokes the same launcher,
# so they can never disagree about the format, the redaction rules, the
# store location or the runtime requirement.
#
# The hook is ADVISORY: it never blocks a session and never fails it.
# ==============================================================================
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
    echo "[MEMORY] node runtime not found; claude-mem episodic sync skipped"
    exit 0
fi

exec node "${ROOT_DIR}/.repo/claude-mem/run.mjs" sync --root "${ROOT_DIR}"
