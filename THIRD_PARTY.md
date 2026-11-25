# Third-Party Manifest (`THIRD_PARTY.md`)

This manifest catalogs all third-party repositories, tools, skills, and MCP servers integrated into or evaluated for this boilerplate. All external sources are pinned to immutable 40-character commit SHAs or explicit package versions, licensed under permissive open-source licenses, and evaluated for token footprint and scoping compliance.

---

## 1. Primary Source Manifest (18 Evaluated Sources)

| # | Source Name & Repository URL | Pinned Commit SHA | SPDX License | Installation / Invocation Command | Context Cost (Always-On vs JIT) | Adaptation / Integration Notes | Status |
|---|---|---|---|---|---|---|---|
| 1 | **`obra/superpowers`**<br>https://github.com/obra/superpowers | `22f0b463e7a5e579904dd6211a520321035526f7` | `MIT` | Bundled in `.agents/skills/superpowers/` | Always-on: 0 tokens<br>JIT: ~2,000 tokens/skill | Curated 8 core skills (TDD, Debugging, Plans, Review, Worktrees). Hooks adapted to project `scripts/hooks/`. | **Copied & Adapted** |
| 2 | **`msitarzewski/agency-agents`**<br>https://github.com/msitarzewski/agency-agents | `8ae6164602c95ca78828b148b9052460ee426885` | `MIT` | Referenced on demand | Always-on: 0 tokens<br>JIT: ~1,500 tokens/persona | Extracted Code Reviewer and Security Auditor checklists into `.agents/rules/code-quality.md`. 100+ personas indexed on demand. | **Modified & Integrated** |
| 3 | **`addyosmani/agent-skills`**<br>https://github.com/addyosmani/agent-skills | `8c99fa36d90068c82d547f7c12a9d67a3e95f4ee` | `MIT` | Bundled in `.agents/skills/quality/` | Always-on: 0 tokens<br>JIT: ~1,200 tokens | Integrated `code-simplification` and accessibility rubrics. Adapted OpenCode command formats. | **Copied & Adapted** |
| 4 | **`mattpocock/skills`**<br>https://github.com/mattpocock/skills | `abeeaf95660ba9e8b7c753eb38f441ca707a8823` | `MIT` | Referenced on demand | Always-on: 0 tokens<br>JIT: ~1,000 tokens | Adopted TypeScript deep modules pattern. Overlapping planning skills superseded by Spec-Kit. | **Integrated on Demand** |
| 5 | **`github/spec-kit`**<br>https://github.com/github/spec-kit | `a4d571229e164e440f8950cac034607bae7b7518` | `MIT` | Initialized in `.specify/` (v1.4.3) | Always-on: 0 tokens<br>JIT: ~2,500 tokens | Core SDD engine. Constitution and templates active in `.specify/`. Connected to `planning-standards.md`. | **Copied & Wired** |
| 6 | **`affaan-m/ecc`**<br>https://github.com/affaan-m/ecc | `4adeee6732a12d1540f49a4d50a38ce8c97f9a53` | `MIT` | Referenced in `.agents/rules/` | Always-on: 0 tokens<br>JIT: ~1,500 tokens | Adopted PreToolUse config protection hook logic into `scripts/hooks/protect-config.{ps1,sh}` and `.opencode/plugins/config-protection.js`. | **Adapted** |
| 7 | **`DietrichGebert/ponytail`**<br>https://github.com/DietrichGebert/ponytail | `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` | `MIT` | `npm i @dietrichgebert/ponytail` (optional) | Always-on: 0 tokens<br>JIT: ~800 tokens | Adapted multi-agent hook structure. Debt/gain refactoring superseded by Karpathy minimal change rules. | **Adapted** |
| 8 | **`headroomlabs-ai/headroom`**<br>https://github.com/headroomlabs-ai/headroom | `e27f0d96cc3032d5f2c510ac97545553b867a697` | `Apache-2.0` | `uvx --from "headroom-ai[mcp]" headroom mcp serve` | Always-on: 0 tokens (Core)<br>Runtime savings: 20-70% | Configured as local stdio MCP server; managed via MCP profiles (`scripts/mcp-profile.ps1`). | **Integrated via MCP Profile** |
| 9 | **`rtk-ai/rtk`**<br>https://github.com/rtk-ai/rtk | `1deaf9155f219196a2ec4d46817db38123424c28` | `Apache-2.0` + `BUSL-1.1` (engine grant) | Pinned binary / `cargo install --git ... rtk` | Always-on: 0 tokens<br>Runtime savings: 60-90% | Hook interceptor in `scripts/hooks/rtk-filter.{ps1,sh}` with graceful passthrough fallback if missing. | **Adapted & Hooked** |
| 10 | **`Graphify-Labs/graphify`**<br>https://github.com/Graphify-Labs/graphify | `f51d46c63d6280a5906277b29b118dc2dd119991` | `Apache-2.0` + `MIT` | `uvx --from graphifyy graphify-mcp` | Always-on: ~350 tokens (Core)<br>JIT: queries | AST codebase knowledge graph server configured in Core MCP manifests. | **Integrated via MCP** |
| 11 | **`OthmanAdi/planning-with-files`**<br>https://github.com/OthmanAdi/planning-with-files | `adcd0b0a0a636c9e0ced71e6404b071d9eb4c1ed` | `MIT` | Integrated into `.specify/` templates | Always-on: 0 tokens<br>JIT: ~1,000 tokens | Markdown file tracking (`task_plan.md`, `progress.md`) incorporated into Spec-Kit workflow; raw standalone files superseded. | **Adapted & Merged** |
| 12 | **`thedotmack/claude-mem`**<br>https://github.com/thedotmack/claude-mem | `96658712bd46d0062eb19bbfb18723a364a9b0ef` | `Apache-2.0` | Local stdio `node mcp-server.cjs` | Always-on: 0 tokens<br>JIT: ~1,500 tokens | Cross-session memory concepts documented; persistent memory available as opt-in MCP server. | **Integrated on Demand** |
| 13 | **`Leonxlnx/taste-skill`**<br>https://github.com/Leonxlnx/taste-skill | `f6b76575f949707b4e3c37cd86cb44b0b98643e8` | `MIT` | Extracted rules into `.agents/rules/ui-standards.md` | Always-on: 0 tokens<br>JIT: ~1,200 tokens | Design aesthetic principles and copy guidelines extracted; 104 MB binary media excluded to keep repo light. | **Modified & Integrated** |
| 14 | **`pbakaus/impeccable`**<br>https://github.com/pbakaus/impeccable | `b49177d32788f2dc585c42831d845dacf1ebed2c` | `Apache-2.0` | Bundled in `.agents/skills/design/impeccable/` | Always-on: 0 tokens<br>JIT: ~1,500 tokens | Core design steering vocabulary (`polish`, `bolder`, `typeset`) and agent harness layouts adopted. 931 MB font files excluded. | **Copied & Adapted** |
| 15 | **`nextlevelbuilder/ui-ux-pro-max-skill`**<br>https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | `2de1134dc4d1cfe112934611ae5803ae17a1bd7e` | `MIT` | Optional reference | Always-on: 0 tokens | Superseded by `impeccable` + `anti-slop` due to complex Python CLI dependencies and functional overlap. | **Skipped (Documented)** |
| 16 | **`emilkowalski/skills`**<br>https://github.com/emilkowalski/skills | `64eb3deb9a5fbfa041faf783e0bc3fd635872e9c` | `MIT` | Bundled in `.agents/skills/design/motion/` | Always-on: 0 tokens<br>JIT: ~1,500 tokens | 60/120fps motion engineering, spring curves, touch gestures, and `break-ui` stress testing integrated. | **Copied & Wired** |
| 17 | **`miqdadbadjuber/anti-slop`**<br>https://github.com/miqdadbadjuber/anti-slop | `44b3547ed6d6f21eed777271602da113efc53c94` | `MIT` | Bundled in `.agents/skills/design/antislop/` | Always-on: ~150 tokens (pointer)<br>JIT: ~1,200 tokens | 12-line pointer rule wired to `ui-standards.md`; sub-skills (`antislop-ui`, `antislop-copywriting`, `antislop-human`, WCAG) active on demand. | **Copied & Wired** |
| 18 | **`mrityunjay-tiwari/ui-registry-mcp`**<br>https://github.com/mrityunjay-tiwari/ui-registry-mcp | `1b0e276ca6e30310075cedd701beb76b37c1b85e` | `MIT` | `npx -y ui-registry-mcp@0.7.1` | Always-on: 0 tokens (Core)<br>UI Profile: ~400 tokens | Component discovery MCP server connecting to 12 shadcn-style registries. Loaded on-demand in UI profile. | **Integrated via MCP Profile** |

---

## 2. Supplementary Ecosystem Tools

| Tool / Source | Repository / Reference | Pinned Identifier | License | Execution Method | Context Cost | Role & Adaptation |
|---|---|---|---|---|---|---|
| **shadcn CLI** | https://ui.shadcn.com/docs/mcp | `latest` (`npm`) | `MIT` | `npx shadcn@latest` | 0 tokens (CLI) | Scaffolds and adds UI components directly into project via `components.json`. |
| **Astryx CLI** | https://github.com/meta/astryx | `fd968d342abb0d1508ec63d9300fb259d894927d` | `MIT` | `npx @astryxdesign/cli` | 0 tokens (CLI) | Enterprise React 19 + StyleX component registry alternative; documented as optional CLI alternative. |
| **Browser Harness** | https://github.com/browser-use/browser-harness | `22ecf8545d67c474fa024643632d70af28b7fa0e` | `MIT` | `pip install browser-harness==0.1.14` | 0 tokens always-on<br>~1,000 tokens JIT | Thin CDP client for background automated browser interaction without stealing window focus. |

---

## 3. Named Exceptions and Workarounds

### Exception 1: Freebuff Agent Directory Trust Gate (`CODEBUFF_TRUST_AGENT_DIRS=1`)
- **Origin**: Freebuff / Codebuff agent runtime.
- **Behavior**: Freebuff prompts the user interactively before loading agent rule files in `.agents/` or reading repository configs.
- **Workaround**: Setting the environment variable `CODEBUFF_TRUST_AGENT_DIRS=1` bypasses the interactive prompt, enabling unattended CI and automated execution without modifying any global settings.
- **Scoping Compliance**: Preserved. The variable is defined locally in `.env.example` and passed per session; no global `%APPDATA%` or registry modifications occur.
- **Reference**: Documented in `docs/agents/freebuff.md`.

### Exception 2: `rtk` (Rust Token Killer) Dual Licensing Grant
- **Origin**: `rtk-ai/rtk` (commit `1deaf9155f219196a2ec4d46817db38123424c28`).
- **License**: Core engine licensed under Business Source License 1.1 (`BUSL-1.1`), with CLI wrappers and hooks under `Apache-2.0`.
- **Additional Use Grant**: The copyright holder provides an explicit Additional Use Grant allowing non-production development, local test running, and personal/commercial agent terminal output filtering.
- **Graceful Degradation**: `scripts/hooks/rtk-filter.{ps1,sh}` tests for the `rtk` binary in PATH before invocation; if absent, stdout and stderr pass through unmodified with zero disruption.

### Exception 3: Astryx Monolithic Git RPC Clone Exclusion
- **Origin**: `meta/astryx` (commit `fd968d342abb0d1508ec63d9300fb259d894927d`).
- **Issue**: Astryx is a 1.38 GB monolithic repository that triggers HTTP 502 / Git RPC errors during standard git shallow clones on restricted bandwidth.
- **Workaround**: The repository source is not vendored directly into `.agents/skills/`. Instead, its component registry capabilities are integrated on-demand via the published npm package `@astryxdesign/cli` and `mrityunjay-tiwari/ui-registry-mcp`.

---

## 4. Pinned SHA Maintenance & Manifest Verification

All commit hashes in this manifest are validated programmatically. To audit or update upstream pinned SHAs:

```powershell
# Windows PowerShell (Audit only):
powershell -ExecutionPolicy Bypass -File ./scripts/update-third-party.ps1 -CheckOnly

# Windows PowerShell (Refresh all SHAs from origin main/master):
powershell -ExecutionPolicy Bypass -File ./scripts/update-third-party.ps1 -UpdateAll

# POSIX / Python:
python ./scripts/update-third-party.py --check
python ./scripts/update-third-party.py --update
```

The updater script queries the GitHub REST API or Git remote references, checks whether HEAD has advanced, and generates an updated `THIRD_PARTY.md` with zero manual editing.
