#!/usr/bin/env sh
# ==============================================================================
# rtk Output Filter Hook (POSIX / Linux / macOS) - thin wrapper.
#
# The filter itself lives in scripts/hooks/rtk-filter.mjs, which is the one
# implementation shared by this script, its PowerShell twin, the cross-platform
# dispatcher and the OpenCode plugin. They cannot disagree about the payload
# shape, the redaction rules or the runtime requirement.
#
# WHY THE WRAPPER EXISTS
# ----------------------
# A PostToolUse hook receives the agent's hook payload on stdin, which for
# Claude Code, Codex, Goose and Qoder is a JSON envelope - not terminal text.
# The implementation extracts the terminal text from that envelope before
# handing it to rtk; the previous revision piped the envelope itself into
# rtk and echoed it back when rtk was missing.
#
# Graceful degradation: without Node, or without rtk, the input is emitted
# unchanged. The filter never swallows output and never fails a session.
# ==============================================================================

set -u

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTER="${HOOKS_DIR}/rtk-filter.mjs"

if ! command -v node >/dev/null 2>&1; then
    # No runtime: emit the payload unchanged.
    cat
    exit 0
fi

if [ ! -f "${FILTER}" ]; then
    cat
    exit 0
fi

exec node "${FILTER}"
