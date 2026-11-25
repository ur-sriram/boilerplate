#!/usr/bin/env sh
# SessionStart Environment Validator Hook for POSIX environments (Linux / macOS).
# Validates presence of core tools and verifies project setup.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Boilerplate Agent Session Initialization ==="
echo "Project Root: $PROJECT_ROOT"

# Check runtimes
for cmd in git node python3 sh; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK] $cmd: $(command -v "$cmd")"
    else
        echo "[WARN] $cmd: Not found in PATH"
    fi
done

# Check optional compression binary
if command -v rtk >/dev/null 2>&1; then
    echo "[OK] rtk compressor: Present ($(command -v rtk))"
else
    echo "[INFO] rtk compressor: Absent (graceful passthrough active)"
fi

# Check skills store
if [ -d "$PROJECT_ROOT/.agents/skills" ]; then
    echo "[OK] Canonical Skills Store: Present (.agents/skills)"
else
    echo "[INFO] Canonical Skills Store: Pending (.agents/skills)"
fi

echo "=== Initialization Complete (Ready for Agent Tasks) ==="
exit 0
