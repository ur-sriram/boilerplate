# `.specify/` — Vendored Spec Kit Engine (v1.4.3)

This directory is a **vendored copy of [GitHub Spec Kit](https://github.com/github/spec-kit)
v1.4.3** (MIT). It is the specification-driven-development (SDD) engine of
this boilerplate: templates, constitution, workflow definition and the
scripts that scaffold a feature.

## What lives here

| Path | Purpose |
|---|---|
| `templates/` | `spec-template.md`, `plan-template.md`, `tasks-template.md`, `checklist-template.md`, `constitution-template.md` — the skeletons an agent fills in |
| `templates/overrides/` | Project-local template overrides (highest priority) |
| `memory/constitution.md` | The project's binding constitution (scoping, secrets, TDD, file limits, skill wiring) |
| `scripts/powershell/` | Windows implementation of the four SDD scripts |
| `scripts/bash/` | POSIX implementation of the same four scripts (vendored from upstream v1.4.3) |
| `workflows/speckit/workflow.yml` | "Full SDD Cycle" workflow: specify → gate → plan → gate → tasks → implement |
| `workflows/workflow-registry.json` | Registry of installed workflows |
| `integration.json` / `init-options.json` | Spec Kit CLI state for this checkout |
| `integrations/speckit.manifest.json` | SHA-256 of every vendored file (verified by `scripts/verify-specify-integrity.py`) |

## Running the SDD cycle

**Windows (PowerShell)**

```powershell
pwsh .specify/scripts/powershell/create-new-feature.ps1 "Add OAuth login" -ShortName user-auth
pwsh .specify/scripts/powershell/setup-plan.ps1
pwsh .specify/scripts/powershell/setup-tasks.ps1
pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireSpec -RequireTasks -IncludeTasks
```

**POSIX (bash)**

```bash
bash .specify/scripts/bash/create-new-feature.sh "Add OAuth login" --short-name user-auth
bash .specify/scripts/bash/setup-plan.sh
bash .specify/scripts/bash/setup-tasks.sh
bash .specify/scripts/bash/check-prerequisites.sh --json --require-spec --include-tasks
```

Both families write the same artifacts into `specs/<NNN>-<slug>/`:
`spec.md`, `plan.md`, `tasks.md`, and the optional `research.md`,
`data-model.md`, `quickstart.md`, `contracts/`.

### Important: the scripts scaffold, the agent authors

`create-new-feature` creates the directory and copies the **unfilled**
template. `setup-plan` and `setup-tasks` resolve the template and print it.
The **agent** then writes the real content into `spec.md` / `plan.md` /
`tasks.md`. That is why `/plan` is the primary entry point in this
repository: it wires the agent to these templates.

### Current feature pointer

`create-new-feature` writes `.specify/feature.json` (machine-local, git
ignored) and exports `SPECIFY_FEATURE` / `SPECIFY_FEATURE_DIRECTORY`. Later
scripts resolve the active feature from that pointer. Set
`SPECIFY_FEATURE_DIRECTORY` explicitly to override it, or
`SPECIFY_FEATURE_NO_PERSIST=1` to prevent the pointer from being written.

## No agent integration is installed

`.specify/integration.json` records `integration: "none"`, which means the
Spec Kit **slash commands** (`/speckit.specify`, `/speckit.plan`,
`/speckit.tasks`, `/speckit.implement`) are **not** available in this
repository — the templates and the error messages in the vendored scripts
therefore point at `/plan`, which *is* available everywhere.

To install an agent integration (and unlock the `/speckit.*` commands):

```bash
uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration claude --script sh
```

## Verification

```bash
python3 scripts/verify-specify-integrity.py   # vendored files match their checksums
```
