# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

Nothing yet.

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

[Unreleased]: https://github.com/ur-sriram/boilerplate/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ur-sriram/boilerplate/releases/tag/v1.0.0
