#!/usr/bin/env sh
# ==============================================================================
# File Line Limit Verifier (POSIX)
# ==============================================================================
# Enforces the 400-line ceiling documented in .agents/rules/code-quality.md
# ("excluding blank lines and comments") and mirrored by .eslintrc.json
# ("max-lines": skipBlankLines + skipComments).
#
# This twin and verify-file-limits.ps1 MUST agree. They previously did not:
#   - the PowerShell twin never scanned .sh files,
#   - the POSIX twin counted raw physical lines (wc -l),
#   - the PowerShell twin counted non-blank lines (Measure-Object -Line),
# so the same file could pass on Windows and fail on Linux.
# ==============================================================================

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
MAX_LINES=400

if [ -n "${1:-}" ]; then
    ROOT_DIR="$(cd "$1" && pwd -P)"
fi

# Extensions scanned (identical list in both twins).
#
# The excluded directories are PRUNED, not merely filtered with `-not -path`.
# `-not -path` only suppresses the *output*; `find` still walks every file
# inside node_modules and the project-local .cache/ tree, which holds the
# uv and npm package caches (hundreds of thousands of files). That made this
# suite take minutes instead of seconds.
find_files() {
    find "$ROOT_DIR" \
        \( -type d \( -name "node_modules" -o -name ".cache" -o -name ".git" \
           -o -name "__pycache__" -o -name ".specify" -o -name "skills" \
           -o -name "dist" -o -name "build" -o -name ".venv" -o -name "venv" \
           -o -name "env" -o -name "ENV" -o -name ".pytest_cache" \
           -o -name "sandbox" -o -name ".sandbox" \) -prune \) \
        -o \( -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
           -o -name "*.mjs" -o -name "*.cjs" -o -name "*.py" -o -name "*.ps1" -o -name "*.sh" \) \
           -print0 \) \
        2>/dev/null
}

# Count "effective" lines: non-blank and not a comment-only line.
# Mirrors ESLint's max-lines behaviour with skipBlankLines + skipComments.
count_effective_lines() {
    awk '
    {
        line = $0
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line == "") next
        if (line ~ /^#/) next
        if (line ~ /^\/\//) next
        if (line ~ /^\/\*/) next
        if (line ~ /^\*/) next
        count++
    }
    END { print count + 0 }
    ' "$1"
}

# NOTE: the previous revision wrote its violation list to `mktemp`, i.e. into
# the system temp directory — the only write this repository performed outside
# the project folder during a verification run. The list is now held in a
# shell variable so the run touches nothing outside the project.
VIOLATIONS="$(find_files | while IFS= read -r -d '' file; do
    LINES=$(count_effective_lines "$file")
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        printf '%s|%s\n' "${file#${ROOT_DIR}/}" "$LINES"
    fi
done)"

SCANNED=$(find_files | tr -cd '\0' | wc -c | tr -d ' ')

if [ -n "$VIOLATIONS" ]; then
    printf '%s\n' "$VIOLATIONS" | while IFS='|' read -r path lines; do
        [ -n "$path" ] && echo "[FAIL] $path ($lines effective lines > $MAX_LINES)"
    done
    echo "Files scanned: $SCANNED"
    echo "[FAIL] File line limit verification failed."
    exit 1
fi

echo "Files scanned: $SCANNED"
echo "[PASS] All source files strictly comply with the $MAX_LINES lines limit!"
exit 0
