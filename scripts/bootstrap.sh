#!/usr/bin/env bash
# ==============================================================================
# Multi-Agent Project Boilerplate Bootstrap Initialization (POSIX)
# Establishes relative symlinks (.codex/skills, .qoder/skills -> .agents/skills),
# verifies local runtimes, and enforces zero-global-config project scoping.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "============================================================"
echo "   Multi-Agent Project Boilerplate Bootstrap Initialization  "
echo "============================================================"
echo "[INFO] Project root: ${PROJECT_ROOT}"

# 1. Ensure canonical skill store directory exists
CANONICAL_SKILLS="${PROJECT_ROOT}/.agents/skills"
mkdir -p "${CANONICAL_SKILLS}"

# 2. Setup secondary agent directories
mkdir -p "${PROJECT_ROOT}/.codex"
mkdir -p "${PROJECT_ROOT}/.qoder"

# 3. Create relative symlinks for secondary agents
echo "[INFO] Establishing relative symbolic links to .agents/skills..."
if ln -sfn "../.agents/skills" "${PROJECT_ROOT}/.codex/skills" 2>/dev/null; then
    echo "[OK] Symlink established: .codex/skills -> ../.agents/skills"
else
    echo "[WARN] Symlink failed; creating fallback directory..."
    mkdir -p "${PROJECT_ROOT}/.codex/skills"
    if [ -d "${CANONICAL_SKILLS}" ]; then
        cp -R "${CANONICAL_SKILLS}/"* "${PROJECT_ROOT}/.codex/skills/" 2>/dev/null || true
    fi
fi

if ln -sfn "../.agents/skills" "${PROJECT_ROOT}/.qoder/skills" 2>/dev/null; then
    echo "[OK] Symlink established: .qoder/skills -> ../.agents/skills"
else
    echo "[WARN] Symlink failed; creating fallback directory..."
    mkdir -p "${PROJECT_ROOT}/.qoder/skills"
    if [ -d "${CANONICAL_SKILLS}" ]; then
        cp -R "${CANONICAL_SKILLS}/"* "${PROJECT_ROOT}/.qoder/skills/" 2>/dev/null || true
    fi
fi

# 4. Ensure .gitignore protects mirrored directories
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"
if [ -f "${GITIGNORE_FILE}" ]; then
    if ! grep -q "^\.codex/skills/" "${GITIGNORE_FILE}" 2>/dev/null; then
        echo -e "\n# Secondary Agent Mirrored Skills\n.codex/skills/" >> "${GITIGNORE_FILE}"
    fi
    if ! grep -q "^\.qoder/skills/" "${GITIGNORE_FILE}" 2>/dev/null; then
        echo ".qoder/skills/" >> "${GITIGNORE_FILE}"
    fi
fi

# 5. Environment Runtime Checks
echo ""
echo "--- Verifying Local Environment Runtimes ---"

if command -v git >/dev/null 2>&1; then
    echo "[OK] Git: $(git --version)"
else
    echo "[WARN] Git not found in PATH"
fi

if command -v node >/dev/null 2>&1; then
    echo "[OK] Node.js: $(node --version)"
else
    echo "[WARN] Node.js not found in PATH"
fi

if command -v python3 >/dev/null 2>&1; then
    echo "[OK] Python: $(python3 --version)"
elif command -v python >/dev/null 2>&1; then
    echo "[OK] Python: $(python --version)"
else
    echo "[WARN] Python not found in PATH"
fi

if command -v bash >/dev/null 2>&1; then
    echo "[OK] Bash: $(bash --version | head -n 1)"
fi

echo ""
echo "============================================================"
echo "   Bootstrap Complete: 0 global files modified              "
echo "============================================================"
exit 0
