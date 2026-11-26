#!/usr/bin/env bash
# ==============================================================================
# Unified Verification Suite Runner (POSIX)
# Runs all verification suites in sequence:
# 1. verify-tools.sh
# 2. verify-scripts.sh
# 3. verify-links.py
# 4. test-bootstrap.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "============================================================"
echo "   Multi-Agent Project Boilerplate: Unified Verification    "
echo "============================================================"
echo "[INFO] Project root: ${PROJECT_ROOT}"
echo "[INFO] Execution timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

OVERALL_FAILED=0
declare -a SUITE_NAMES=()
declare -a SUITE_STATUS=()

run_suite() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo ">>> RUNNING: ${name}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    
    SUITE_NAMES+=("${name}")
    if eval "${cmd}"; then
        SUITE_STATUS+=("PASS")
    else
        SUITE_STATUS+=("FAIL")
        OVERALL_FAILED=1
    fi
}

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

# 1. verify-tools.sh
run_suite "1. verify-tools" "bash '${SCRIPT_DIR}/verify-tools.sh'"

# 2. verify-scripts.sh
run_suite "2. verify-scripts" "bash '${SCRIPT_DIR}/verify-scripts.sh'"

# 3. verify-file-limits.sh
run_suite "3. verify-file-limits" "bash '${SCRIPT_DIR}/verify-file-limits.sh'"

# 4. verify-links.py
if [ -n "${PYTHON_CMD:-${PYTHON_BIN:-}}" ]; then
    PY_EXEC="${PYTHON_CMD:-${PYTHON_BIN}}"
    run_suite "4. verify-links" "'${PY_EXEC}' '${SCRIPT_DIR}/verify-links.py' '${PROJECT_ROOT}'"
else
    echo "[WARN] Python not found; skipping verify-links"
fi

# 5. sync-agent-adapters.sh
#    Creates the skill junctions first, then verifies them. Verifying a fresh
#    clone without creating them always failed (all 6 junctions are
#    gitignored and only bootstrap creates 2 of the 6).
run_suite "5. sync-agent-adapters" "bash '${SCRIPT_DIR}/sync-agent-adapters.sh' && bash '${SCRIPT_DIR}/sync-agent-adapters.sh' --verify-only"

# 6. test-bootstrap.sh
run_suite "6. test-bootstrap" "bash '${SCRIPT_DIR}/test-bootstrap.sh'"

# 7. skills-index drift check (the wiring map must match the store on disk)
# 8. adapter parity check (every agent gets the same capabilities)
# 9. Spec Kit vendored-file integrity
if [ -n "${PYTHON_CMD:-${PYTHON_BIN:-}}" ]; then
    PY_EXEC="${PYTHON_CMD:-${PYTHON_BIN}}"
    run_suite "7. skills-index" "'${PY_EXEC}' '${SCRIPT_DIR}/generate-skills-index.py' --check"
    run_suite "8. verify-adapters" "'${PY_EXEC}' '${SCRIPT_DIR}/verify-adapters.py'"
    run_suite "9. specify-integrity" "'${PY_EXEC}' '${SCRIPT_DIR}/verify-specify-integrity.py'"
else
    echo "[WARN] Python not found; skipping skills-index and adapter checks"
fi

echo ""
echo "============================================================"
echo "               VERIFICATION SUITE SUMMARY                   "
echo "============================================================"

for i in "${!SUITE_NAMES[@]}"; do
    printf " %-25s [%s]\n" "${SUITE_NAMES[$i]}" "${SUITE_STATUS[$i]}"
done

echo "============================================================"
if [ "${OVERALL_FAILED}" -eq 0 ]; then
    echo " ALL VERIFICATION SUITES PASSED (100% GREEN) "
    echo "============================================================"
    exit 0
else
    echo " VERIFICATION FAILED: One or more suites encountered errors. "
    echo "============================================================"
    exit 1
fi
