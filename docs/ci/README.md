# Continuous integration

The workflow for this repo lives here: [`ci.yml`](ci.yml).

It runs the same checks you run locally — the 10-suite verification runner,
`npm test`, `npm run lint` and `npm run typecheck` — on Linux and on Windows,
on every push to `main` and on every pull request.

## Activating it

Copy the file to `.github/workflows/ci.yml` and push:

```bash
cp docs/ci/ci.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "ci: run the verification suite on Linux and Windows"
git push
```

Then add the status badge back to the top of the README:

```markdown
[![CI](https://github.com/ur-sriram/boilerplate/actions/workflows/ci.yml/badge.svg)](https://github.com/ur-sriram/boilerplate/actions/workflows/ci.yml)
```

## Why it is not in `.github/workflows/` yet

GitHub refuses any change to a file under `.github/workflows/` from a token
without the `workflow` scope — that check applies to `git push` and to every
REST API route alike. The file is staged here so it is ready to activate with
one copy.

## What the workflow needs

| Requirement | Why |
|---|---|
| Node.js 22 | `npm test`, `npm run lint`, `npm run typecheck` and the 400-line cap |
| Python 3.11 | the Python verification suites (`verify-links.py`, `verify-adapters.py`, …) |
| `uv` / `uvx` (optional) | only the MCP-server boot check; missing tools are a warning, not a failure |

No secrets are needed: the suite runs entirely on the checkout.
