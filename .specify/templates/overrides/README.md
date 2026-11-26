# Template Overrides

Any template in this directory **replaces** the corresponding core template
from `.specify/templates/`.

Resolution order (highest priority first):

1. `.specify/templates/overrides/<name>.md`   ← this directory
2. `.specify/presets/<preset-id>/templates/`
3. `.specify/extensions/<ext-id>/templates/`
4. `.specify/templates/<name>.md`              ← upstream core templates

The override file must be named exactly like the template it replaces, e.g.
`spec-template.md`, `plan-template.md`, `tasks-template.md`,
`checklist-template.md`, `constitution-template.md`.

Overridden templates are intentionally **not** tracked in
`.specify/integrations/speckit.manifest.json` — they are project-local
customisations, not part of the vendored upstream engine.
