#!/usr/bin/env sh
# PreToolUse Guardrail Hook for POSIX environments (Linux / macOS).
# Blocks file modification or creation outside project root.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_PATH="$1"

# If no argument, attempt to read from stdin
if [ -z "$TARGET_PATH" ] && [ ! -t 0 ]; then
    INPUT_PAYLOAD=$(cat)
    # Extract path from JSON if python3 is available
    if command -v python3 >/dev/null 2>&1; then
        TARGET_PATH=$(python3 -c "
import sys, json
try:
    data = json.loads('''$INPUT_PAYLOAD''')
    path = data.get('path') or data.get('file') or data.get('target') or (data.get('params') or {}).get('path')
    if path: print(path)
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

# Resolve absolute path of target
if command -v realpath >/dev/null 2>&1; then
    RESOLVED_TARGET=$(realpath -m "$TARGET_PATH" 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
    RESOLVED_TARGET=$(python3 -c "import os, sys; print(os.path.abspath(sys.argv[1]))" "$TARGET_PATH" 2>/dev/null || true)
else
    case "$TARGET_PATH" in
        /*) RESOLVED_TARGET="$TARGET_PATH" ;;
        *)  RESOLVED_TARGET="$PROJECT_ROOT/$TARGET_PATH" ;;
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
