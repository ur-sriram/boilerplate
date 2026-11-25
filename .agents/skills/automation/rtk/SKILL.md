---
name: rtk
description: Rust Token Killer (rtk) integration for compressing verbose terminal command outputs and preserving context window headroom.
---

# RTK (Rust Token Killer)

`rtk` compresses verbose CLI outputs (e.g., test runners, git diffs, package managers) via `scripts/hooks/rtk-filter.ps1` and `scripts/hooks/rtk-filter.sh`.

## Usage
- Wired automatically as a `PostToolUse` hook in `.antigravity/hooks.json` and `.opencode/plugins/rtk-interceptor.js`.
- Gracefully passes through raw output if `rtk` binary is not installed in `PATH`.
