# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

Nothing yet.

---

## [1.1.0] — 2026-11-27

### Changed

- **claude-mem now follows upstream's observation model.** The 9 observation
  types and 7 concepts of the upstream `code` mode profile replace the
  taxonomy the boilerplate's own prose had invented; `sensitive` episodes are
  withheld from recall unless `--include-sensitive`; dedup has two tiers (an
  identical title is merged, a near-duplicate is reported and **not** written);
  ranking uses the IDF model with its term veto; retrieval is index-first
  (`search` → `timeline` → `get`); and every episode is attributed to the
  session that wrote it. The legacy spellings still map, so existing entries
  keep reading. The LLM observer, automatic capture, SQLite/Chroma, the
  25-tool MCP server, cloud sync and telemetry are deliberately not adopted,
  and the reasons are documented.
- **claude-mem is now a project-level vendored island.** The store, its CLI and
  the launcher moved from `src/features/claude-mem/` to `.repo/claude-mem/`, so
  `src/features/` stays free for the user's own features and every vendored
  component is pinned in `THIRD_PARTY.md`. See
  [`.repo/README.md`](.repo/README.md).
- **The episodic memory now has a write path.** `/remember` records an
  observation — a decision, a discovery, a change, a gotcha; `/recall`
  searches the store. Both are distributed to every adapter and enforced by
  `scripts/verify-adapters.py`. Previously the hook only read, so in a real
  session the store stayed empty.
- **`.repo/` is the home for vendored third-party code**, with a README that
  states what an island is and the rules one follows.
- **`package.json` requires Node `>=22.18.0`** (it claimed `>=22.6.0`).
  The test suite, the claude-mem CLI and every hook that runs a `.ts` file
  need the type stripping that ships by default from that release;
  `scripts/verify-tools.{sh,ps1}` now asserts the version.

### Fixed

- The claude-mem store resolved the project root by counting directory
  levels. After the island moved, that arithmetic pointed the store at the
  **parent of the project** — a write outside the boundary the store promises
  never to cross. `findProjectRoot()` now walks up to the nearest
  `AGENTS.md`, with regression tests.
- On a runtime older than Node 22.18 the claude-mem CLI died with an opaque
  `ERR_UNKNOWN_FILE_EXTENSION` that the advisory catch swallowed. A plain-JS
  launcher (`.repo/claude-mem/run.mjs`) now checks the runtime first and says
  what to install.
- `.agents/rules/core-invariants.md` had no clause about episodic memory, so
  the adapters without a hook API had no prompt-level rule to fall back on.
  Section 3 now states it.
- The slash-command count was still 8 in `scripts/sync-agent-adapters.sh`,
  `scripts/verify-adapters.py` and `docs/agents/copilot.md` after the two new
  commands landed.
- `.agents/memory/session.json` is machine-local state like the episode
  store, but it was not ignored — it would have been committed with a live
  session id in it.

---

## [1.0.0] — 2026-11-27

First public release of the boilerplate as a GitHub template.

### Added

- **377 wired skills** in a single canonical store (`.agents/skills/`), each
  mapped to exactly one governing rule file in
  [`.agents/rules/skills-index.md`](.agents/rules/skills-index.md).
- **13 agent adapters** sharing the same rules, skills, MCP servers and slash
  commands: Claude Code, Cursor, Codex CLI, GitHub Copilot, OpenCode, JetBrains
  Junie, Kimi Code CLI, Goose, Qoder, Windsurf, Cline / Roo Code, Antigravity
  and Freebuff.
- **8 slash commands** (`/plan`, `/tdd`, `/test`, `/review`, `/simplify`,
  `/refactor-clean`, `/verify`, `/build-fix`) with a single source of truth in
  `.agents/commands/`.
- **Spec-driven development** templates (`.specify/`) and a project
  constitution covering project-local scoping, TDD, the 400-line file cap and
  the skill-wiring rule.
- **A 10-suite verification runner** (`./scripts/verify-all.sh`) covering
  runtimes, scripts, file limits, Markdown links, adapter sync, bootstrap,
  skill-map drift, adapter parity, vendored Spec Kit integrity and the
  OpenCode plugin contract.
- **Project-local isolation**: every MCP server and package manager cache is
  pinned inside the project folder, so setup never writes to global config.
- **Continuous integration** on Linux and Windows running the full suite plus
  lint, typecheck and unit tests.
- **Contributor onboarding**: contributing guide, bug and feature request issue
  templates, and a `good first issue` label to seed first contributions.

### Fixed

- The OpenCode plugins now satisfy the loader contract, so every guardrail
  actually fires instead of being silently dropped.
- MCP servers are started from project-local paths and are verified to boot.
- `AGENTS.md` stays inside its token budget, so agent context stays small.

[Unreleased]: https://github.com/ur-sriram/boilerplate/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/ur-sriram/boilerplate/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ur-sriram/boilerplate/releases/tag/v1.0.0
