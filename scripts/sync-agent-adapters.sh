#!/usr/bin/env sh
# Creates and verifies the universal agent skill junctions.
#
# Every junction lives one level below the repo root (.claude/skills, ...), so
# the relative target is ALWAYS "../.agents/skills". The previous revision used
# "../../.agents/skills" on the repair path, which resolved to the PARENT of
# the repository and produced a dangling link that the verifier still reported
# as PASS (it only checked that a symlink existed, never that it resolved).
#
# Usage: ./sync-agent-adapters.sh [--verify-only]

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
VERIFY_ONLY=0
if [ "${1:-}" = "--verify-only" ]; then
    VERIFY_ONLY=1
fi

CANONICAL="$ROOT_DIR/.agents/skills"
REL_TARGET="../.agents/skills"
ERRORS=0

LINKS=".claude/skills .cursor/skills .windsurf/skills .cline/skills .codex/skills .qoder/skills"

for rel in $LINKS; do
    TARGET="$ROOT_DIR/$rel"
    PARENT="$(dirname "$TARGET")"

    if [ "$VERIFY_ONLY" -eq 0 ]; then
        mkdir -p "$PARENT"
    fi

    if [ -L "$TARGET" ]; then
        # Link exists: it must actually resolve into the canonical store.
        RESOLVED="$(readlink -f "$TARGET" 2>/dev/null || echo "")"
        CANONICAL_RESOLVED="$(readlink -f "$CANONICAL" 2>/dev/null || echo "$CANONICAL")"
        if [ -z "$RESOLVED" ] || [ "$RESOLVED" != "$CANONICAL_RESOLVED" ]; then
            if [ "$VERIFY_ONLY" -eq 1 ]; then
                echo "[FAIL] $rel does not resolve into .agents/skills (got: ${RESOLVED:-<unresolved>})"
                ERRORS=$((ERRORS + 1))
            else
                rm -f "$TARGET"
                ln -sfn "$REL_TARGET" "$TARGET"
                echo "[FIXED] $rel -> $REL_TARGET"
            fi
        else
            echo "[PASS] Symlink verified and resolves: $rel"
        fi
    elif [ -d "$TARGET" ]; then
        if [ "$VERIFY_ONLY" -eq 1 ]; then
            echo "[FAIL] $rel is a plain directory, not a symlink."
            ERRORS=$((ERRORS + 1))
        elif [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then
            rmdir "$TARGET" 2>/dev/null || true
            ln -sfn "$REL_TARGET" "$TARGET"
            echo "[FIXED] $rel -> $REL_TARGET (replaced empty directory)"
        else
            echo "[WARN] $rel is a non-empty directory; skipping."
        fi
    else
        if [ "$VERIFY_ONLY" -eq 1 ]; then
            echo "[FAIL] Missing symlink: $rel"
            ERRORS=$((ERRORS + 1))
        else
            ln -sfn "$REL_TARGET" "$TARGET"
            echo "[CREATED] $rel -> $REL_TARGET"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Slash command distribution
# ---------------------------------------------------------------------------
# .agents/commands/ is the CANONICAL source for the 8 slash commands.
# They are distributed to every adapter that supports a project-level command
# directory, so `/plan`, `/review`, `/test`, ... resolve the same way
# everywhere instead of only in Claude Code and OpenCode.
#
# Adapter command directories (verified against vendor documentation):
#   .claude/commands/*.md          Claude Code
#   .cursor/commands/*.md          Cursor
#   .github/prompts/*.prompt.md    GitHub Copilot (IDE; needs chat.promptFiles)
#   .qoder/commands/*.md           Qoder
#   .kimi/commands/*.md            Kimi Code CLI
#   .goose/commands/*.md           Goose CLI
#   .antigravity/commands/*.md     Antigravity
#   .junie/commands/*.md           JetBrains Junie
#   .cline/commands/*.md           Cline / Roo Code
#   .windsurf/commands/*.md        Windsurf
# OpenCode keeps its richer .toml command files in .opencode/commands/.

CANONICAL_COMMANDS="${ROOT_DIR}/.agents/commands"
if [ -d "${CANONICAL_COMMANDS}" ]; then
    for cmd_file in "${CANONICAL_COMMANDS}"/*.md; do
        [ -e "$cmd_file" ] || continue
        cmd_name="$(basename "$cmd_file" .md)"
        cmd_body="$(cat "$cmd_file")"

        for dest in .claude/commands .cursor/commands .qoder/commands .kimi/commands \
                    .goose/commands .antigravity/commands .junie/commands \
                    .cline/commands .windsurf/commands .codex/prompts; do
            target_dir="${ROOT_DIR}/${dest}"
            [ "$VERIFY_ONLY" -eq 0 ] && mkdir -p "$target_dir"
            printf '%s\n' "$cmd_body" > "${target_dir}/${cmd_name}.md"
        done

        # GitHub Copilot prompt files must use the .prompt.md extension.
        copilot_dir="${ROOT_DIR}/.github/prompts"
        [ "$VERIFY_ONLY" -eq 0 ] && mkdir -p "$copilot_dir"
        printf '%s\n' "$cmd_body" > "${copilot_dir}/${cmd_name}.prompt.md"
    done
fi

# Required adapter entry-point files must exist for every supported agent.
REQUIRED_FILES="AGENTS.md CLAUDE.md .cursor/rules/core.mdc .cursor/mcp.json
.claude/settings.json .windsurfrules .github/copilot-instructions.md
.clinerules .antigravity/settings.json opencode.json
.codex/config.toml .qoder/settings.json .goosehints
.goose/config.yaml .kimi/config.toml .junie/playbook.md
.kimi-code/mcp.json .agents/commands/plan.md .agents/commands/review.md
.cursor/commands/plan.md .github/prompts/plan.prompt.md"

for rf in $REQUIRED_FILES; do
    if [ ! -e "$ROOT_DIR/$rf" ]; then
        echo "[FAIL] Missing required adapter file: $rf"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo "[FAIL] Adapter verification failed with $ERRORS error(s)."
    exit 1
fi

echo "[PASS] All universal agent adapters and 6 skill junctions verified!"
exit 0
