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

        # A guardrail that is only ever tested on the ALLOW path is not tested.
        # Claude Code, Codex, Qoder, Goose and Antigravity all send the target
        # as `tool_input.file_path`; when the hook did not look there it found
        # no path, treated the payload as read-only, and allowed the write.
        OUT_OF_SCOPE='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/etc/passwd","content":"x"}}'
        if echo "${OUT_OF_SCOPE}" | bash "${PROTECT_HOOK}" >/dev/null 2>&1; then
            echo "[FAIL] protect-config.sh allowed an out-of-scope tool_input.file_path"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        else
            echo "[PASS] protect-config.sh blocked an out-of-scope tool_input.file_path"
        fi

        # The payload used to be interpolated into a Python source literal, so
        # three consecutive quotes broke the parse, the path was never
        # extracted, and the write was allowed.
        QUOTE_PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"},"content":"docstring '"'"''"'"''"'"' here"}'
        if echo "${QUOTE_PAYLOAD}" | bash "${PROTECT_HOOK}" >/dev/null 2>&1; then
            echo "[FAIL] protect-config.sh allowed an out-of-scope write with quotes in the payload"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        else
            echo "[PASS] protect-config.sh blocked an out-of-scope write with quotes in the payload"
        fi
    fi

    # run-hook.mjs is the dispatcher that Claude Code, Codex, Goose and Qoder
    # actually invoke. It was never executed by this suite, so a regression in
    # it stayed invisible.
    RUN_HOOK="${HOOKS_DIR}/run-hook.mjs"
    if [ -f "${RUN_HOOK}" ] && command -v node >/dev/null 2>&1; then
        if echo '{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}' | node "${RUN_HOOK}" protect-config >/dev/null 2>&1; then
            echo "[FAIL] run-hook.mjs allowed an out-of-scope tool_input.file_path"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        else
            echo "[PASS] run-hook.mjs blocked an out-of-scope tool_input.file_path"
        fi

        if echo '{"tool_name":"Write","tool_input":{"file_path":"src/lib/verify-probe.ts"}}' | node "${RUN_HOOK}" protect-config >/dev/null 2>&1; then
            echo "[PASS] run-hook.mjs permitted an in-scope tool_input.file_path"
        else
            echo "[FAIL] run-hook.mjs blocked an in-scope tool_input.file_path"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    else
        echo "[WARN] run-hook.mjs or node not found; skipping dispatcher guardrail checks"
    fi

    # The rtk hook used to pipe the agent's JSON hook payload straight into
    # `rtk filter` and echo the whole envelope back when rtk was missing - so
    # it never compressed terminal output, and the dry-run only asserted that
    # it exited 0. A feature that cannot be observed is a feature that decays.
    # These three assertions pin the behaviour that matters.
    RTK_HOOK="${HOOKS_DIR}/rtk-filter.sh"
    if [ -f "${RTK_HOOK}" ]; then
        RTK_SAMPLE="rtk dry-run sample output"

        RTK_OUT="$(printf '%s' "${RTK_SAMPLE}" | bash "${RTK_HOOK}" 2>/dev/null || true)"
        if [ "${RTK_OUT}" = "${RTK_SAMPLE}" ]; then
            echo "[PASS] rtk-filter.sh passed the output through unchanged (rtk absent)"
        else
            echo "[FAIL] rtk-filter.sh altered the output while rtk was absent"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi

        RTK_PAYLOAD='{"tool_name":"Bash","tool_response":{"stdout":"REAL TERMINAL OUTPUT"}}'
        RTK_OUT="$(printf '%s' "${RTK_PAYLOAD}" | bash "${RTK_HOOK}" 2>/dev/null || true)"
        if [ "${RTK_OUT}" = "REAL TERMINAL OUTPUT" ]; then
            echo "[PASS] rtk-filter.sh extracted the terminal output from the hook payload"
        else
            echo "[FAIL] rtk-filter.sh did not extract the terminal output (got: ${RTK_OUT})"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi

        # A fake rtk on PATH proves the filter is actually used when it is
        # installed. The scratch directory lives inside the project: this
        # repository does not write outside the project root.
        RTK_FAKE_DIR="${PROJECT_ROOT}/.cache/rtk-fake-$$"
        mkdir -p "${RTK_FAKE_DIR}"
        printf '%s\n' '#!/usr/bin/env sh' "sed 's/^/RTK_COMPRESSED: /'" > "${RTK_FAKE_DIR}/rtk"
        chmod +x "${RTK_FAKE_DIR}/rtk" 2>/dev/null || true
        RTK_OUT="$(printf '%s' "${RTK_SAMPLE}" | PATH="${RTK_FAKE_DIR}:${PATH}" bash "${RTK_HOOK}" 2>/dev/null || true)"
        rm -rf "${RTK_FAKE_DIR}"
        case "${RTK_OUT}" in
            *RTK_COMPRESSED*)
                echo "[PASS] rtk-filter.sh compressed the output through rtk" ;;
            *)
                echo "[FAIL] rtk-filter.sh did not use rtk when it was available"
                TOTAL_ERRORS=$((TOTAL_ERRORS + 1)) ;;
        esac
    fi

    # The claude-mem hook used to be a mkdir+echo stub that no adapter ever
    # registered, so it "passed" every check while persisting nothing. It is
    # now exercised for real: it must recall the episodic store without
    # failing.
    MEMORY_HOOK="${HOOKS_DIR}/memory-sync.sh"
    if [ -f "${MEMORY_HOOK}" ]; then
        if MEM_OUT="$(bash "${MEMORY_HOOK}" 2>&1)" && echo "${MEM_OUT}" | grep -q "\[MEMORY\]"; then
            echo "[PASS] memory-sync.sh recalled the episodic store"
        else
            echo "[FAIL] memory-sync.sh did not report the episodic store"
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
