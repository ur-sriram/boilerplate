# Core Invariants & Operational Boundaries

> **Layer 2 Modular Rule** | Scope: All tasks and agents | Enforced across entire repository

This document defines the absolute, non-negotiable operational invariants governing all agent interactions in this repository. Every agent—regardless of vendor or architecture—must comply with these boundaries.

---

## 1. Strict Project Scoping & Zero Global Pollution

1. **Working Directory Lockdown**: All reads, writes, and modifications must strictly target paths within the project root (the directory that contains this rule file).
2. **Global Paths Forbidden**: Modifying, creating, or inspecting files outside the project boundary is strictly prohibited:
   - Prohibited paths: `%USERPROFILE%`, `%APPDATA%`, `~/.config`, `~/.gemini`, `~/.claude`, `/etc`, or global package registries (`%APPDATA%\npm`, `~/.cargo/bin`).
   - Any agent configuration workarounds required by third-party tooling must be recorded in [THIRD_PARTY.md](../../THIRD_PARTY.md) as a named exception.
3. **Automated Guardrail Enforcement**: Tool calls attempting to access paths outside the project root are intercepted and blocked by the PreToolUse hook, which aborts with exit code 1. The hook is invoked through the cross-platform dispatcher `scripts/hooks/run-hook.mjs` (Claude Code, Codex, Qoder, Goose), through `.antigravity/hooks.json` (Antigravity), or through the OpenCode `config-protection.js` plugin. Runtimes without a hook API (Cursor, Cline, Windsurf, Copilot, Kimi, Junie) rely on this rule at the prompt level — do not assume the block is enforced there.

---

## 2. Secret Hygiene & Environment Discipline

1. **Zero Secrets in Repository**: API keys, tokens, credentials, and private connection strings must NEVER be committed to Git or written to persistent files in the workspace.
2. **Environment Variable Storage**: Use `.env` for local sensitive values.
3. **Mirroring Guardrail**: `.gitignore` strictly mirrors `.aiignore`. The `.env` file and all sensitive artifacts are ignored by both version control and AI context indexing.
4. **Template Reference**: All required variables must be documented with dummy values in [`.env.example`](../../.env.example).

---

## 3. Episodic Memory & Cross-Session Recall

1. **Observations Persist**: A settled decision, a discovery, a change or a
   recovered error is written to the episodic store in `.agents/memory/` with
   the `/remember` command, using the upstream `claude-mem` observation types
   and concepts, so the next session starts with them. The store is
   machine-local and git-ignored — it never becomes repository content.
2. **Recall Before Asking**: Search the store with `/recall` before asking the
   user a question the project may already have answered, and never invent
   history: if nothing matched, say so.
3. **Automatic Recall**: The `memory-sync` hook surfaces the most recent
   episodes at session start for every adapter that has a hook API. Runtimes
   without one (Cursor, Cline, Windsurf, Copilot, Kimi, Junie) rely on this
   rule at the prompt level and on `/recall` for on-demand search.
4. **No Secrets in Memory**: Credentials are scrubbed at write time, and the
   store is scoped strictly inside the project root.

---

## 4. Worktree & Context Isolation

1. **Isolated Worktrees**: When performing exploratory spikes, complex refactoring, or multi-step feature implementations, use isolated Git worktrees via the [`using-git-worktrees`](../skills/superpowers/using-git-worktrees/SKILL.md) skill.
2. **Context Purity**: Never pollute the primary working tree with unverified intermediate builds or broken experiments.
3. **Lifecycle Cleanup**: Once a worktree task is complete and verified, integrate or prune it cleanly using [`finishing-a-development-branch`](../skills/superpowers/finishing-a-development-branch/SKILL.md).

---

## 5. Karpathy Surgical Execution

1. **Think Before Coding**: State assumptions explicitly. Surface tradeoffs upfront. Ask clarifying questions before writing code when requirements are ambiguous.
2. **Simplicity First**: Write the minimum amount of code that solves the user's problem. Avoid speculative abstractions, unnecessary flexibility, or dead-weight boilerplate.
3. **Surgical Edits**:
   - Touch only the lines strictly necessary to fulfill the request.
   - Do not "clean up" adjacent code, reformat surrounding blocks, or rewrite comments you did not introduce.
   - Remove unused imports, variables, or functions created by your changes, but leave pre-existing code alone.
4. **Goal-Driven Verification**: Define explicit, programmatic success criteria before editing and iterate until verified.

---

## 6. Related Standards & Skills

- [Planning Standards](planning-standards.md): Spec-Kit SDD and Superpowers plan workflows.
- [Code Quality](code-quality.md): TDD cycles, systematic debugging, and code review.
- [Automation & Hooks](automation.md): Executable guardrails and verification suite.
- [Skills Index](skills-index.md): Complete wiring map for all integrated skills.
- Integrated Skills:
  - [`using-superpowers`](../skills/superpowers/using-superpowers/SKILL.md)
  - [`using-git-worktrees`](../skills/superpowers/using-git-worktrees/SKILL.md)
  - [`finishing-a-development-branch`](../skills/superpowers/finishing-a-development-branch/SKILL.md)
