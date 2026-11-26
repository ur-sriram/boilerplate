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

# 3. Establish the skill junctions for every supported agent.
#    Delegated to sync-agent-adapters.sh so the link logic lives in ONE place.
#    The previous inline copy only created .codex and .qoder, which left Claude
#    Code, Cursor, Windsurf and Cline with zero access to the 378-skill store.
echo "[INFO] Establishing relative symbolic links to .agents/skills..."
if bash "${PROJECT_ROOT}/scripts/sync-agent-adapters.sh"; then
    echo "[OK] Skill junctions established for all supported agents."
else
    echo "[WARN] Some skill junctions could not be established; run scripts/sync-agent-adapters.sh manually."
fi

# 4. Ensure .gitignore protects mirrored directories
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"
if [ -f "${GITIGNORE_FILE}" ]; then
    for pattern in ".claude/skills/" ".cline/skills/" ".codex/skills/" ".cursor/skills/" ".qoder/skills/" ".windsurf/skills/"; do
        if ! grep -q "^${pattern}$" "${GITIGNORE_FILE}" 2>/dev/null; then
            echo -e "\n# Secondary Agent Mirrored Skills\n${pattern}" >> "${GITIGNORE_FILE}"
        fi
    done
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
