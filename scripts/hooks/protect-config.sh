#!/usr/bin/env sh
# PreToolUse Guardrail Hook for POSIX environments (Linux / macOS).
# Blocks file modification or creation outside project root.
#
# Path resolution contract (both sides must agree or every write is blocked):
#   - PROJECT_ROOT is resolved PHYSICALLY (pwd -P), so a checkout that lives
#     behind a symlink (/workspace -> /run/csi/..., /tmp -> /private/tmp on
#     macOS) still compares equal to the physically-resolved target.
#   - The target is resolved with `realpath -m` (physical), matching the root.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

TARGET_PATH="$1"

# If no argument, attempt to read from stdin
if [ -z "$TARGET_PATH" ] && [ ! -t 0 ]; then
    INPUT_PAYLOAD=$(cat)
    # Extract path from JSON if python3 is available.
    # The payload is piped on STDIN, never interpolated into the Python
    # source: a Write payload carries the file CONTENT, so an apostrophe in
    # it used to break the parse and turn a legitimate in-project write into
    # a false block.
    #
    # NOTE: the key set must match the PowerShell twin exactly:
    #       path | file | target | target_path | filePath | file_path
    #       and the tool_input | params | args | input containers.
    if command -v python3 >/dev/null 2>&1; then
        TARGET_PATH=$(printf '%s' "$INPUT_PAYLOAD" | python3 -c "
import sys, json

KEYS = ('path', 'file', 'target', 'target_path', 'filePath', 'file_path')
CONTAINERS = ('tool_input', 'params', 'args', 'input')


def first_string(container):
    for key in KEYS:
        value = container.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


try:
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        raise ValueError
    found = first_string(data)
    if found is None:
        for name in CONTAINERS:
            container = data.get(name)
            if not isinstance(container, dict):
                continue
            found = first_string(container)
            if found is not None:
                break
    if found is not None:
        print(found)
except Exception:
    pass
" 2>/dev/null || true)
    fi
    if [ -z "$TARGET_PATH" ]; then
        TARGET_PATH="$INPUT_PAYLOAD"
    fi
fi

# If still empty, allow (no path target)
if [ -z "$TARGET_PATH" ]; then
    exit 0
fi

# Expand leading tilde (~) to user home directory before path resolution
HOME_DIR="${HOME:-$USERPROFILE}"
case "$TARGET_PATH" in
    "~")
        if [ -z "$HOME_DIR" ]; then
            echo "[GUARDRAIL] Access Denied: Cannot resolve home directory for target path '$TARGET_PATH'." >&2
            exit 1
        fi
        TARGET_PATH="$HOME_DIR"
        ;;
    "~/"*|"~\\"*)
        if [ -z "$HOME_DIR" ]; then
            echo "[GUARDRAIL] Access Denied: Cannot resolve home directory for target path '$TARGET_PATH'." >&2
            exit 1
        fi
        SUB_PATH="${TARGET_PATH#??}"
        if [ -n "$SUB_PATH" ]; then
            TARGET_PATH="$HOME_DIR/$SUB_PATH"
        else
            TARGET_PATH="$HOME_DIR"
        fi
        ;;
esac

# Resolve absolute path of target (physical, matching PROJECT_ROOT)
if command -v realpath >/dev/null 2>&1; then
    RESOLVED_TARGET=$(realpath -m "$TARGET_PATH" 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
    RESOLVED_TARGET=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$TARGET_PATH" 2>/dev/null || true)
else
    case "$TARGET_PATH" in
        /*) RESOLVED_TARGET="$TARGET_PATH" ;;
        *) RESOLVED_TARGET="$PROJECT_ROOT/$TARGET_PATH" ;;
    esac
fi

# Check if target starts with PROJECT_ROOT
case "$RESOLVED_TARGET" in
    "$PROJECT_ROOT"/*|"$PROJECT_ROOT")
        exit 0
        ;;
    *)
        echo "[GUARDRAIL] Access Denied: Target path '$RESOLVED_TARGET' is outside project root '$PROJECT_ROOT'." >&2
        exit 1
        ;;
esac
