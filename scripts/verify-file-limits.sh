#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAX_LINES=400
VIOLATIONS=0
SCANNED=0

for file in $(find "$ROOT_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.ps1" -o -name "*.sh" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.specify/*" -not -path "*/skills/*" -not -path "*/__pycache__/*"); do
    SCANNED=$((SCANNED + 1))
    LINES=$(wc -l < "$file")
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        echo "[FAIL] $file ($LINES lines > $MAX_LINES)"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

echo "Files scanned: $SCANNED"
if [ "$VIOLATIONS" -gt 0 ]; then
    exit 1
fi
echo "[PASS] All source files strictly comply with the $MAX_LINES lines limit!"
exit 0
