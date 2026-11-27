#!/usr/bin/env bash
# ==============================================================================
# Runtime Prerequisites & MCP Tool Resolution Verification Suite (POSIX)
# Validates core runtimes (Git, Node, Python, Shell) and resolves MCP commands.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "============================================================"
echo "   Runtime Prerequisites & MCP Tool Verification (POSIX)    "
echo "============================================================"
echo "[INFO] Project root: ${PROJECT_ROOT}"

CRITICAL_ERRORS=0
WARNINGS=0

# ----------------------------------------------------------------------
# 1. Core Runtime Prerequisites Validation
# ----------------------------------------------------------------------
echo ""
echo "--- Checking Core Runtime Prerequisites ---"

# 1a. Git
if command -v git >/dev/null 2>&1; then
    GIT_PATH="$(command -v git)"
    GIT_VER="$(git --version 2>&1)"
    echo "[OK] Git: ${GIT_VER} (${GIT_PATH})"
else
    echo "[FAIL] Git was not found in PATH."
    echo "       Diagnostic: Install git via your system package manager (apt, brew, dnf)."
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
fi

# 1b. Node.js
if command -v node >/dev/null 2>&1; then
    NODE_PATH="$(command -v node)"
    NODE_VER="$(node --version 2>&1)"
    echo "[OK] Node.js: ${NODE_VER} (${NODE_PATH})"

    # Node 22.18.0 is the first release that strips TypeScript types by
    # default. The test suite, the claude-mem CLI and every hook that runs a
    # .ts file need it. On an older runtime they die with an opaque
    # ERR_UNKNOWN_FILE_EXTENSION, so the version is checked here instead.
    if node -e 'const [maj,min]=process.versions.node.split(".").map(Number);process.exit(maj>22||(maj===22&&min>=18)?0:1)' >/dev/null 2>&1; then
        echo "[OK] Node.js is new enough for TypeScript type stripping (>= 22.18.0)."
    else
        echo "[FAIL] Node.js ${NODE_VER} is too old: TypeScript type stripping needs Node >= 22.18.0."
        echo "       Diagnostic: Upgrade Node.js (https://nodejs.org/). The test suite, the claude-mem CLI and the lifecycle hooks all run .ts files directly."
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
else
    echo "[FAIL] Node.js was not found in PATH."
    echo "       Diagnostic: Install Node.js LTS (>= 22.18.0) from https://nodejs.org/"
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
fi

# 1c. Python
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

if [ -n "${PYTHON_CMD}" ]; then
    PY_PATH="$(command -v "${PYTHON_CMD}")"
    PY_VER="$("${PYTHON_CMD}" --version 2>&1)"
    echo "[OK] Python: ${PY_VER} (${PY_PATH})"
else
    echo "[FAIL] Python was not found in PATH."
    echo "       Diagnostic: Install Python 3 (>= 3.10) from https://www.python.org/"
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
fi

# 1d. Shell Environment
if command -v bash >/dev/null 2>&1; then
    BASH_PATH="$(command -v bash)"
    echo "[OK] Shell: Bash (${BASH_PATH})"
elif command -v sh >/dev/null 2>&1; then
    SH_PATH="$(command -v sh)"
    echo "[OK] Shell: sh (${SH_PATH})"
else
    echo "[FAIL] No standard POSIX shell (bash/sh) detected."
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
fi

# ----------------------------------------------------------------------
# 2. Package Managers & MCP Launchers
# ----------------------------------------------------------------------
echo ""
echo "--- Checking MCP Launchers & CLI Package Managers ---"

# 2a. npx
if command -v npx >/dev/null 2>&1; then
    NPX_PATH="$(command -v npx)"
    NPX_VER="$(npx --version 2>&1 || true)"
    echo "[OK] npx: v${NPX_VER} (${NPX_PATH})"
else
    echo "[FAIL] npx was not found in PATH (required for ui-registry-mcp)."
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
fi

# 2b. uvx / uv
if command -v uvx >/dev/null 2>&1; then
    UVX_PATH="$(command -v uvx)"
    UVX_VER="$(uvx --version 2>&1 || true)"
    echo "[OK] uvx: ${UVX_VER} (${UVX_PATH})"
elif command -v uv >/dev/null 2>&1; then
    UV_PATH="$(command -v uv)"
    UV_VER="$(uv --version 2>&1 || true)"
    echo "[OK] uv: ${UV_VER} (uvx available via 'uv tool run')"
else
    echo "[WARN] uv / uvx not detected in PATH."
    echo "       Diagnostic: uvx is required for graphify and headroom MCP servers."
    echo "       Install via: curl -LsSf https://astral.sh/uv/install.sh | sh"
    WARNINGS=$((WARNINGS + 1))
fi

# ----------------------------------------------------------------------
# 3. Project MCP Server Configuration & Command Resolution
# ----------------------------------------------------------------------
echo ""
echo "--- Resolving Configured MCP Servers ---"

MCP_CONFIG="${PROJECT_ROOT}/.mcp.json"
if [ ! -f "${MCP_CONFIG}" ]; then
    MCP_CONFIG="${PROJECT_ROOT}/.agents/mcp.json"
fi

if [ -f "${MCP_CONFIG}" ] && [ -n "${PYTHON_CMD}" ]; then
    echo "[INFO] Reading MCP manifest from ${MCP_CONFIG}"
    MCP_RESOLVE_ERRORS=$("${PYTHON_CMD}" -c "
import json, sys, shutil
from pathlib import Path

config_path = Path('${MCP_CONFIG}')
try:
    data = json.loads(config_path.read_text(encoding='utf-8'))
except Exception as e:
    print(f'[FAIL] Failed to parse {config_path}: {e}')
    sys.exit(1)

servers = data.get('mcpServers', {})
errors = 0
for name, srv in servers.items():
    cmd = srv.get('command')
    if not cmd:
        print(f'[FAIL] MCP server \'{name}\': missing command')
        errors += 1
        continue
    resolved = shutil.which(cmd)
    if resolved:
        print(f'[PASS] MCP server \'{name}\': command \'{cmd}\' -> {resolved}')
    else:
        print(f'[FAIL] MCP server \'{name}\': command \'{cmd}\' not found in PATH')
        errors += 1

sys.exit(errors)
" 2>&1) || MCP_ERR_CODE=$?

    echo "${MCP_RESOLVE_ERRORS}"
    if [ "${MCP_ERR_CODE:-0}" -ne 0 ]; then
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + ${MCP_ERR_CODE:-1}))
    fi
else
    if [ ! -f "${MCP_CONFIG}" ]; then
        echo "[WARN] No .mcp.json found in project root."
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# ----------------------------------------------------------------------
# 4. Summary & Exit Code
# ----------------------------------------------------------------------
echo ""
echo "============================================================"
if [ "${CRITICAL_ERRORS}" -eq 0 ]; then
    if [ "${WARNINGS}" -gt 0 ]; then
        echo "   Verification Passed with ${WARNINGS} warning(s).                 "
    else
        echo "   Runtime & MCP Tool Verification 100% Passed               "
    fi
    echo "============================================================"
    exit 0
else
    echo "   Verification FAILED: ${CRITICAL_ERRORS} critical error(s), ${WARNINGS} warning(s)."
    echo "============================================================"
    exit 1
fi
