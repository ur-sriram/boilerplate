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
# NOTE: the -not -path patterns MUST stay quoted, otherwise the shell expands
# them against the working directory and find() silently scans nothing.
find_files() {
    find "$ROOT_DIR" -type f \
        \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
           -o -name "*.mjs" -o -name "*.cjs" -o -name "*.py" -o -name "*.ps1" -o -name "*.sh" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/.specify/*" \
        -not -path "*/skills/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -print0 2>/dev/null
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

VIOLATION_LIST="$(mktemp)"
trap 'rm -f "$VIOLATION_LIST"' EXIT

SCANNED=0
find_files | while IFS= read -r -d '' file; do
    SCANNED=$((SCANNED + 1))
    LINES=$(count_effective_lines "$file")
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        printf '%s|%s\n' "${file#${ROOT_DIR}/}" "$LINES" >> "$VIOLATION_LIST"
    fi
done

SCANNED=$(find_files | tr -cd '\0' | wc -c | tr -d ' ')

if [ -s "$VIOLATION_LIST" ]; then
    while IFS='|' read -r path lines; do
        [ -n "$path" ] && echo "[FAIL] $path ($lines effective lines > $MAX_LINES)"
    done < "$VIOLATION_LIST"
    echo "Files scanned: $SCANNED"
    echo "[FAIL] File line limit verification failed."
    exit 1
fi

echo "Files scanned: $SCANNED"
echo "[PASS] All source files strictly comply with the $MAX_LINES lines limit!"
exit 0
