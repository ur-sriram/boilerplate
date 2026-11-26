#!/usr/bin/env sh
# ==============================================================================
# Claude-Mem Episodic Memory Sync Hook (POSIX / Linux / macOS)
#
# Recalls the project's cross-session episodic memory and prints it as
# session context.
#
# WHY THE CLI IS CALLED INSTEAD OF REIMPLEMENTED HERE
# The store lives in src/features/claude-mem/ and is covered by unit tests.
# Both hook twins and the cross-platform dispatcher therefore invoke the same
# CLI, so the three entry points can never disagree about the format, the
# redaction rules or the store location.
#
# The hook is ADVISORY: it never blocks a session and never fails it.
# ==============================================================================
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
    echo "[MEMORY] node runtime not found; claude-mem episodic sync skipped"
    exit 0
fi

exec node "${ROOT_DIR}/src/features/claude-mem/cli.ts" sync --root "${ROOT_DIR}"
