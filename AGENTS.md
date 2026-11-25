# Multi-Agent Boilerplate: Core Invariants & Universal Agent Index

Production-ready, project-level boilerplate for autonomous coding agents. Zero global configuration. Compatible with any AI coding agent.

---

## 1. Non-Negotiable Invariants

- **Strict Project Scoping**: NEVER modify files outside `c:\sriram\boilerplate`. Writes to `%USERPROFILE%`, `%APPDATA%`, `~/.config`, `~/.gemini`, or `~/.claude` are forbidden.
- **Secret Hygiene**: ZERO secrets committed. Keep sensitive credentials in `.env` (strictly mirrored and ignored by `.gitignore` and `.aiignore`); see [`.env.example`](.env.example).
- **Episodic Memory**: Cross-session memory and learned operational facts persist in `.agents/memory/` using the `claude-mem` architecture.
- **Single Canonical Skill Store**: Skills reside strictly in `.agents/skills/`. Agents access them directly or via zero-elevation NTFS directory junctions (`mklink /J`) and symlinks.

---

## 2. Mandatory 4-Step UI/UX Development Pipeline

Whenever creating or modifying web interfaces, agents MUST follow this sequential 4-step workflow:

1. **Step 1: Component Sourcing (Zero-Scratch Mandate)**:
   - Search `ui-registry-mcp` (across 12 registries), `shadcn mcp` (`npx shadcn@latest mcp`), and Meta's `@astryxdesign/cli`.
   - Adapt and install existing primitives. ONLY if not found across all three sources may custom components be built from scratch.
2. **Step 2: Motion & Animation (`emilkowalski/skills`)**:
   - Apply spring physics (`stiffness: 300, damping: 30, mass: 1`), 60/120fps GPU-composited transforms (`transform`, `opacity`), and `prefers-reduced-motion` compliance.
3. **Step 3: Anti-Slop & Unslop Gate (`anti-slop` + `heydamir/unslop`)**:
   - Strip AI clichés (generic purple/cyan radial gradients, meaningless floating cards, decorative sparkles, corporate buzzwords). Enforce WCAG 2.2 AA contrast standards.
4. **Step 4: Impeccable Craftsmanship & Taste Polish (`impeccable` + `taste-skill`)**:
   - Apply steering verbs (`polish`, `bolder`, `quieter`, `typeset`, `colorize`, `contrast`, `align`, `space`, `hierarchy`) and curated typographical palettes.

---

## 3. Code Quality, Modularity & Architecture

- **File Length Limits**: Strict **maximum 400 lines** per file. Target range: **200 to 400 lines** for core feature modules. Enforced via `tsconfig.json`, `.eslintrc.json`, and `scripts/verify-file-limits.ps1`.
- **Feature-Folder Architecture**: Organize all capabilities into dedicated vertical slices under `src/features/<feature-name>/` (following `src/features/_template/`).
- **Codebase Exploration via Graphify**: NEVER guess or run naive whole-repo greps. Use `Graphify-Labs/graphify` (`search_graph`, `trace_path`, `get_code_snippet`, `query_graph`).
- **Cloudflare CodeMode MCP Rule**: Avoid token burn from massive MCP tool schemas. Keep the default profile locked to `core` and execute programmatic scripts or on-demand profile switching (`scripts/mcp-profile.ps1 -Profile <core|ui|compression|all>`).
- **Planning with Files & Spec-Kit**: Maintain persistent execution files in `.planning/` (`task_plan.md`, `findings.md`, `progress.md`) and specifications in `.specify/`.

---

## 4. Autonomous Skill Discovery Protocol

The repository contains a canonical store of 300+ skills across:
- **`superpowers/`**: Engineering workflows (`test-driven-development`, `systematic-debugging`, `writing-plans`, etc.).
- **`agency-agents/`**: 270+ domain-expert agent skills.
- **`agent-skills/`**: Addy Osmani engineering and workflow skills.
- **`mattpocock/`**: TypeScript and engineering skills.
- **`design/`**: `impeccable`, `taste-skill`, `anti-slop`, `unslop`, `motion`.
- **`automation/`**: `browser-harness`, `ponytail`, `rtk`, `claude-mem`, `graphify`, `planning-with-files`.

**How to find skills**: Inspect [`.agents/rules/skills-index.md`](.agents/rules/skills-index.md) or list directory names in `.agents/skills/` to locate and load the exact skill required for any task.

---

## 5. Universal Agent Adapter Index

Zero-duplication configuration and discovery guides for all major coding agents:

| Agent | Entry Point / Configuration | Discovery Mechanism | Guide |
|---|---|---|---|
| Universal Standard | `AGENTS.md` + `.agents/rules/*.md` | Native `.agents/skills/` | [README.md](README.md) |
| Antigravity IDE / CLI | `.antigravity/settings.json` | Native `.agents/skills/` | [docs/agents/antigravity.md](docs/agents/antigravity.md) |
| OpenCode | `opencode.json` + `.opencode/` | Native `.agents/skills/` | [docs/agents/opencode.md](docs/agents/opencode.md) |
| Claude Code | `CLAUDE.md` | `.claude/skills` Junction | [CLAUDE.md](CLAUDE.md) |
| Cursor | `.cursor/rules/core.mdc` | `.cursor/skills` Junction | [README.md](README.md) |
| Windsurf | `.windsurfrules` | `.windsurf/skills` Junction | [README.md](README.md) |
| GitHub Copilot | `.github/copilot-instructions.md` | Native | [README.md](README.md) |
| Cline / Roo Code | `.clinerules` | `.cline/skills` Junction | [README.md](README.md) |
| Codex CLI | `.codex/config.toml` | `.codex/skills` Junction | [docs/agents/codex.md](docs/agents/codex.md) |
| Qoder / CLI | `.qoder/settings.json` | `.qoder/skills` Junction | [docs/agents/qoder.md](docs/agents/qoder.md) |
| Goose | `.goosehints` + `.goose/config.yaml`| Native | [docs/agents/goose.md](docs/agents/goose.md) |
| Kimi CLI | `.kimi/config.toml` | Native | [docs/agents/kimi.md](docs/agents/kimi.md) |
| Junie | `.junie/playbook.md` | Native | [docs/agents/junie.md](docs/agents/junie.md) |
| Freebuff | `AGENTS.md` + `.agents/mcp.json` | Native | [docs/agents/freebuff.md](docs/agents/freebuff.md) |

---

## 6. Verification & Slash Commands

- Verification Suite: `verify-all.cmd` (Windows) or `./scripts/verify-all.sh` (POSIX).
- File Limits Check: `powershell -ExecutionPolicy Bypass -File ./scripts/verify-file-limits.ps1`
- Sync Agent Adapters: `powershell -ExecutionPolicy Bypass -File ./scripts/sync-agent-adapters.ps1`
- Slash Commands:
  - `/plan`: Initiate architectural specification or task plan.
  - `/review`: Run 2-stage code review (correctness, security, simplicity).
  - `/test`: Run TDD cycle with failing-test assertions.
  - `/simplify`: Run Karpathy-compliant surgical simplification.
  - `/tdd`: Enforce red-green-refactor test-driven development.
  - `/verify`: Run full programmatic verification suite.
  - `/build-fix`: Diagnose and resolve build/type errors surgically.
  - `/refactor-clean`: Remove dead code and simplify modules (<= 400 lines).
- Browser Testing: Use `browser-use/browser-harness` (`.agents/skills/automation/browser-harness/SKILL.md`) for CDP-driven browser verification.
