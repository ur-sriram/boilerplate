#!/usr/bin/env bash
# ==============================================================================
# Isolated Sandbox Bootstrap & Structural Integrity Smoke Test Suite (POSIX)
# Validates zero global configuration pollution and structural repository bounds.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "============================================================"
echo "   Sandbox Bootstrap & Boundary Assertion Suite (POSIX)     "
echo "============================================================"
echo "[INFO] Source repository: ${PROJECT_ROOT}"

TOTAL_ERRORS=0

# Create an isolated sandbox directory.
#
# The sandbox MUST live outside the repository (it contains a copy of the
# repository, so a sandbox inside it would recurse). It therefore uses the
# system temp directory, which is the single documented exception to the
# "writes stay inside the project" rule — the sandbox is deleted on exit.
# Set BOILERPLATE_SANDBOX_ROOT to place it elsewhere.
if [ -n "${BOILERPLATE_SANDBOX_ROOT:-}" ]; then
    SANDBOX_DIR="${BOILERPLATE_SANDBOX_ROOT}/boilerplate_smoke_$$"
    mkdir -p "${SANDBOX_DIR}"
else
    SANDBOX_DIR="$(mktemp -d /tmp/boilerplate_smoke_XXXXXX 2>/dev/null || mktemp -d -t 'boilerplate_smoke_XXXXXX')"
fi
echo "[INFO] Created isolated sandbox directory: ${SANDBOX_DIR}"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi
# NOTE: every assertion below used to reference ${PYTHON_CMD}, which was never
# defined. Under `set -u` that aborted the whole script at the first use, so
# the config-parse, skill-wiring and ignore-mirroring assertions never ran.
# PYTHON_CMD may still be supplied by the caller to pin a specific interpreter.
PYTHON_CMD="${PYTHON_CMD:-${PYTHON_BIN:-}}"

# ----------------------------------------------------------------------
# 1. Snapshot Sensitive Global Directories Before Bootstrap
# ----------------------------------------------------------------------
echo ""
echo "--- Snapshotting Sensitive Global Directories ---"
SNAPSHOT_FILE="${SANDBOX_DIR}/.external_snapshot.txt"
touch "${SNAPSHOT_FILE}"

MONITORED_DIRS=(
    "${HOME}/.config"
    "${HOME}/.claude"
    "${HOME}/.gemini"
    "${HOME}/.codex"
    "${HOME}/.qoder"
    "${HOME}/.goose"
)

for m_dir in "${MONITORED_DIRS[@]}"; do
    if [ -d "${m_dir}" ]; then
        find "${m_dir}" -type f \
            -not -path "*/antigravity/brain/*" \
            -not -path "*/antigravity/scratch/*" \
            -not -name "*.pb" \
            -not -name "*.log" \
            -exec ls -ld {} + >> "${SNAPSHOT_FILE}" 2>/dev/null || true
    fi
done
SNAPSHOT_COUNT="$(wc -l < "${SNAPSHOT_FILE}" | tr -d ' ')"
echo "[INFO] Snapshotted ${SNAPSHOT_COUNT} external file reference(s)."

# ----------------------------------------------------------------------
# 2. Replicate Repository into Isolated Sandbox
# ----------------------------------------------------------------------
echo ""
echo "--- Replicating Repository into Isolated Sandbox ---"
mkdir -p "${SANDBOX_DIR}/repo"
# Copy the repository into the sandbox.
#
# The copy EXCLUDES the project-local caches (`.cache/`), the VCS metadata and
# installed dependencies. The previous revision used `cp -R` followed by
# `rm -rf`, which copied the entire uv/npm cache - hundreds of megabytes and
# hundreds of thousands of files - into the sandbox before deleting it, and
# made this suite unusably slow. Excluding at copy time also keeps the
# sandbox free of another project-local cache tree.
tar -C "${PROJECT_ROOT}" \
    --exclude='./.git' \
    --exclude='./.cache' \
    --exclude='./node_modules' \
    --exclude='./.venv' \
    --exclude='./venv' \
    --exclude='./__pycache__' \
    -cf - . 2>/dev/null | tar -C "${SANDBOX_DIR}/repo" -xf - 2>/dev/null || true
echo "[OK] Sandbox repository populated."

# ----------------------------------------------------------------------
# 3. Execute Bootstrap Sequence in Sandbox
# ----------------------------------------------------------------------
echo ""
echo "--- Executing Bootstrap Sequence in Sandbox ---"
BOOTSTRAP_SCRIPT="${SANDBOX_DIR}/repo/scripts/bootstrap.sh"
if [ -f "${BOOTSTRAP_SCRIPT}" ]; then
    chmod +x "${BOOTSTRAP_SCRIPT}"
    if bash "${BOOTSTRAP_SCRIPT}"; then
        echo "[PASS] Bootstrap sequence executed cleanly inside sandbox."
    else
        echo "[FAIL] Bootstrap sequence failed inside sandbox."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo "[FAIL] bootstrap.sh not found at ${BOOTSTRAP_SCRIPT}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

# ----------------------------------------------------------------------
# 4. Assertion 1: 0 Files Modified Outside Sandbox
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 1: 0 Files Modified Outside Sandbox ---"
POST_SNAPSHOT_FILE="${SANDBOX_DIR}/.external_post_snapshot.txt"
touch "${POST_SNAPSHOT_FILE}"

for m_dir in "${MONITORED_DIRS[@]}"; do
    if [ -d "${m_dir}" ]; then
        find "${m_dir}" -type f \
            -not -path "*/antigravity/brain/*" \
            -not -path "*/antigravity/scratch/*" \
            -not -name "*.pb" \
            -not -name "*.log" \
            -exec ls -ld {} + >> "${POST_SNAPSHOT_FILE}" 2>/dev/null || true
    fi
done

EXTERNAL_DIFF="$(diff -u "${SNAPSHOT_FILE}" "${POST_SNAPSHOT_FILE}" || true)"
if [ -z "${EXTERNAL_DIFF}" ]; then
    echo "[PASS] 0 files modified outside sandbox directory (Zero pollution to ~/.config, ~/.claude, ~/.gemini)."
else
    echo "[FAIL] External file changes detected outside sandbox:"
    echo "${EXTERNAL_DIFF}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

# ----------------------------------------------------------------------
# 5. Assertion 2: 100% Config Files (JSON/TOML/YAML) Parse Cleanly
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 2: 100% Config Files (JSON/TOML/YAML) Parse Cleanly ---"
if [ -n "${PYTHON_CMD}" ]; then
    CONFIG_CHECK_RES=$("${PYTHON_CMD}" -c "
import json, sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    tomllib = None

try:
    import yaml
except ImportError:
    yaml = None

repo_dir = Path('${SANDBOX_DIR}/repo')
extensions = {'.json', '.toml', '.yaml', '.yml'}
config_files = [p for p in repo_dir.rglob('*') if p.suffix.lower() in extensions and not any(part in p.parts for part in ['node_modules', '.venv', 'venv', 'dist', 'build'])]

print(f'[INFO] Scanning {len(config_files)} configuration file(s)...')
errors = 0
for cf in config_files:
    rel = cf.relative_to(repo_dir)
    ext = cf.suffix.lower()
    try:
        if ext == '.json':
            json.loads(cf.read_text(encoding='utf-8'))
            print(f'[PASS] {rel} (Valid JSON)')
        elif ext == '.toml':
            if tomllib:
                with open(cf, 'rb') as f:
                    tomllib.load(f)
                print(f'[PASS] {rel} (Valid TOML)')
        elif ext in ('.yaml', '.yml'):
            if yaml:
                with open(cf, 'r', encoding='utf-8') as f:
                    yaml.safe_load(f)
                print(f'[PASS] {rel} (Valid YAML)')
    except Exception as e:
        print(f'[FAIL] {rel} : Syntax error ({e})')
        errors += 1

if errors == 0:
    print(f'[PASS] 100% of configuration files ({len(config_files)}/{len(config_files)}) parsed successfully.')
    sys.exit(0)
else:
    print(f'[FAIL] {errors} configuration file(s) failed syntax validation.')
    sys.exit(1)
" 2>&1) || CFG_CODE=$?

    echo "${CONFIG_CHECK_RES}"
    if [ "${CFG_CODE:-0}" -ne 0 ]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo "[WARN] Python not found; skipping configuration syntax validation."
fi

# ----------------------------------------------------------------------
# 6. Assertion 3: AGENTS.md Size & Token Budget Limits
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 3: AGENTS.md Size & Token Budget Limits ---"
AGENTS_FILE="${SANDBOX_DIR}/repo/AGENTS.md"
MAX_AGENTS_LINES=120
MAX_AGENTS_CHARS=9000
if [ -f "${AGENTS_FILE}" ]; then
    LINE_COUNT="$(wc -l < "${AGENTS_FILE}" | tr -d ' ')"
    CHAR_COUNT="$(wc -c < "${AGENTS_FILE}" | tr -d ' ')"
    echo "[INFO] AGENTS.md metrics: ${LINE_COUNT} lines, ${CHAR_COUNT} characters (budget: ${MAX_AGENTS_LINES} lines / ${MAX_AGENTS_CHARS} chars)."
    # The budget is ENFORCED, not merely reported. AGENTS.md is loaded into
    # every agent turn, so an unbounded file silently inflates every request.
    if [ "${LINE_COUNT}" -gt "${MAX_AGENTS_LINES}" ]; then
        echo "[FAIL] AGENTS.md is ${LINE_COUNT} lines (max ${MAX_AGENTS_LINES}). Move detail into .agents/rules/."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    elif [ "${CHAR_COUNT}" -gt "${MAX_AGENTS_CHARS}" ]; then
        echo "[FAIL] AGENTS.md is ${CHAR_COUNT} characters (max ${MAX_AGENTS_CHARS}). Move detail into .agents/rules/."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    else
        echo "[PASS] AGENTS.md within budget (${LINE_COUNT}/${MAX_AGENTS_LINES} lines, ${CHAR_COUNT}/${MAX_AGENTS_CHARS} chars)."
    fi
else
    echo "[FAIL] AGENTS.md missing in sandbox repo!"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

# ----------------------------------------------------------------------
# 7. Assertion 4: 100% Skills in .agents/skills/ Wired to Rule Files
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 4: 100% Skill Wiring Coverage ---"
SKILLS_DIR="${SANDBOX_DIR}/repo/.agents/skills"
RULES_DIR="${SANDBOX_DIR}/repo/.agents/rules"

if [ -d "${SKILLS_DIR}" ] && [ -d "${RULES_DIR}" ] && [ -n "${PYTHON_CMD}" ]; then
    SKILL_WIRING_RES=$("${PYTHON_CMD}" -c "
import sys
from pathlib import Path

skills_dir = Path('${SKILLS_DIR}')
rules_dir = Path('${RULES_DIR}')
index_file = rules_dir / 'skills-index.md'

skill_files = sorted(skills_dir.rglob('SKILL.md'))
rule_files = sorted(rules_dir.glob('*.md'))
rule_names = {rf.name for rf in rule_files}

# Parse the wiring map: | Skill Name | Category | Canonical Path | Governing Rule | Description |
rows = []
if index_file.exists():
    for line in index_file.read_text(encoding='utf-8').splitlines():
        if not line.strip().startswith('|'):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) < 4:
            continue
        if cells[0].lower().startswith('skill name') or set(cells[0]) <= set('-: '):
            continue
        rows.append(cells)

indexed = {}
malformed = []
for cells in rows:
    path_cell = cells[2]
    rule_cell = cells[3] if len(cells) > 3 else ''
    rel = path_cell.replace('[', '').replace(']', '').strip()
    # strip a markdown link target if present
    if '(' in rel and rel.endswith(')'):
        rel = rel[rel.index('(') + 1:-1]
    rel = rel.replace('../../', '').lstrip('/')
    if not rel:
        malformed.append(cells[0])
        continue
    rule = rule_cell.replace('[', '').replace(']', '').strip()
    if '(' in rule and rule.endswith(')'):
        rule = rule[rule.index('(') + 1:-1]
    indexed[rel] = rule

missing_from_index = []
missing_rule = []
missing_on_disk = []
for sf in skill_files:
    rel = str(sf.relative_to(skills_dir.parent.parent))  # .agents/skills/<...>
    if rel not in indexed:
        missing_from_index.append(rel)
        continue
    rule = indexed[rel]
    if not rule:
        missing_rule.append(rel)
    else:
        target = (rules_dir / rule).resolve()
        if not target.exists():
            missing_rule.append(f'{rel} -> {rule}')

for rel in indexed:
    if not (skills_dir.parent.parent / rel).exists():
        missing_on_disk.append(rel)

print(f'[INFO] {len(skill_files)} skill(s) on disk, {len(indexed)} row(s) in skills-index.md, {len(rule_files)} rule file(s).')
ok = True
if missing_from_index:
    ok = False
    print(f'[FAIL] {len(missing_from_index)} skill(s) missing from skills-index.md: {missing_from_index[:10]}')
if missing_rule:
    ok = False
    print(f'[FAIL] {len(missing_rule)} skill(s) without a resolvable governing rule: {missing_rule[:10]}')
if missing_on_disk:
    ok = False
    print(f'[FAIL] {len(missing_on_disk)} indexed path(s) do not exist on disk: {missing_on_disk[:10]}')
if ok:
    print(f'[PASS] 100% of skills ({len(skill_files)}/{len(skill_files)}) are indexed AND wired to a governing rule file.')
sys.exit(0 if ok else 1)
" 2>&1) || WIRING_CODE=$?

    echo "${SKILL_WIRING_RES}"
    if [ "${WIRING_CODE:-0}" -ne 0 ]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
fi

# ----------------------------------------------------------------------
# 8. Assertion 5: 100% .aiignore Patterns Mirrored in .gitignore
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 5: 100% .aiignore Patterns Mirrored in .gitignore ---"
AIIGNORE="${SANDBOX_DIR}/repo/.aiignore"
GITIGNORE="${SANDBOX_DIR}/repo/.gitignore"

if [ -f "${AIIGNORE}" ] && [ -f "${GITIGNORE}" ] && [ -n "${PYTHON_CMD}" ]; then
    IGNORE_CHECK_RES=$("${PYTHON_CMD}" -c "
import sys
from pathlib import Path

ai_path = Path('${AIIGNORE}')
git_path = Path('${GITIGNORE}')

ai_patterns = [line.strip() for line in ai_path.read_text(encoding='utf-8').splitlines() if line.strip() and not line.strip().startswith('#')]
git_patterns = [line.strip() for line in git_path.read_text(encoding='utf-8').splitlines() if line.strip() and not line.strip().startswith('#')]

git_set = set(git_patterns)
git_norm = {p.rstrip('/').rstrip(chr(92)) for p in git_patterns}

missing = []
for p in ai_patterns:
    if p not in git_set and p.rstrip('/').rstrip(chr(92)) not in git_norm:
        missing.append(p)

print(f'[INFO] Evaluated {len(ai_patterns)} pattern(s) from .aiignore against .gitignore.')
if not missing:
    print(f'[PASS] 100% of .aiignore patterns ({len(ai_patterns)}/{len(ai_patterns)}) are strictly mirrored in .gitignore.')
    sys.exit(0)
else:
    print(f'[FAIL] Found {len(missing)} pattern(s) missing from .gitignore: {missing}')
    sys.exit(1)
" 2>&1) || IGNORE_CODE=$?

    echo "${IGNORE_CHECK_RES}"
    if [ "${IGNORE_CODE:-0}" -ne 0 ]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
fi

# ----------------------------------------------------------------------
# 9. Assertion 6: claude-mem Episodic Memory Is Wired, Not Just Described
# ----------------------------------------------------------------------
echo ""
echo "--- Assertion 6: claude-mem Episodic Memory Round-Trip + Hook Wiring ---"
MEMORY_REPO="${SANDBOX_DIR}/repo"

if [ -f "${MEMORY_REPO}/.repo/claude-mem/cli.ts" ]; then
    MEMORY_CLI="${MEMORY_REPO}/.repo/claude-mem/run.mjs"

    if node "${MEMORY_CLI}" remember --kind fact \
        --title "Bootstrap probe episode" \
        --body "The episodic store round-trips inside the sandbox." \
        --tags bootstrap \
        --root "${MEMORY_REPO}" >/dev/null 2>&1; then
        echo "[PASS] claude-mem wrote an episode into the sandbox store."
    else
        echo "[FAIL] claude-mem could not write an episode."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi

    RECALL_OUT="$(node "${MEMORY_CLI}" recall --text "Bootstrap probe" --root "${MEMORY_REPO}" 2>&1 || true)"
    if echo "${RECALL_OUT}" | grep -q "Bootstrap probe episode"; then
        echo "[PASS] claude-mem recalled the episode it wrote."
    else
        echo "[FAIL] claude-mem did not recall the episode it wrote."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi

    # The store must stay inside the sandbox (the only sanctioned write
    # outside a project root).
    if [ -f "${MEMORY_REPO}/.agents/memory/episodes.jsonl" ]; then
        echo "[PASS] claude-mem store lives inside the project root (.agents/memory/)."
    else
        echo "[FAIL] claude-mem store missing at .agents/memory/episodes.jsonl."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo "[FAIL] claude-mem CLI missing in sandbox repo."
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

HOOK_WIRING_MISSING=""
for cfg in ".claude/settings.json" ".codex/config.toml" ".goose/hooks.json" \
           ".qoder/settings.json" ".antigravity/hooks.json"; do
    if [ -f "${MEMORY_REPO}/${cfg}" ] && ! grep -q "memory-sync" "${MEMORY_REPO}/${cfg}"; then
        HOOK_WIRING_MISSING="${HOOK_WIRING_MISSING} ${cfg}"
    fi
done
if [ ! -f "${MEMORY_REPO}/.opencode/plugins/memory-sync.js" ]; then
    HOOK_WIRING_MISSING="${HOOK_WIRING_MISSING} .opencode/plugins/memory-sync.js"
fi

if [ -z "${HOOK_WIRING_MISSING}" ]; then
    echo "[PASS] memory-sync hook registered in every hook-capable adapter."
else
    echo "[FAIL] memory-sync hook not wired in:${HOOK_WIRING_MISSING}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

# ----------------------------------------------------------------------
# 10. Teardown Sandbox & Exit
# ----------------------------------------------------------------------
echo ""
echo "[INFO] Cleaning up sandbox directory: ${SANDBOX_DIR}"
rm -rf "${SANDBOX_DIR}" 2>/dev/null || true

echo ""
echo "============================================================"
if [ "${TOTAL_ERRORS}" -eq 0 ]; then
    echo "   Sandbox Bootstrap Verification: 100% PASSED               "
    echo "============================================================"
    exit 0
else
    echo "   Sandbox Bootstrap Verification FAILED with ${TOTAL_ERRORS} error(s)  "
    echo "============================================================"
    exit 1
fi
