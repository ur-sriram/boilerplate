#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_ONLY=0
if [ "${1:-}" = "--verify-only" ]; then
    VERIFY_ONLY=1
fi

ERRORS=0
for rel in ".claude/skills" ".cursor/skills" ".windsurf/skills" ".cline/skills" ".codex/skills" ".qoder/skills"; do
    TARGET="$ROOT_DIR/$rel"
    PARENT="$(dirname "$TARGET")"
    if [ "$VERIFY_ONLY" -eq 0 ]; then
        mkdir -p "$PARENT"
    fi
    if [ -L "$TARGET" ]; then
        echo "[PASS] Symlink verified: $rel"
    elif [ -d "$TARGET" ]; then
        if [ "$VERIFY_ONLY" -eq 1 ]; then
            echo "[FAIL] $rel is a plain directory, not a symlink."
            ERRORS=$((ERRORS + 1))
        else
            rmdir "$TARGET" 2>/dev/null && ln -sfn "../../.agents/skills" "$TARGET" || true
        fi
    else
        if [ "$VERIFY_ONLY" -eq 1 ]; then
            echo "[FAIL] Missing symlink: $rel"
            ERRORS=$((ERRORS + 1))
        else
            ln -sfn "../.agents/skills" "$TARGET"
        fi
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
echo "[PASS] All universal agent adapters verified!"
exit 0
