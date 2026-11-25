#!/usr/bin/env sh
# PostToolUse Output Compressor Hook for POSIX environments (Linux / macOS).
# Filters terminal stdout via `rtk` if available, echoing raw input if absent.

if [ ! -t 0 ]; then
    INPUT_CONTENT=$(cat)
else
    INPUT_CONTENT="$1"
fi

if [ -z "$INPUT_CONTENT" ]; then
    exit 0
fi

if command -v rtk >/dev/null 2>&1; then
    FILTERED=$(printf '%s\n' "$INPUT_CONTENT" | rtk filter 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$FILTERED" ]; then
        printf '%s\n' "$FILTERED"
        exit 0
    fi
fi

# Fallback: emit raw input unmodified
printf '%s\n' "$INPUT_CONTENT"
exit 0
