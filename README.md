# Production-Ready Multi-Agent Unified Boilerplate

A battle-tested, project-level starter template for autonomous coding agents. Zero global configuration required — all skills, rules, hooks, plugins, and MCP servers reside strictly within the project boundary.

---

## 1. Project Overview & Architecture

Modern AI coding agents (OpenCode, Antigravity, Codex, Qoder, Goose, Kimi, Junie, Freebuff) often require scattered global configuration in `~/.config`, `%APPDATA%`, or `~/.claude`. This boilerplate eliminates manual setup and configuration drift by providing a self-contained, project-scoped architecture:

- **Layer 1: Always-On Core (`AGENTS.md`)**: Comprehensive root index containing project invariants, Karpathy minimal-change guidelines, 4-step UI/UX pipeline, Cloudflare CodeMode MCP rules, and pointers to all rules and agent adapters.
- **Layer 2: On-Demand Rules (`.agents/rules/*.md`)**: Modular rules loaded conditionally via glob pattern triggers or agent routing for planning, code quality, UI standards, exploration, and automation.
- **Layer 3: Single Canonical Skill Store (`.agents/skills/`)**: Single canonical truth for all integrated skills (Superpowers, Impeccable, Anti-Slop, Motion, Code Simplification). Agents access them directly or via zero-elevation NTFS directory junctions (`mklink /J`) on Windows and symlinks on POSIX.
- **Dynamic MCP Profiles**: Switch between `core` (default, ~350 tokens), `ui` (~750 tokens), `compression` (~650 tokens), or `all` profiles via `scripts/mcp-profile.{ps1,sh}`.
- **Executable Lifecycle Hooks (`scripts/hooks/`)**: Standalone scripts enforcing config protection, terminal output token filtering via `rtk`, and session startup validation.
- **Self-Verification Suite (`scripts/`)**: Programmatic verification scripts validating link integrity, script syntax, tool availability, and sandbox bootstrap isolation.

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

3. DISCOVER YOUR AGENT CONFIGURATION:
   Identify your agent runtime and review your specific setup guide in `docs/agents/`:
   - OpenCode: Consult docs/agents/opencode.md (reads opencode.json & .opencode/plugins/)
   - Antigravity IDE / CLI: Consult docs/agents/antigravity.md (reads .antigravity/ & .agents/)
   - Codex CLI: Consult docs/agents/codex.md (reads .codex/config.toml)
   - Qoder / Qoder CLI: Consult docs/agents/qoder.md (reads .qoder/settings.json)
   - Freebuff: Consult docs/agents/freebuff.md (set CODEBUFF_TRUST_AGENT_DIRS=1; reads AGENTS.md)
   - Goose: Consult docs/agents/goose.md (reads .goosehints & .goose/config.yaml)
   - Kimi Code CLI: Consult docs/agents/kimi.md (reads .kimi/config.toml & AGENTS.md)
   - JetBrains Junie: Consult docs/agents/junie.md (reads .junie/playbook.md & AGENTS.md)

4. STRICT SCOPING MANDATE:
   NEVER write, edit, or create files outside this project directory (e.g. in $HOME, %USERPROFILE%, or global config directories). All rules, skills, MCP servers, and hooks are strictly project-scoped.

5. PROGRESSIVE DISCLOSURE & WORKFLOWS:
   - For architecture & specs: Run `/plan` or inspect `.specify/`.
   - For implementation: Use Superpowers TDD (.agents/skills/superpowers/test-driven-development/SKILL.md).
   - For UI/UX: Follow Impeccable verbs and Anti-Slop gates (.agents/rules/ui-standards.md). Activate UI MCP profile if needed via: powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile ui
   - For code review: Execute 2-stage review before completing tasks (.agents/rules/code-quality.md).
```

---

## 4. Per-Agent Guide Index

Detailed setup guides, configuration files, and hook mappings for supported agents:

| Agent Runtime | Primary Config File | Setup Guide | Native Hook Support | Skill Access Method |
|---|---|---|---|---|
| **OpenCode** | `opencode.json` | [docs/agents/opencode.md](docs/agents/opencode.md) | Native plugins (`.opencode/plugins/`) | Native (`.agents/skills/`) |
| **Antigravity IDE / CLI** | `.antigravity/settings.json` | [docs/agents/antigravity.md](docs/agents/antigravity.md) | Native hooks (`.antigravity/hooks.json`) | Native (`.agents/skills/`) |
| **Codex CLI** | `.codex/config.toml` | [docs/agents/codex.md](docs/agents/codex.md) | Open Plugins hooks (`scripts/hooks/`) | NTFS Junction (`.codex/skills`) |
| **Qoder / Qoder CLI** | `.qoder/settings.json` | [docs/agents/qoder.md](docs/agents/qoder.md) | Lifecycle hooks | NTFS Junction (`.qoder/skills`) |
| **Freebuff** | `AGENTS.md` + `.agents/mcp.json` | [docs/agents/freebuff.md](docs/agents/freebuff.md) | Behavioral rules (`AGENTS.md`) | Native (`.agents/skills/`) |
| **Goose (Block)** | `.goosehints` + `.goose/config.yaml` | [docs/agents/goose.md](docs/agents/goose.md) | Open Plugins (`.goose/hooks.json`) | Pointer (`.goosehints`) |
| **Kimi Code CLI** | `.kimi/config.toml` | [docs/agents/kimi.md](docs/agents/kimi.md) | Behavioral rules (`AGENTS.md`) | Configured (`.agents/skills/`) |
| **JetBrains Junie** | `.junie/playbook.md` | [docs/agents/junie.md](docs/agents/junie.md) | Junie guidelines | Converted rules (`.junie/rules/`) |

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

The verification suite executes 4 programmatic checks:
1. `scripts/verify-tools.{ps1,sh}`: Validates Git, Node, Python, PowerShell runtimes and MCP command resolvers.
2. `scripts/verify-scripts.{ps1,sh}`: Validates PowerShell AST syntax, Bash script syntax, and Python compilation.
3. `scripts/verify-links.py`: Code-block aware parser confirming all internal Markdown links and GitHub anchor slugs resolve.
4. `scripts/test-bootstrap.{ps1,sh}`: Runs an isolated sandbox clone asserting zero files are touched outside the sandbox.

---

## 6. Core Slash Commands & Workflows

| Command | Workflow Description | Primary Rule File |
|---|---|---|
| `/plan` | Formulate architectural specification or atomic task checklist. | [.agents/rules/planning-standards.md](.agents/rules/planning-standards.md) |
| `/test` | Execute TDD test loop with strict failing-test assertions. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/review` | Execute 2-stage code review (correctness, security, simplicity). | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |
| `/simplify` | Run Karpathy-compliant surgical code simplification. | [.agents/rules/code-quality.md](.agents/rules/code-quality.md) |

To switch MCP tool profiles dynamically:
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile <core|ui|compression|all>
```

---

## 7. License & Third-Party Credits

All custom code, configurations, rules, and scripts are licensed under the [MIT License](LICENSE). Third-party tools, skills, and libraries integrated into this boilerplate are detailed in [THIRD_PARTY.md](THIRD_PARTY.md) with pinned commit SHAs, licenses, context costs, and adaptation notes.
