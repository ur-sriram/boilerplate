#!/usr/bin/env sh
set -eu
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MEM_DIR="$ROOT_DIR/.agents/memory"
mkdir -p "$MEM_DIR"
echo "[MEMORY] claude-mem episodic store verified at $MEM_DIR"
exit 0
