# Multi-Agent Boilerplate: Core Invariants & Universal Agent Index

Production-ready, project-level boilerplate for autonomous coding agents. Zero global configuration. Compatible with any AI coding agent.

---

## 1. Non-Negotiable Invariants

- **Strict Project Scoping**: NEVER modify files outside the project root (the directory that contains this `AGENTS.md`). Writes to `%USERPROFILE%`, `%APPDATA%`, `~/.config`, `~/.gemini`, or `~/.claude` are forbidden.
- **Secret Hygiene**: ZERO secrets committed. Keep sensitive credentials in `.env` (strictly mirrored and ignored by `.gitignore` and `.aiignore`); see [`.env.example`](.env.example).
- **Episodic Memory**: Decisions, preferences, error recoveries and facts persist in `.agents/memory/` (a git-ignored JSONL store). Write them with `/remember`, read them with `/recall`; the `memory-sync` hook recalls the store at session start.
- **Vendored Third-Party Islands**: Third-party code that ships with this boilerplate lives in `.repo/`, never in `src/features/` — that folder belongs to the user's own features. Every island is pinned with its licence and commit SHA in [`THIRD_PARTY.md`](THIRD_PARTY.md).
- **Project-Level Isolation**: Everything this repository configures lives inside the project folder. MCP servers and `npm` are pointed at the project-local `.cache/` directory (via the `env` blocks in every adapter config and the project `.npmrc`), so importing this boilerplate does not modify the user's global configuration. The only sanctioned write outside the project is the self-test sandbox, which lives in the system temp directory and is deleted on exit.
- **Single Canonical Skill Store**: Skills reside strictly in `.agents/skills/`. Agents access them directly or via zero-elevation NTFS directory junctions (`mklink /J`) and symlinks. `scripts/sync-agent-adapters.sh` creates and verifies all six junctions.

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

- **File Length Limits**: Strict **maximum 400 lines** per file. Target range: **200 to 400 lines** for core feature modules. Enforced via `tsconfig.json`, `eslint.config.js`, and `scripts/verify-file-limits.{sh,ps1}`.
- **Feature-Folder Architecture**: Organize all capabilities into dedicated vertical slices under `src/features/<feature-name>/` (following `src/features/_template/`). Vendored third-party code belongs in `.repo/`, not here.
- **Codebase Exploration via Graphify**: NEVER guess or run naive whole-repo greps. Use `Graphify-Labs/graphify` (`query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `get_section`, `god_nodes`, `graph_stats`).
- **Cloudflare CodeMode MCP Rule**: Avoid token burn from massive MCP tool schemas. Keep the default profile locked to `core` and execute programmatic scripts or on-demand profile switching (`scripts/mcp-profile.sh <core|ui|compression|all>`, `scripts/mcp-profile.ps1 -Profile <core|ui|compression|all>`). Verify the servers actually boot with `python3 scripts/verify-mcp-servers.py`.
- **Planning with Files & Spec-Kit**: Maintain persistent execution files in `.planning/` (`task_plan.md`, `findings.md`, `progress.md`) and specifications in `specs/<NNN>-<slug>/`, scaffolded from the templates in `.specify/` (see `.specify/README.md`).

---

## 4. Autonomous Skill Discovery Protocol

The repository contains a canonical store of **377 skills**, every one mapped to a governing rule in `.agents/rules/skills-index.md`, across:
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
| Claude Code | `CLAUDE.md` + `.claude/settings.json` | `.claude/skills` Junction | [docs/agents/claude.md](docs/agents/claude.md) |
| Cursor | `.cursor/rules/core.mdc` + `.cursor/mcp.json` | `.cursor/skills` Junction | [docs/agents/cursor.md](docs/agents/cursor.md) |
| Windsurf | `.windsurfrules` | `.windsurf/skills` Junction | [docs/agents/windsurf.md](docs/agents/windsurf.md) |
| GitHub Copilot | `.github/copilot-instructions.md` | Native | [docs/agents/copilot.md](docs/agents/copilot.md) |
| Cline / Roo Code | `.clinerules` | `.cline/skills` Junction | [docs/agents/cline.md](docs/agents/cline.md) |
| Codex CLI | `.codex/config.toml` | `.codex/skills` Junction | [docs/agents/codex.md](docs/agents/codex.md) |
| Qoder / CLI | `.qoder/settings.json` | `.qoder/skills` Junction | [docs/agents/qoder.md](docs/agents/qoder.md) |
| Goose | `.goosehints` + `.goose/config.yaml`| Native | [docs/agents/goose.md](docs/agents/goose.md) |
| Kimi CLI | `.kimi/config.toml` + `.kimi-code/mcp.json` | Native | [docs/agents/kimi.md](docs/agents/kimi.md) |
| Junie | `.junie/playbook.md` | Native | [docs/agents/junie.md](docs/agents/junie.md) |
| Freebuff | `AGENTS.md` + `.agents/mcp.json` | Native | [docs/agents/freebuff.md](docs/agents/freebuff.md) |

Every row above is enforced by `scripts/verify-adapters.py`: an adapter that loses its rules, MCP servers, hooks or slash commands fails the verification suite.

---

## 6. Verification & Slash Commands

- Verification Suite: `verify-all.cmd` (Windows) or `./scripts/verify-all.sh` (POSIX) — **10 suites, all must pass**.
- Project Checks: `npm test`, `npm run lint`, `npm run typecheck` (requires `npm install`).
- File Limits Check: `powershell -ExecutionPolicy Bypass -File ./scripts/verify-file-limits.ps1`
- Sync Agent Adapters: `powershell -ExecutionPolicy Bypass -File ./scripts/sync-agent-adapters.ps1`
- Slash Commands (canonical source: `.agents/commands/`, distributed to every adapter):
  - `/plan`: Scaffold and fill the specification, plan and task artifacts from `.specify/` templates.
  - `/review`: Run 2-stage code review (correctness, security, simplicity).
  - `/test`: Run TDD cycle with failing-test assertions.
  - `/simplify`: Run Karpathy-compliant surgical simplification.
  - `/tdd`: Enforce red-green-refactor test-driven development.
  - `/verify`: Run full programmatic verification suite.
  - `/build-fix`: Diagnose and resolve build/type errors surgically.
  - `/refactor-clean`: Remove dead code and simplify modules (<= 400 lines).
  - `/remember`: Record a decision, preference, recovery or fact in the episodic memory store.
  - `/recall`: Search the episodic memory store for earlier decisions and facts.
- Browser Testing: Use `browser-use/browser-harness` (`.agents/skills/automation/browser-harness/SKILL.md`) for CDP-driven browser verification.
