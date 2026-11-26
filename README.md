# Production-Ready Multi-Agent Unified Boilerplate

A battle-tested, project-level starter template for autonomous coding agents. Zero global configuration required — all skills, rules, hooks, plugins, and MCP servers reside strictly within the project boundary.

---

## 1. Project Overview & Architecture

Modern AI coding agents (OpenCode, Antigravity, Codex, Qoder, Goose, Kimi, Junie, Freebuff) often require scattered global configuration in `~/.config`, `%APPDATA%`, or `~/.claude`. This boilerplate eliminates manual setup and configuration drift by providing a self-contained, project-scoped architecture:

- **Layer 1: Always-On Core (`AGENTS.md`)**: Comprehensive root index containing project invariants, Karpathy minimal-change guidelines, 4-step UI/UX pipeline, Cloudflare CodeMode MCP rules, and pointers to all rules and agent adapters.
- **Layer 2: On-Demand Rules (`.agents/rules/*.md`)**: Modular rules loaded conditionally via glob pattern triggers or agent routing for planning, code quality, UI standards, exploration, and automation.
- **Layer 3: Single Canonical Skill Store (`.agents/skills/`)**: **377 skills** (Superpowers, Impeccable, Anti-Slop, Unslop, Motion, Agency personas, …), every one mapped to a governing rule in [.agents/rules/skills-index.md](.agents/rules/skills-index.md). Agents reach them natively (`.agents/skills/`) or through zero-elevation NTFS junctions (`mklink /J`) / POSIX symlinks — `scripts/sync-agent-adapters.sh` creates and verifies all six.
- **Dynamic MCP Profiles**: Switch between `core` (default, ~350 tokens), `ui` (~750 tokens), `compression` (~650 tokens), or `all` profiles via `scripts/mcp-profile.sh` / `.ps1`. One Python implementation updates **all nine** adapter MCP configs, so they can never drift apart.
- **Executable Lifecycle Hooks (`scripts/hooks/`)**: Config protection, `rtk` terminal-output compression and session validation. `scripts/hooks/run-hook.mjs` is a cross-platform Node dispatcher, so the same command string works on Windows, macOS and Linux.
- **Spec-Driven Development (`.specify/`)**: Vendored GitHub Spec Kit v1.4.3 with **both** script families (PowerShell + POSIX bash), templates, constitution and the "Full SDD Cycle" workflow. See [.specify/README.md](.specify/README.md).
- **Self-Verification Suite (`scripts/`)**: Nine programmatic suites validating tool availability, script syntax, file-size limits, link integrity, adapter parity, skill-wiring coverage and vendored-file integrity.

---

## 2. Adoption & Import Methods

Choose one of two quick-start methods to adopt this boilerplate for a new project:

### Method A: Use as GitHub Template (Recommended)
```bash
# 1. Create a new repository from this template
gh repo create my-awesome-project --template sriram/boilerplate --clone
cd my-awesome-project

# 2. Run one-time local initialization (zero global modifications)
# Windows (Command Prompt):
bootstrap.cmd

# Windows (PowerShell with execution policy bypass):
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/bootstrap.ps1

# Linux / macOS (Bash):
./scripts/bootstrap.sh
```

### Method B: Clone & Initialize Directly
```bash
# 1. Clone repository
git clone https://github.com/sriram/boilerplate.git my-awesome-project
cd my-awesome-project

# 2. Run local bootstrap wrapper
# Windows:
bootstrap.cmd
# POSIX:
./scripts/bootstrap.sh
```

---

## 3. Copy-Paste Agent Bootstrap Prompt

When dispatching any AI coding agent to work in this repository, paste the following prompt into its initial context window:

```text
You are an AI coding agent adopting this repository. This project is configured with a zero-config, project-level agentic boilerplate. Follow these initialization instructions strictly:

1. READ PROJECT INVARIANTS FIRST:
   Open and inspect `AGENTS.md` at project root. It contains the non-negotiable architectural rules, the Karpathy minimal-change guidelines, and pointers to domain rules. Stay strictly within its <= 1,000 token budget.

2. RUN ENVIRONMENT VERIFICATION:
   Execute the verification suite to ensure your runtime environment is clean and all configurations resolve:
   - Windows Command Prompt: verify-all.cmd
   - Windows PowerShell: powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify-all.ps1
   - Linux/macOS Bash: ./scripts/verify-all.sh
   The suite must report ALL 9 SUITES PASSED before you start work.

3. DISCOVER YOUR AGENT CONFIGURATION:
   Identify your agent runtime and review your specific setup guide in `docs/agents/`:
   - Claude Code: docs/agents/claude.md (reads CLAUDE.md, .claude/settings.json, .mcp.json)
   - OpenCode: docs/agents/opencode.md (reads opencode.json & .opencode/plugins/)
   - Cursor: docs/agents/cursor.md (reads .cursor/rules/core.mdc, .cursor/mcp.json, .cursor/commands/)
   - Antigravity IDE / CLI: docs/agents/antigravity.md (reads .antigravity/ & .agents/)
   - Codex CLI: docs/agents/codex.md (reads .codex/config.toml, .codex/prompts/)
   - Qoder / Qoder CLI: docs/agents/qoder.md (reads .qoder/settings.json)
   - GitHub Copilot: docs/agents/copilot.md (reads .github/copilot-instructions.md, .github/prompts/)
   - Freebuff: docs/agents/freebuff.md (set CODEBUFF_TRUST_AGENT_DIRS=1; reads AGENTS.md)
   - Goose: docs/agents/goose.md (reads .goosehints & .goose/config.yaml)
   - Kimi Code CLI: docs/agents/kimi.md (reads .kimi/config.toml, .kimi-code/mcp.json)
   - JetBrains Junie: docs/agents/junie.md (reads .junie/playbook.md & AGENTS.md)
   - Cline / Roo Code: docs/agents/cline.md (reads .clinerules & AGENTS.md)
   - Windsurf: docs/agents/windsurf.md (reads .windsurfrules & AGENTS.md)

4. STRICT SCOPING MANDATE:
   NEVER write, edit, or create files outside this project directory (e.g. in $HOME, %USERPROFILE%, or global config directories). All rules, skills, MCP servers, and hooks are strictly project-scoped.

5. PROGRESSIVE DISCLOSURE & WORKFLOWS:
   - For architecture & specs: Run `/plan`. It scaffolds `specs/<NNN>-<slug>/` from the `.specify/` templates and fills them in. See .specify/README.md.
   - For implementation: Use Superpowers TDD (.agents/skills/superpowers/test-driven-development/SKILL.md).
   - For UI/UX: Follow Impeccable verbs and Anti-Slop gates (.agents/rules/ui-standards.md). Activate the UI MCP profile if needed via: ./scripts/mcp-profile.sh ui
   - For code review: Execute 2-stage review before completing tasks (.agents/rules/code-quality.md).
   - For skill discovery: match the task against .agents/rules/skills-index.md, then load the skill at its Canonical Path together with its Governing Rule.
```

---

## 4. Per-Agent Guide Index

Detailed setup guides, configuration files, and hook mappings for supported agents:

Every adapter below is covered by `scripts/verify-adapters.py`, which fails the
build if an agent loses its rules, MCP servers, hooks or slash commands.

| Agent Runtime | Primary Config File | Setup Guide | Hook Support | Skill Access | Slash Commands |
|---|---|---|---|---|---|
| **Claude Code** | `.claude/settings.json` + `.mcp.json` | [docs/agents/claude.md](docs/agents/claude.md) | `.claude/settings.json` (all 3 events) | Native + junction `.claude/skills` | `.claude/commands/` |
| **OpenCode** | `opencode.json` | [docs/agents/opencode.md](docs/agents/opencode.md) | Plugins (`.opencode/plugins/`) | Native (`.agents/skills/`) | `.opencode/commands/` |
| **Cursor** | `.cursor/rules/core.mdc` + `.cursor/mcp.json` | [docs/agents/cursor.md](docs/agents/cursor.md) | n/a (prompt-level rules) | Native + junction `.cursor/skills` | `.cursor/commands/` |
| **Antigravity IDE / CLI** | `.antigravity/settings.json` | [docs/agents/antigravity.md](docs/agents/antigravity.md) | `.antigravity/hooks.json` (all 3 + POSIX) | Native (`.agents/skills/`) | `.antigravity/commands/` |
| **Codex CLI** | `.codex/config.toml` | [docs/agents/codex.md](docs/agents/codex.md) | `config.toml` matcher groups | Native + junction `.codex/skills` | `.codex/prompts/` |
| **Qoder / Qoder CLI** | `.qoder/settings.json` | [docs/agents/qoder.md](docs/agents/qoder.md) | `.qoder/settings.json` (all 3 events) | Junction `.qoder/skills` | `.qoder/commands/` |
| **GitHub Copilot** | `.github/copilot-instructions.md` | [docs/agents/copilot.md](docs/agents/copilot.md) | n/a (IDE-scoped) | Native (`.agents/skills/`) | `.github/prompts/*.prompt.md` |
| **Freebuff** | `AGENTS.md` + `.agents/mcp.json` | [docs/agents/freebuff.md](docs/agents/freebuff.md) | Behavioral rules (`AGENTS.md`) | Native (`.agents/skills/`) | via `/plan` prompt |
| **Goose (Block)** | `.goosehints` + `.goose/config.yaml` | [docs/agents/goose.md](docs/agents/goose.md) | `.goose/hooks.json` (all 3 events) | Pointer (`.goosehints`) | `.goose/commands/` |
| **Kimi Code CLI** | `.kimi/config.toml` + `.kimi-code/mcp.json` | [docs/agents/kimi.md](docs/agents/kimi.md) | n/a (prompt-level rules) | Native (`.agents/skills/`) | `.kimi/commands/` |
| **JetBrains Junie** | `.junie/playbook.md` | [docs/agents/junie.md](docs/agents/junie.md) | Junie guidelines | Native (`.agents/skills/`) | `.junie/commands/` |
| **Cline / Roo Code** | `.clinerules` | [docs/agents/cline.md](docs/agents/cline.md) | n/a (prompt-level rules) | Junction `.cline/skills` | `.cline/commands/` |
| **Windsurf** | `.windsurfrules` | [docs/agents/windsurf.md](docs/agents/windsurf.md) | n/a (prompt-level rules) | Junction `.windsurf/skills` | `.windsurf/commands/` |

---

## 5. Verification & Health Check

Run the unified test runner to ensure 100% link integrity, script syntax, tool availability, and boundary enforcement:

```cmd
:: Windows 1-Click Batch Wrapper:
verify-all.cmd

:: Windows PowerShell (ExecutionPolicy Bypass):
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify-all.ps1

:: Linux / macOS:
./scripts/verify-all.sh
```

The verification suite executes 9 programmatic checks:
1. `scripts/verify-tools.{ps1,sh}`: Validates Git, Node, Python runtimes and MCP command resolvers.
2. `scripts/verify-scripts.{ps1,sh}`: Validates PowerShell AST syntax, Bash script syntax, Python compilation, and hook dry-runs.
3. `scripts/verify-file-limits.{ps1,sh}`: Enforces the 400-line cap on effective lines (blank lines and comment-only lines excluded), identically on both platforms.
4. `scripts/verify-links.py`: Code-block aware parser confirming all internal Markdown links and GitHub anchor slugs resolve.
5. `scripts/sync-agent-adapters.sh`: Creates and verifies the six skill junctions and distributes the slash commands.
6. `scripts/test-bootstrap.{ps1,sh}`: Runs an isolated sandbox clone asserting zero files are touched outside the sandbox, plus config parsing, skill-wiring coverage and ignore-file mirroring.
7. `scripts/generate-skills-index.py --check`: Proves the skill wiring map matches the store on disk.
8. `scripts/verify-adapters.py`: Proves every agent adapter keeps the same rules, MCP servers, hooks and commands.
9. `scripts/verify-specify-integrity.py`: Proves the vendored Spec Kit files match their recorded checksums.

Project-level checks that need Node.js:

```bash
npm install       # once
npm test          # node:test over src/features/**/*.test.ts
npm run lint      # ESLint 9 flat config
npm run typecheck # tsc --noEmit
```

---

## 6. Core Slash Commands & Workflows

All eight commands are distributed from the single canonical source
`.agents/commands/` to every adapter by `scripts/sync-agent-adapters.sh`.

| Command | Workflow Description | Primary Rule File |
|---|---|---|
| `/plan` | Scaffold and fill the specification, plan and task artifacts from `.specify/` templates. | [.agents/rules/planning-standards.md](.agents/rules/planning-standards.md) |
| `/test` | Execute TDD test loop with strict failing-test assertions. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/tdd` | Enforce the full red-green-refactor cycle. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/review` | Execute 2-stage code review (correctness, security, simplicity). | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/simplify` | Run Karpathy-compliant surgical code simplification. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/refactor-clean` | Remove dead code and enforce 400-line feature-folder modularity. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/verify` | Run the full programmatic verification suite. | [.agents/rules/automation.md](.agents/rules/automation.md) |
| `/build-fix` | Diagnose and surgically fix build or type errors. | [.agents/rules/automation.md](.agents/rules/automation.md) |

To switch MCP tool profiles dynamically:
```bash
./scripts/mcp-profile.sh <core|ui|compression|all>   # POSIX
./scripts/mcp-profile.sh --status                    # show the current profile
```
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 <core|ui|compression|all>
```

---

## 7. License & Third-Party Credits

All custom code, configurations, rules, and scripts are licensed under the [MIT License](LICENSE). Third-party tools, skills, and libraries integrated into this boilerplate are detailed in [THIRD_PARTY.md](THIRD_PARTY.md) with pinned commit SHAs, licenses, context costs, and adaptation notes.
