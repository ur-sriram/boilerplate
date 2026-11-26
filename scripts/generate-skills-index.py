#!/usr/bin/env python3
"""Regenerate .agents/rules/skills-index.md — the canonical skill wiring map.

Why a generator:
  The index was a hand-maintained INVENTORY with no governing-rule column,
  so the constitutional invariant "every skill is mapped to at least one
  governing rule" (see .specify/memory/constitution.md, Principle VI) was
  unenforceable, and the old test in test-bootstrap.sh passed vacuously.

This script makes the mapping explicit, deterministic and reviewable:

    python3 scripts/generate-skills-index.py            # rewrite the index
    python3 scripts/generate-skills-index.py --check    # verify it is current

Rules:
  * "Skill Name" is ALWAYS the frontmatter `name` (runtime resolves by it),
  * "Canonical Path" is the real path on disk,
  * "Governing Rule" is a relative link to a rule file in .agents/rules/,
  * "Status" marks work-in-progress skills that are not production-ready.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_ROOT = REPO_ROOT / ".agents" / "skills"
RULES_DIR = REPO_ROOT / ".agents" / "rules"
INDEX_PATH = RULES_DIR / "skills-index.md"

RULE_FILES = [
    "automation.md",
    "code-quality.md",
    "codebase-exploration.md",
    "core-invariants.md",
    "mcp-codemode.md",
    "planning-standards.md",
    "ui-standards.md",
]

# Governing rule per category, used as the default for a skill whose
# specific mapping is not listed in SKILL_RULE_OVERRIDES.
CATEGORY_RULE = {
    "agency-agents": "automation.md",
    "agent-skills": "planning-standards.md",
    "automation": "automation.md",
    "design": "ui-standards.md",
    "mattpocock": "code-quality.md",
    "quality": "code-quality.md",
    "superpowers": "code-quality.md",
}

# Explicit per-skill mappings. Key = path relative to .agents/skills.
SKILL_RULE_OVERRIDES = {
    # Superpowers
    "superpowers/using-git-worktrees/SKILL.md": "core-invariants.md",
    "superpowers/finishing-a-development-branch/SKILL.md": "core-invariants.md",
    "superpowers/using-superpowers/SKILL.md": "core-invariants.md",
    "superpowers/writing-plans/SKILL.md": "planning-standards.md",
    "superpowers/brainstorming/SKILL.md": "planning-standards.md",
    "superpowers/executing-plans/SKILL.md": "planning-standards.md",
    "superpowers/subagent-driven-development/SKILL.md": "planning-standards.md",
    "superpowers/dispatching-parallel-agents/SKILL.md": "planning-standards.md",
    "superpowers/writing-skills/SKILL.md": "automation.md",
    "superpowers/diagnosing-superpowers/SKILL.md": "automation.md",
    "superpowers/test-driven-development/SKILL.md": "code-quality.md",
    "superpowers/systematic-debugging/SKILL.md": "code-quality.md",
    "superpowers/verification-before-completion/SKILL.md": "code-quality.md",
    "superpowers/requesting-code-review/SKILL.md": "code-quality.md",
    "superpowers/receiving-code-review/SKILL.md": "code-quality.md",
    # Agent skills
    "agent-skills/spec-driven-development/SKILL.md": "planning-standards.md",
    "agent-skills/planning-and-task-breakdown/SKILL.md": "planning-standards.md",
    "agent-skills/idea-refine/SKILL.md": "planning-standards.md",
    "agent-skills/interview-me/SKILL.md": "planning-standards.md",
    "agent-skills/constraint-driven-development/SKILL.md": "planning-standards.md",
    "agent-skills/source-driven-development/SKILL.md": "planning-standards.md",
    "agent-skills/doubt-driven-development/SKILL.md": "planning-standards.md",
    "agent-skills/incremental-implementation/SKILL.md": "planning-standards.md",
    "agent-skills/context-engineering/SKILL.md": "automation.md",
    "agent-skills/using-agent-skills/SKILL.md": "automation.md",
    "agent-skills/test-driven-development/SKILL.md": "code-quality.md",
    "agent-skills/code-review-and-quality/SKILL.md": "code-quality.md",
    "agent-skills/code-simplification/SKILL.md": "code-quality.md",
    "agent-skills/debugging-and-error-recovery/SKILL.md": "code-quality.md",
    "agent-skills/deprecation-and-migration/SKILL.md": "code-quality.md",
    "agent-skills/documentation-and-adrs/SKILL.md": "code-quality.md",
    "agent-skills/observability-and-instrumentation/SKILL.md": "code-quality.md",
    "agent-skills/performance-optimization/SKILL.md": "code-quality.md",
    "agent-skills/security-and-hardening/SKILL.md": "code-quality.md",
    "agent-skills/shipping-and-launch/SKILL.md": "code-quality.md",
    "agent-skills/git-workflow-and-versioning/SKILL.md": "core-invariants.md",
    "agent-skills/ci-cd-and-automation/SKILL.md": "automation.md",
    "agent-skills/browser-testing-with-devtools/SKILL.md": "automation.md",
    "agent-skills/browser-use/SKILL.md": "automation.md",
    "agent-skills/frontend-ui-engineering/SKILL.md": "ui-standards.md",
    "agent-skills/accessibility-engineering/SKILL.md": "ui-standards.md",
    "agent-skills/api-and-interface-design/SKILL.md": "code-quality.md",
    # Quality / design / automation
    "quality/code-simplification/SKILL.md": "code-quality.md",
    "design/antislop/SKILL.md": "ui-standards.md",
    "design/unslop/skills/unslop/SKILL.md": "ui-standards.md",
    "design/impeccable/SKILL.md": "ui-standards.md",
    "design/taste-skill/skills/taste-skill/SKILL.md": "ui-standards.md",
    "design/motion/SKILL.md": "ui-standards.md",
    "automation/browser-harness/SKILL.md": "automation.md",
    "automation/claude-mem/SKILL.md": "automation.md",
    "automation/graphify/SKILL.md": "codebase-exploration.md",
    "automation/headroom/SKILL.md": "mcp-codemode.md",
    "automation/rtk/SKILL.md": "automation.md",
    "automation/planning-with-files/SKILL.md": "planning-standards.md",
}

# Matt Pocock skills are grouped by their upstream folder.
MATT_CATEGORY_RULE = {
    "engineering": "code-quality.md",
    "productivity": "planning-standards.md",
    "misc": "core-invariants.md",
    "in-progress": "code-quality.md",
    "deprecated": "code-quality.md",
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict[str, str]:
    """Extract `name` and `description` from YAML frontmatter.

    Supports the simple key: value and block scalar (>-, |) forms used in
    this repository without requiring a YAML dependency.
    """
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    block = match.group(1)
    data: dict[str, str] = {}
    lines = block.split("\n")
    index = 0
    while index < len(lines):
        line = lines[index]
        key_match = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$", line)
        if not key_match:
            index += 1
            continue
        key, value = key_match.group(1), key_match.group(2).strip()
        if value in (">", ">-", "|", "|-"):
            collected: list[str] = []
            index += 1
            while index < len(lines) and (
                lines[index].startswith("  ") or not lines[index].strip()
            ):
                collected.append(lines[index].strip())
                index += 1
            data[key] = " ".join(part for part in collected if part).strip()
            continue
        data[key] = value.strip().strip('"').strip("'")
        index += 1
    return data


def rule_for(rel_path: str, category: str) -> str:
    if rel_path in SKILL_RULE_OVERRIDES:
        return SKILL_RULE_OVERRIDES[rel_path]
    if category == "mattpocock":
        parts = rel_path.split("/")
        if len(parts) > 2 and parts[1] in MATT_CATEGORY_RULE:
            return MATT_CATEGORY_RULE[parts[1]]
    return CATEGORY_RULE.get(category, "automation.md")


def status_for(rel_path: str) -> str:
    if "/in-progress/" in f"/{rel_path}" or rel_path.startswith("in-progress/"):
        return "WIP"
    return "Active"


def collect() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for skill_file in sorted(SKILLS_ROOT.rglob("SKILL.md")):
        rel = skill_file.relative_to(SKILLS_ROOT).as_posix()
        category = rel.split("/")[0]
        front = parse_frontmatter(skill_file.read_text(encoding="utf-8", errors="replace"))
        name = front.get("name") or skill_file.parent.name
        description = front.get("description") or ""
        description = re.sub(r"\s+", " ", description).strip()
        rows.append(
            {
                "name": name,
                "category": category,
                "rel": rel,
                "rule": rule_for(rel, category),
                "status": status_for(rel),
                "description": description,
            }
        )
    return rows


def render(rows: list[dict[str, str]]) -> str:
    lines = [
        "# Skills Index & Autonomous Discovery Map",
        "",
        "> **Layer 2 Modular Rule** | Scope: Universal Skill Store (`.agents/skills/`)",
        "",
        "## Complete Skill Inventory & Rule Wiring Map",
        "",
        "Every skill in the canonical store is mapped to exactly one governing rule file.",
        "The `Governing Rule` column is the mapping the constitution requires",
        "(*Principle VI — Single Canonical Skill Store & 100% Rule Wiring Map*).",
        "",
        "| Skill Name | Category | Canonical Path | Governing Rule | Status | Description |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        path_link = f"../../.agents/skills/{row['rel']}"
        rule_link = f"[{row['rule']}]({row['rule']})"
        description = row["description"].replace("|", "\\|")
        if len(description) > 110:
            description = description[:107].rstrip() + "..."
        lines.append(
            f"| {row['name']} | {row['category']} | "
            f"[.agents/skills/{row['rel']}]({path_link}) | {rule_link} | "
            f"{row['status']} | {description} |"
        )
    lines.append("")
    lines.append("## How To Use This Map")
    lines.append("")
    lines.append("1. **Discovery**: match the task description in your prompt against the")
    lines.append("   `Description` column, then load the skill at the `Canonical Path`.")
    lines.append("2. **Governance**: the `Governing Rule` is the Layer 2 rule that constrains")
    lines.append("   how the skill must be applied. Load it before using the skill.")
    lines.append("3. **Status**: `WIP` skills are upstream work-in-progress and are")
    lines.append("   indexed for discovery, but are not production-approved.")
    lines.append("")
    lines.append("This file is generated — run `python3 scripts/generate-skills-index.py`")
    lines.append("after adding, renaming or removing a skill.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Regenerate the skills wiring map.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when the on-disk index differs from the generated one.",
    )
    args = parser.parse_args()

    missing_rules = [r for r in RULE_FILES if not (RULES_DIR / r).exists()]
    if missing_rules:
        print(f"[FAIL] Missing rule files: {missing_rules}", file=sys.stderr)
        return 1

    rows = collect()
    if not rows:
        print("[FAIL] No skills found.", file=sys.stderr)
        return 1

    content = render(rows)

    if args.check:
        current = INDEX_PATH.read_text(encoding="utf-8") if INDEX_PATH.exists() else ""
        if current != content:
            print(
                "[FAIL] skills-index.md is out of date. "
                "Run: python3 scripts/generate-skills-index.py",
                file=sys.stderr,
            )
            return 1
        print(f"[PASS] skills-index.md is current ({len(rows)} skills wired).")
        return 0

    INDEX_PATH.write_text(content, encoding="utf-8")
    print(f"[OK] Wrote {INDEX_PATH.relative_to(REPO_ROOT)} ({len(rows)} skills wired).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
