#!/usr/bin/env python3
"""Verify the UI integration contracts.

The shadcn / ui-registry / Astryx integration was, for a long time, a set of
plausible-looking strings that nothing ever validated. `components.json` named
three registries that the shadcn CLI rejected outright, one of which pointed
at a domain that does not serve TLS; `src/app/globals.css` had no CSS
variables, so every installed component would have rendered unstyled; and
`tsconfig.json` had no path aliases, so `npx shadcn add` dropped components
into a literal directory named `@`.

None of that was caught, because no suite looked at any of it.

This suite asserts the local contracts:

  * `components.json` parses, and its `registries` block uses the namespace
    form the shadcn schema requires (keys starting with `@`, URLs containing
    the `{name}` placeholder).
  * The stylesheet `components.json` points at exists and declares the shadcn
    theme variables and the `@theme inline` mapping.
  * The Tailwind configuration path is either empty (Tailwind v4, where the
    stylesheet is the configuration) or points at a file that exists.
  * `tsconfig.json` maps every alias declared in `components.json`.
  * `src/lib/utils.ts` exports the `cn()` helper the components import.

Live registry reachability is opt-in with `--network`, because the default
suite must stay offline and deterministic.

Usage:
    python3 scripts/verify-ui-contracts.py            # local contracts only
    python3 scripts/verify-ui-contracts.py --network  # also probe the registries
"""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# The CSS custom properties a shadcn theme must declare. These are the
# variables the installed components resolve their utility classes against.
REQUIRED_CSS_VARIABLES = [
    "--background",
    "--foreground",
    "--card",
    "--card-foreground",
    "--popover",
    "--popover-foreground",
    "--primary",
    "--primary-foreground",
    "--secondary",
    "--secondary-foreground",
    "--muted",
    "--muted-foreground",
    "--accent",
    "--accent-foreground",
    "--destructive",
    "--border",
    "--input",
    "--ring",
    "--radius",
]

# Tailwind utility names that must resolve to the theme variables above.
REQUIRED_THEME_MAPPINGS = [
    "--color-background",
    "--color-foreground",
    "--color-primary",
    "--color-primary-foreground",
    "--color-card",
    "--color-popover",
    "--color-border",
    "--color-input",
    "--color-ring",
]

# The aliases the shadcn CLI uses to place an installed component.
REQUIRED_ALIASES = ["components", "utils", "ui", "lib", "hooks"]


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def check_components_json(errors: list[str]) -> dict:
    """Validate the shadcn contract file itself."""
    path = REPO_ROOT / "components.json"
    if not path.exists():
        fail("components.json is missing", errors)
        return {}

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"components.json is not valid JSON: {exc}", errors)
        return {}

    registries = data.get("registries") or {}
    if not isinstance(registries, dict):
        fail("components.json: 'registries' must be an object", errors)
        return data

    for name, url in registries.items():
        # The shadcn schema declares `patternProperties: {"^@": ...}` with
        # `additionalProperties: false`, so a namespace without the `@` prefix
        # makes the CLI reject the whole file.
        if not name.startswith("@"):
            fail(
                f"components.json: registry '{name}' must be namespaced as '@{name}' "
                "(the shadcn schema rejects registry keys without '@')",
                errors,
            )
        if not isinstance(url, str) or "{name}" not in url:
            fail(
                f"components.json: registry '{name}' URL must contain the "
                f"'{{name}}' placeholder (got {url!r})",
                errors,
            )

    # The default shadcn registry is implicit in the CLI and needs no entry.
    for name in registries:
        if name in ("default", "shadcn"):
            fail(
                f"components.json: registry '{name}' must not be declared — the "
                "default shadcn registry is implicit (`npx shadcn add button`)",
                errors,
            )

    tailwind = data.get("tailwind") or {}
    css_path = tailwind.get("css")
    if not css_path:
        fail("components.json: tailwind.css is not declared", errors)
    elif not (REPO_ROOT / css_path).exists():
        fail(f"components.json: tailwind.css points at a missing file '{css_path}'", errors)

    config_path = tailwind.get("config")
    if config_path and not (REPO_ROOT / config_path).exists():
        fail(
            f"components.json: tailwind.config points at a missing file '{config_path}'",
            errors,
        )

    aliases = data.get("aliases") or {}
    for alias in REQUIRED_ALIASES:
        if alias not in aliases:
            fail(f"components.json: alias '{alias}' is not declared", errors)

    return data


def check_stylesheet(errors: list[str]) -> None:
    """The stylesheet must carry the shadcn theme, or components render raw."""
    path = REPO_ROOT / "src" / "app" / "globals.css"
    if not path.exists():
        fail("src/app/globals.css is missing", errors)
        return

    css = path.read_text(encoding="utf-8")

    for variable in REQUIRED_CSS_VARIABLES:
        if f"{variable}:" not in css:
            fail(
                f"src/app/globals.css: theme variable '{variable}' is not declared — "
                "installed components resolve their colours against it",
                errors,
            )

    for mapping in REQUIRED_THEME_MAPPINGS:
        if mapping not in css:
            fail(
                f"src/app/globals.css: '{mapping}' is not mapped — the utility it "
                "backs (e.g. bg-primary) would not exist",
                errors,
            )

    if "@import \"tailwindcss\"" not in css and "@tailwind base" not in css:
        fail(
            "src/app/globals.css: no Tailwind import found "
            "('@import \"tailwindcss\"' for v4, '@tailwind base' for v3)",
            errors,
        )


def check_tsconfig(errors: list[str]) -> None:
    """`@/*` must resolve, or `shadcn add` writes into a literal `@` folder."""
    path = REPO_ROOT / "tsconfig.json"
    if not path.exists():
        fail("tsconfig.json is missing", errors)
        return

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"tsconfig.json is not valid JSON: {exc}", errors)
        return

    options = data.get("compilerOptions") or {}
    paths = options.get("paths") or {}
    base_url = options.get("baseUrl")

    if not base_url:
        fail("tsconfig.json: 'baseUrl' is not set, so the '@/*' alias cannot resolve", errors)
    if not paths:
        fail("tsconfig.json: 'paths' is not set, so the '@/*' alias cannot resolve", errors)
        return

    if not any("@/*" in key for key in paths):
        fail(
            "tsconfig.json: no '@/*' path mapping — the shadcn CLI would install "
            "components into a literal directory named '@'",
            errors,
        )


def check_cn_helper(errors: list[str]) -> None:
    """Every installed component imports `cn` from the aliased utils module."""
    path = REPO_ROOT / "src" / "lib" / "utils.ts"
    if not path.exists():
        fail("src/lib/utils.ts is missing — the components' `cn` import cannot resolve", errors)
        return

    source = path.read_text(encoding="utf-8")
    if not re.search(r"export\s+function\s+cn\b", source):
        fail("src/lib/utils.ts does not export a `cn` function", errors)
    for dependency in ("clsx", "tailwind-merge"):
        if dependency not in source:
            fail(f"src/lib/utils.ts does not use '{dependency}'", errors)


def _fetch(url: str) -> tuple[str, str]:
    """Return (body, error). Exactly one of the two is empty."""
    # A browser-ish User-Agent is required: the default `Python-urllib/*`
    # agent is refused by the bot protection in front of the registries.
    request = urllib.request.Request(url, headers={"User-Agent": "boilerplate-ui-contracts/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8", "replace"), ""
    except urllib.error.HTTPError as exc:
        return "", f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001 - report any transport failure
        return "", str(exc)


def _registry_index(base: str) -> tuple[dict, str]:
    """Find a registry's index. shadcn registries expose it as registry.json
    or index.json; the two conventions are both in the wild."""
    for suffix in ("registry.json", "index.json"):
        body, error = _fetch(base.rstrip("/") + "/" + suffix)
        if error:
            continue
        try:
            return json.loads(body), ""
        except json.JSONDecodeError:
            continue
    return {}, f"no registry index found at {base.rstrip('/')}/registry.json or /index.json"


def probe_registry(url_template: str) -> str:
    """Fetch one real item from a registry template. Returns an error string or ''."""
    base = url_template.split("{name}")[0]
    index, error = _registry_index(base)
    if error:
        return error

    items = index.get("items") or []
    if not items:
        return "registry index lists no items"

    # Item names are registry-specific: Astryx uses `component-button`,
    # MagicUI uses `marquee`. Take a name from the index rather than guessing.
    name = items[0].get("name")
    if not name:
        return "registry index item has no name"

    body, error = _fetch(url_template.replace("{name}", name))
    if error:
        return f"item '{name}' could not be fetched: {error}"
    if '"name"' not in body:
        return f"item '{name}' did not return a registry item"
    return ""


def check_registries_live(errors: list[str]) -> None:
    """Opt-in: prove each configured registry actually serves a component."""
    try:
        data = json.loads((REPO_ROOT / "components.json").read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        fail(f"components.json could not be read for the live probe: {exc}", errors)
        return

    for name, url_template in (data.get("registries") or {}).items():
        if not isinstance(url_template, str) or "{name}" not in url_template:
            continue
        problem = probe_registry(url_template)
        if problem:
            fail(f"registry '{name}' ({url_template}) is not serving components: {problem}", errors)
        else:
            print(f"[INFO] registry '{name}' serves components: {url_template}")


def main() -> int:
    network = "--network" in sys.argv[1:]
    errors: list[str] = []

    print("[INFO] Verifying the UI integration contracts")
    print(f"[INFO] Project root: {REPO_ROOT}")

    check_components_json(errors)
    check_stylesheet(errors)
    check_tsconfig(errors)
    check_cn_helper(errors)

    if network:
        print("[INFO] Live registry probe enabled (--network)")
        check_registries_live(errors)

    print("-" * 78)
    if errors:
        for error in errors:
            print(f"[FAIL] {error}")
        print("-" * 78)
        print(f"[FAIL] UI contract verification failed with {len(errors)} error(s).")
        return 1

    print("[PASS] UI integration contracts verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
