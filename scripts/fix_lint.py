#!/usr/bin/env python3
"""Apply lint fixes using a JSON log file.

Expected input format:
{
  "mistakes": [
    {
      "filename": "vala/src/file.vala",
      "line": 10,
      "column": 3,
      "level": "error",
      "message": "...",
      "ruleId": "space-before-paren"
    }
  ]
}

This script focuses on deterministic, low-risk fixes:
- use-of-tabs
- trailing-whitespace
- space-before-paren
- ellipsis
- line-length (best effort, line split at commas)
"""

from __future__ import annotations

import argparse
import json
import os
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple


@dataclass(frozen=True)
class Mistake:
    filename: str
    line: int
    column: int
    level: str
    message: str
    rule_id: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fix lint errors from a JSON report.")
    parser.add_argument(
        "--log",
        default="lint.json",
        help="Path to lint JSON report (default: lint.json)",
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root (default: current directory)",
    )
    parser.add_argument(
        "--line-length",
        type=int,
        default=120,
        help="Maximum line length for best-effort wrapping (default: 120)",
    )
    parser.add_argument(
        "--tab-width",
        type=int,
        default=4,
        help="Spaces used to replace tab characters (default: 4)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing files",
    )
    return parser.parse_args()


def normalize_path(raw: str) -> str:
    path = raw.strip()
    while path.startswith("./"):
        path = path[2:]
    if path.startswith(".vala/"):
        path = "vala/" + path[len(".vala/") :]
    return path


def load_mistakes(log_path: Path) -> List[Mistake]:
    try:
        data = json.loads(log_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"Log file not found: {log_path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {log_path}: {exc}")

    if isinstance(data, dict):
        items = data.get("mistakes", [])
    elif isinstance(data, list):
        items = data
    else:
        raise SystemExit("Unsupported lint JSON format: expected object or list")

    mistakes: List[Mistake] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        filename = normalize_path(str(item.get("filename", "")).strip())
        if not filename:
            continue
        try:
            line = int(item.get("line", 0))
            column = int(item.get("column", 1))
        except (TypeError, ValueError):
            continue
        rule_id = str(item.get("ruleId", "")).strip()
        if not rule_id:
            continue
        mistakes.append(
            Mistake(
                filename=filename,
                line=max(1, line),
                column=max(1, column),
                level=str(item.get("level", "")).strip(),
                message=str(item.get("message", "")).strip(),
                rule_id=rule_id,
            )
        )
    return mistakes


def rule_key_order(rule_id: str) -> int:
    # Apply whitespace normalization first, then targeted syntax spacing, then wrapping.
    order = {
        "use-of-tabs": 0,
        "trailing-whitespace": 1,
        "ellipsis": 2,
        "space-before-paren": 3,
        "line-length": 4,
    }
    return order.get(rule_id, 99)


def fix_space_before_paren(line: str) -> str:
    # Convert foo( -> foo ( and also generic/cast closers >( -> > (
    # to satisfy lints such as typeof(string) and HashTable<K, V>(...).
    updated = re.sub(r"([A-Za-z_][A-Za-z0-9_\.]*)\(", r"\1 (", line)
    updated = re.sub(r"([>\]\)])\(", r"\1 (", updated)
    return updated


def fix_line_length(line: str, max_len: int) -> List[str]:
    if len(line) <= max_len:
        return [line]

    indent_match = re.match(r"\s*", line)
    indent = indent_match.group(0) if indent_match else ""

    cutoff = max_len
    break_candidates = [
        line.rfind(", ", 0, cutoff),
        line.rfind(" + ", 0, cutoff),
        line.rfind(" && ", 0, cutoff),
        line.rfind(" || ", 0, cutoff),
    ]
    split_at = max(break_candidates)

    if split_at <= len(indent) + 8:
        # Fallback: split long string literal by concatenation.
        first_quote = line.find('"')
        last_quote = line.rfind('"')
        if first_quote >= 0 and last_quote > first_quote + 1:
            available = max_len - (first_quote + 2)
            if available > 20:
                content = line[first_quote + 1 : last_quote]
                split_pos = content.rfind(" ", 0, available)
                if split_pos > 10:
                    left_content = content[:split_pos]
                    right_content = content[split_pos + 1 :]
                    left = line[: first_quote + 1] + left_content + '" +'
                    right = (
                        indent
                        + " " * 4
                        + '"'
                        + right_content
                        + '"'
                        + line[last_quote + 1 :]
                    )
                    return [left.rstrip(), right.rstrip()]
        return [line]

    if line[split_at : split_at + 2] == ", ":
        left = line[: split_at + 1].rstrip()
        right = line[split_at + 2 :].lstrip()
    else:
        left = line[: split_at + 2].rstrip()
        right = line[split_at + 3 :].lstrip()

    if not right:
        return [line]

    continuation = indent + " " * 4 + right
    return [left, continuation]


def apply_fixes_to_file(
    file_path: Path,
    mistakes: List[Mistake],
    max_len: int,
    tab_width: int,
) -> Tuple[bool, Dict[str, int]]:
    stats: Dict[str, int] = defaultdict(int)
    if not file_path.exists() or not file_path.is_file():
        stats["missing-files"] += 1
        return False, stats

    lines = file_path.read_text(encoding="utf-8").splitlines(keepends=False)

    # Work from bottom to top to keep line references stable when splitting lines.
    sorted_mistakes = sorted(
        mistakes,
        key=lambda m: (m.line, rule_key_order(m.rule_id), m.column),
        reverse=True,
    )

    changed = False

    for m in sorted_mistakes:
        idx = m.line - 1
        if idx < 0 or idx >= len(lines):
            stats["out-of-range"] += 1
            continue

        original = lines[idx]
        updated = original

        if m.rule_id == "use-of-tabs":
            updated = updated.replace("\t", " " * tab_width)
        elif m.rule_id == "trailing-whitespace":
            updated = updated.rstrip()
        elif m.rule_id == "ellipsis":
            updated = updated.replace("...", "…")
        elif m.rule_id == "space-before-paren":
            updated = fix_space_before_paren(updated)
        elif m.rule_id == "line-length":
            wrapped = fix_line_length(updated, max_len)
            if len(wrapped) > 1:
                lines[idx : idx + 1] = wrapped
                changed = True
                stats[m.rule_id] += 1
            continue
        else:
            stats["unsupported-rules"] += 1
            continue

        if updated != original:
            lines[idx] = updated
            changed = True
            stats[m.rule_id] += 1

    if changed:
        file_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return changed, stats


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    log_path = Path(args.log)
    if not log_path.is_absolute():
        log_path = (root / log_path).resolve()

    mistakes = load_mistakes(log_path)
    if not mistakes:
        print("No mistakes found in lint log.")
        return 0

    by_file: Dict[str, List[Mistake]] = defaultdict(list)
    for m in mistakes:
        by_file[m.filename].append(m)

    total_stats: Dict[str, int] = defaultdict(int)
    changed_files = 0

    for rel_path, file_mistakes in sorted(by_file.items()):
        file_path = (root / rel_path).resolve()

        if args.dry_run:
            print(f"[DRY RUN] Would process: {rel_path} ({len(file_mistakes)} issues)")
            continue

        changed, stats = apply_fixes_to_file(
            file_path=file_path,
            mistakes=file_mistakes,
            max_len=args.line_length,
            tab_width=args.tab_width,
        )
        if changed:
            changed_files += 1
        for key, value in stats.items():
            total_stats[key] += value

    print(f"Processed files: {len(by_file)}")
    print(f"Changed files: {changed_files}")
    if total_stats:
        print("Applied fixes:")
        for key in sorted(total_stats.keys()):
            print(f"  {key}: {total_stats[key]}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
