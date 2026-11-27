# `.repo/` — vendored third-party islands

This folder holds **third-party code that ships with the boilerplate**. It is
the project-level home for vendored dependencies, so that:

- `src/features/` stays empty for the **user's own** code
  (`cp -r src/features/_template src/features/my-feature`),
- every vendored component is listed with its source, licence and pinned
  commit SHA in [`THIRD_PARTY.md`](../THIRD_PARTY.md),
- a vendored island can be replaced or removed without touching user code.

Everything here is **project-level**: nothing in `.repo/` writes outside the
project root.

## Islands

| Island | Source | Licence | What it is |
|---|---|---|---|
| [`claude-mem/`](claude-mem/) | [`thedotmack/claude-mem`](https://github.com/thedotmack/claude-mem) @ `96658712` | Apache-2.0 | Cross-session episodic memory: the store, its CLI and the redaction rules. The architecture is reimplemented locally; the upstream MCP server is **not** installed. |

## Rules for an island

1. **Dependency-free at runtime.** An island may only use Node/Python built-ins
   or things the user explicitly opts into. It must run in a fresh clone
   without an install step.
2. **Project-local by construction.** Every path it touches resolves inside
   the project root. An island never reads or writes global config.
3. **Tested and enforced.** An island ships with unit tests (`npm test`) and at
   least one check in the verification suite, so it cannot decay into a stub
   unnoticed.
4. **Documented in `THIRD_PARTY.md`.** Source URL, pinned SHA, licence, how it
   is invoked, and how it was adapted.
5. **Never edited in place.** Adapt the island inside `.repo/`, keep the
   upstream attribution, and update the pinned SHA if you re-sync it.

## Adding an island

```bash
mkdir -p .repo/<name>
# copy the upstream code in, add the licence header, then:
#   1. write the tests under .repo/<name>/
#   2. register the path in scripts/verify-adapters.py or the relevant suite
#   3. add a row to THIRD_PARTY.md
```

The `claude-mem` island is a worked example: it is invoked by the
`memory-sync` hook (`scripts/hooks/memory-sync.{sh,ps1}`), by the cross-platform
dispatcher (`scripts/hooks/run-hook.mjs`) and by the OpenCode plugin
(`.opencode/plugins/memory-sync.js`), and it round-trips an episode inside the
bootstrap sandbox (`scripts/test-bootstrap.{sh,ps1}`).
