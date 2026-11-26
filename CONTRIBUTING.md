# Contributing to Multi-Agent Boilerplate

Thanks for wanting to make this better. This guide covers everything you need
to go from "I have an idea" to a merged pull request — including the checks
that CI runs on your branch.

**New to open source?** Look for issues labelled
[good first issue](https://github.com/ur-sriram/boilerplate/issues?q=label%3A%22good+first+issue%22).
They are small, well-scoped and explained — pick one, comment so nobody
duplicates your work, and go.

Questions that are not bug reports belong in
[Discussions](https://github.com/ur-sriram/boilerplate/discussions).

---

## 1. Set up

You need Node.js ≥ 22.6, Python 3.10+, Git, and Bash (or PowerShell on
Windows). `uv`/`uvx` is optional but recommended — it powers the MCP servers.

```bash
git clone https://github.com/ur-sriram/boilerplate.git
cd boilerplate
npm install          # TypeScript, ESLint and the test runner
```

Then wire up the agent adapters so the local checks can run:

```bash
./scripts/bootstrap.sh            # macOS / Linux
bootstrap.cmd                     # Windows
```

Check the repo is healthy before you touch anything:

```bash
./scripts/verify-all.sh           # macOS / Linux
verify-all.cmd                    # Windows
```

All 10 suites must be green. If they are not, the repo is already broken —
please open an issue instead of pushing a fix you did not cause.

---

## 2. The rules this repo follows

The constitution lives in
[`.specify/memory/constitution.md`](.specify/memory/constitution.md). The short
version:

| Rule | What it means in practice |
|---|---|
| **Project-local only** | Never write outside the project folder — no global agent config, no global package cache. The hooks enforce it. |
| **No secrets** | Never commit credentials, tokens or `.env` files. `.env.example` is the only env file that belongs in the repo. |
| **TDD by default** | Write the failing test first, watch it fail, then implement. |
| **400-line file cap** | Files over 400 lines fail CI. Split instead of growing. |
| **One canonical skill store** | Skills live in `.agents/skills/` and are wired to exactly one rule file. |
| **Never edit vendored skills** | `.agents/skills/` holds upstream content — add your own skill in a new folder instead. |

The longer explanation of each rule lives in
[`.agents/rules/`](.agents/rules) — start with
[`code-quality.md`](.agents/rules/code-quality.md) and
[`core-invariants.md`](.agents/rules/core-invariants.md).

---

## 3. The daily loop

```bash
./scripts/verify-all.sh    # before every commit — catches drift in seconds
npm test                   # unit tests
npm run lint               # ESLint + the 400-line limit
npm run typecheck          # tsc --noEmit
```

The `/plan`, `/tdd`, `/review` and `/verify` slash commands work inside any
supported agent, and they are exactly the workflow this repo expects:
plan first, implement test-first, verify, then review your own diff.

---

## 4. Adding things

### A new skill

1. Create `.agents/skills/<category>/<your-skill>/SKILL.md` with YAML
   frontmatter containing at least `name` and `description`.
2. Register it in the wiring map:
   ```bash
   python3 scripts/generate-skills-index.py
   ```
   This regenerates [`.agents/rules/skills-index.md`](.agents/rules/skills-index.md)
   and wires the skill to exactly one governing rule file.
3. Run `./scripts/verify-all.sh` — the "Skill wiring" suite must stay green.

Never hand-edit `.agents/rules/skills-index.md`; it is generated.

### A new rule file

Add a Markdown file in `.agents/rules/`, reference it from
[`AGENTS.md`](AGENTS.md), and keep it short. Rules load on demand — a long
rule file defeats the whole layering.

### A new slash command

Edit the source of truth in [`.agents/commands/`](.agents/commands), then push
it to every agent:

```bash
./scripts/sync-agent-adapters.sh
```

The "Adapter parity" suite fails if any agent is missing a command.

### A new feature

```bash
cp -r src/features/_template src/features/<your-feature>
```

Then write `feature.test.ts` first. Each feature folder holds `feature.ts`,
`feature.types.ts`, `feature.test.ts`, `index.ts` and a `README.md`.

---

## 5. Pull requests

1. **Branch** from `main`: `git checkout -b feat/my-change`.
2. **Keep it focused.** One logical change per PR. Drive-by refactors and
   unrelated reformatting make review harder and will be asked for as a
   separate PR.
3. **Run the checks locally** — `./scripts/verify-all.sh` plus `npm test`,
   `npm run lint` and `npm run typecheck`.
4. **Open the PR** with a short description of *what* changed and *why*. Link
   the issue it fixes (`Fixes #123`).
5. **The checks must be green.** Run `./scripts/verify-all.sh`, `npm test`,
   `npm run lint` and `npm run typecheck` — these are exactly the commands the
   GitHub Actions workflow runs, on Linux and on Windows.
6. **Respond to review.** Push follow-up commits rather than force-pushing once
   review has started.

### Commit messages

Use the style already in the history:

```
feat: add a dark mode toggle to the settings page
fix: keep the npm cache inside the project folder
docs: explain the adapter parity check
refactor: split the file-limit verifier into two scripts
chore: bump eslint to 10.15.0
```

---

## 6. Reporting bugs

Open an issue using the **Bug report** template and include:

- the repo version (tag or commit) and your OS,
- the exact command you ran,
- what you expected and what happened instead,
- the output of `./scripts/verify-all.sh` if the problem is in the verification
  suite itself.

Security issues: do not open a public issue. Use GitHub's private
vulnerability reporting (the **Security** tab of the repository) or contact the
maintainer directly.

---

## 7. Licensing

By contributing you agree that your contribution is licensed under the
[MIT licence](LICENSE). Vendored third-party content keeps its own licence —
see [THIRD_PARTY.md](THIRD_PARTY.md) — and must not be modified in place.

---

## 8. Code of conduct

Be decent. Assume good faith, critique code rather than people, and keep
discussion focused on the work. Harassment of any kind is not tolerated.
Report problems to the maintainer privately.
