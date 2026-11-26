#!/usr/bin/env bash
# ==============================================================================
# Script Syntax & AST Verification Suite (POSIX)
# Validates syntax of all .sh, .py, and .ps1 scripts in the repository.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "============================================================"
echo "   Script Syntax & AST Integrity Verification Suite (POSIX)  "
echo "============================================================"
echo "[INFO] Project root: ${PROJECT_ROOT}"

TOTAL_ERRORS=0

# The excluded directories are PRUNED, not merely filtered with `-not -path`.
# `-not -path` only suppresses the *output*; `find` still walks every file
# inside node_modules and the project-local .cache/ tree, which holds the uv
# and npm package caches. That made this suite take minutes instead of
# seconds.
#
# 1. Shell Script Validation via bash -n
echo ""
echo "--- Validating Shell Scripts via bash -n ---"
while IFS= read -r -d '' sh_file; do
    rel_path="${sh_file#$PROJECT_ROOT/}"
    if bash -n "${sh_file}" 2>/dev/null; then
        echo "[PASS] ${rel_path} (Bash Syntax Clean)"
    else
        echo "[FAIL] ${rel_path} (Bash syntax error detected)"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
done < <(find "${PROJECT_ROOT}" \
    \( -type d \( -name "node_modules" -o -name ".cache" -o -name ".git" \
       -o -name "dist" -o -name "build" -o -name ".venv" -o -name "venv" \
       -o -name "env" -o -name "ENV" -o -name "__pycache__" \
       -o -name ".pytest_cache" -o -name "sandbox" -o -name ".sandbox" \) -prune \) \
    -o \( -type f -name "*.sh" -print0 \))

# 2. Python Script Validation via py_compile
echo ""
echo "--- Validating Python Scripts via py_compile ---"
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

if [ -n "${PYTHON_BIN}" ]; then
    while IFS= read -r -d '' py_file; do
        rel_path="${py_file#$PROJECT_ROOT/}"
        if "${PYTHON_BIN}" -m py_compile "${py_file}" 2>/dev/null; then
            echo "[PASS] ${rel_path} (Bytecode Clean)"
        else
            echo "[FAIL] ${rel_path} (Compilation error)"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    done < <(find "${PROJECT_ROOT}" \
        \( -type d \( -name "node_modules" -o -name ".cache" -o -name ".git" \
           -o -name "dist" -o -name "build" -o -name ".venv" -o -name "venv" \
           -o -name "env" -o -name "ENV" -o -name "__pycache__" \
           -o -name ".pytest_cache" -o -name "sandbox" -o -name ".sandbox" \) -prune \) \
        -o \( -type f -name "*.py" -print0 \))
else
    echo "[WARN] Python not found; skipping py_compile checks"
fi

# 3. Hook Dry-Run Checks
HOOKS_DIR="${PROJECT_ROOT}/scripts/hooks"
if [ -d "${HOOKS_DIR}" ]; then
    echo ""
    echo "--- Executing POSIX Hook Dry-Run Checks ---"
    
    PROTECT_HOOK="${HOOKS_DIR}/protect-config.sh"
    if [ -f "${PROTECT_HOOK}" ]; then
        if echo '{"tool_name":"write_file","target_path":"test.txt"}' | bash "${PROTECT_HOOK}" >/dev/null 2>&1; then
            echo "[PASS] protect-config.sh permitted in-scope target"
        else
            echo "[FAIL] protect-config.sh blocked in-scope target"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    fi

    RTK_HOOK="${HOOKS_DIR}/rtk-filter.sh"
    if [ -f "${RTK_HOOK}" ]; then
        if echo "test log" | bash "${RTK_HOOK}" >/dev/null 2>&1; then
            echo "[PASS] rtk-filter.sh executed cleanly"
        else
            echo "[FAIL] rtk-filter.sh failed"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    fi
fi

echo ""
echo "============================================================"
if [ "${TOTAL_ERRORS}" -eq 0 ]; then
    echo "   Script Verification Complete: 100% Passed                "
    echo "============================================================"
    exit 0
else
    echo "   Script Verification FAILED with ${TOTAL_ERRORS} error(s)    "
    echo "============================================================"
    exit 1
fi
