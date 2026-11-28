#!/usr/bin/env python3
"""
Multi-Stage Code-Block Aware Markdown Link & Anchor Validator.

Features:
1. Strips multi-line fenced code blocks (```...``` and ~~~...~~~) preserving line counts.
2. Strips inline code spans (`...`) to prevent dummy examples from triggering false positives.
3. Strips HTML comments (<!--...-->) preserving line counts.
4. Extracts Markdown links, direct paths, and link definitions.
5. Verifies local file existence (case-insensitive on Windows, case-sensitive on POSIX).
6. Computes GitHub-compatible heading slugs and verifies anchor references.
7. Returns exit code 0 on 100% clean links, exit code 1 if dead links exist.
"""

import os
import re
import sys
import urllib.parse
from pathlib import Path

# Directories to ignore during scanning
EXCLUDED_DIRS = {
    ".git",
    "node_modules",
    "vendor",
    "dist",
    "build",
    "out",
    "target",
    ".venv",
    "venv",
    "env",
    "ENV",
    "__pycache__",
    ".cache",
    ".pytest_cache",
    "temp",
    "tmp",
    "sandbox",
    ".sandbox",
}

# External URL protocols to skip
EXTERNAL_SCHEMES = (
    "http://",
    "https://",
    "mailto:",
    "ftp://",
    "ssh://",
    "git://",
    "tel:",
    "data:",
)


def is_excluded_path(path: Path, project_root: Path | None = None) -> bool:
    """True when the path sits inside an excluded directory.

    The components are matched RELATIVE to the project root. Matching the
    absolute path components meant that a checkout living under /tmp or
    /temp had every file excluded: the suite reported "Scanning 0 Markdown
    files ... 100% of links resolved successfully" — a vacuous pass that
    looks exactly like a green run.
    """
    if project_root is not None:
        try:
            parts = path.relative_to(project_root).parts
        except ValueError:
            parts = path.parts
    else:
        parts = path.parts
    for part in parts:
        if part in EXCLUDED_DIRS or part.startswith("boilerplate_smoke_"):
            return True
    return False


def strip_code_blocks(text: str) -> str:
    """
    Strips fenced code blocks and HTML comments while preserving newline count.
    Strips inline code spans replacing them with spaces of equal length.
    """
    # 1. Strip fenced code blocks: ```...``` or ~~~...~~~
    def replace_fenced(match):
        newlines = match.group(0).count("\n")
        return "\n" * newlines

    fenced_pattern = re.compile(r"(?:```|~~~)[^\n]*\n[\s\S]*?(?:```|~~~)[^\n]*", re.MULTILINE)
    text = fenced_pattern.sub(replace_fenced, text)

    # 2. Strip HTML comments: <!-- ... -->
    def replace_comments(match):
        newlines = match.group(0).count("\n")
        return "\n" * newlines

    comment_pattern = re.compile(r"<!--[\s\S]*?-->", re.MULTILINE)
    text = comment_pattern.sub(replace_comments, text)

    # 3. Strip inline code spans: `...`
    def replace_inline(match):
        # Replace non-newline chars with spaces
        span_len = len(match.group(0))
        return " " * span_len

    inline_pattern = re.compile(r"`[^`\n]+`")
    text = inline_pattern.sub(replace_inline, text)

    return text


def github_slugify(heading_text: str) -> str:
    """
    Generates a GitHub-compatible heading slug.
    1. Strip links [text](url) -> text
    2. Strip markdown formatting (*, _, `, etc.)
    3. Strip HTML tags
    4. Lowercase
    5. Remove characters other than letters, numbers, hyphens, underscores, spaces
    6. Replace spaces with hyphens
    """
    text = heading_text.strip()
    # Strip markdown link syntax: [foo](bar) -> foo
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Strip HTML tags
    text = re.sub(r"<[^>]+>", "", text)
    # Strip inline code ticks, bold, italics
    text = text.replace("`", "").replace("**", "").replace("*", "").replace("__", "")
    text = text.lower()
    # Remove chars not in [a-z0-9 _-]
    text = re.sub(r"[^\w\s-]", "", text)
    # Replace spaces with hyphens
    slug = text.replace(" ", "-")
    return slug


def extract_headings(file_path: Path) -> set:
    """Extracts all heading slugs from a markdown file."""
    slugs = set()
    slug_counts = {}

    try:
        content = file_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return slugs

    stripped = strip_code_blocks(content)
    heading_pattern = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)

    for match in heading_pattern.finditer(stripped):
        heading_text = match.group(2).strip()
        base_slug = github_slugify(heading_text)
        if not base_slug:
            continue

        # GitHub handles duplicate headings by appending -1, -2, etc.
        count = slug_counts.get(base_slug, 0)
        slug_counts[base_slug] = count + 1
        if count == 0:
            final_slug = base_slug
        else:
            final_slug = f"{base_slug}-{count}"

        slugs.add(final_slug)
        # Also add collapsed hyphen version if different (e.g. "a--b" -> "a-b")
        collapsed = re.sub(r"-+", "-", final_slug)
        if collapsed != final_slug:
            slugs.add(collapsed)

    return slugs


def extract_links_from_text(content: str, file_path: Path):
    """
    Extracts markdown links and reference definitions from stripped content.
    Returns list of dicts: {'line': int, 'text': str, 'target': str}
    """
    links = []
    lines = content.splitlines()

    # Pattern 1: Inline links: [text](target)
    inline_link_pattern = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
    # Pattern 2: Reference link definitions: [label]: target
    ref_def_pattern = re.compile(r"^\s*\[([^\]]+)\]:\s*(\S+)")

    for line_idx, line in enumerate(lines, start=1):
        # Find inline links
        for match in inline_link_pattern.finditer(line):
            link_text = match.group(1).strip()
            raw_target = match.group(2).strip()
            links.append({"line": line_idx, "text": link_text, "target": raw_target})

        # Find reference definitions
        ref_match = ref_def_pattern.match(line)
        if ref_match:
            links.append({
                "line": line_idx,
                "text": ref_match.group(1).strip(),
                "target": ref_match.group(2).strip()
            })

    return links


def validate_markdown_links(project_root: Path) -> list:
    """
    Scans project_root for markdown files and verifies all internal links and anchors.
    Returns list of error dicts.
    """
    errors = []
    heading_cache = {}  # file_path -> set of slugs

    md_files = []
    for root, dirs, files in os.walk(project_root):
        # Exclude directories in-place
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS and not d.startswith("boilerplate_smoke_")]
        for f in files:
            if f.endswith(".md") or f.endswith(".markdown"):
                md_path = Path(root) / f
                if not is_excluded_path(md_path, project_root):
                    md_files.append(md_path)

    print(f"[INFO] Scanning {len(md_files)} Markdown files across {project_root}...")

    total_links_checked = 0

    for md_file in md_files:
        try:
            content = md_file.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            errors.append({
                "file": str(md_file.relative_to(project_root)),
                "line": 0,
                "text": "READ_ERROR",
                "target": str(md_file),
                "reason": f"Could not read file: {e}",
            })
            continue

        stripped_content = strip_code_blocks(content)
        links = extract_links_from_text(stripped_content, md_file)

        for item in links:
            raw_target = item["target"]
            line_no = item["line"]
            link_text = item["text"]

            # Filter external schemes
            if any(raw_target.startswith(scheme) for scheme in EXTERNAL_SCHEMES):
                continue

            # Filter template variables or placeholders
            if "${" in raw_target or "{{" in raw_target or "<" in raw_target:
                continue

            # Strip optional title in link e.g. [text](url "title")
            target_parts = raw_target.split(None, 1)
            target = target_parts[0] if target_parts else raw_target

            # Unquote URL encoding
            target = urllib.parse.unquote(target)

            total_links_checked += 1

            # Split path and anchor
            if "#" in target:
                path_part, anchor_part = target.split("#", 1)
            else:
                path_part, anchor_part = target, ""

            # Resolve target path
            if not path_part:
                # Same-file anchor link
                target_file = md_file
            else:
                # Relative or root-relative path
                # Remove leading slash if project-root relative
                cleaned_path = path_part.lstrip("/")
                if path_part.startswith("/"):
                    resolved_target = (project_root / cleaned_path).resolve()
                else:
                    resolved_target = (md_file.parent / path_part).resolve()

                target_file = resolved_target

                if not target_file.exists():
                    errors.append({
                        "file": str(md_file.relative_to(project_root)),
                        "line": line_no,
                        "text": link_text,
                        "target": raw_target,
                        "reason": f"Target file does not exist: {path_part}",
                    })
                    continue

            # Validate anchor if present
            if anchor_part:
                # Normalize anchor
                anchor_slug = anchor_part.strip().lower()
                # Skip numeric or empty anchor
                if not anchor_slug:
                    continue

                if target_file.is_file() and target_file.suffix.lower() in [".md", ".markdown"]:
                    if target_file not in heading_cache:
                        heading_cache[target_file] = extract_headings(target_file)

                    valid_slugs = heading_cache[target_file]
                    # Check anchor_slug, or collapsed version
                    collapsed_anchor = re.sub(r"-+", "-", anchor_slug)
                    if anchor_slug not in valid_slugs and collapsed_anchor not in valid_slugs:
                        errors.append({
                            "file": str(md_file.relative_to(project_root)),
                            "line": line_no,
                            "text": link_text,
                            "target": raw_target,
                            "reason": f"Heading anchor '#{anchor_part}' not found in {target_file.name}",
                        })

    print(f"[INFO] Verified {total_links_checked} internal links and anchors.")
    return errors


def main():
    project_root = Path(__file__).resolve().parent.parent
    if len(sys.argv) > 1:
        project_root = Path(sys.argv[1]).resolve()

    print("============================================================")
    print("   Markdown Link & Anchor Integrity Verification Suite      ")
    print("============================================================")
    print(f"[INFO] Project root: {project_root}")

    errors = validate_markdown_links(project_root)

    if errors:
        print("\n[ERROR] Found dead links or broken anchors:")
        print("-" * 80)
        print(f"{'Source File':<30} | {'Line':<5} | {'Target':<35} | {'Reason'}")
        print("-" * 80)
        for err in errors:
            print(f"{err['file']:<30} | {err['line']:<5} | {err['target']:<35} | {err['reason']}")
        print("-" * 80)
        print(f"[FAIL] {len(errors)} broken link(s) detected.\n")
        sys.exit(1)
    else:
        print("\n[OK] 100% of Markdown links and anchors resolved successfully.\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
