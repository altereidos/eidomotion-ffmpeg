#!/usr/bin/env python3
"""Replace host-specific prefixes in generated native build config files."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("--replace", action="append", default=[], metavar="PREFIX=TOKEN")
    args = parser.parse_args()

    content = args.file.read_text(encoding="utf-8")
    replacements: list[tuple[str, str]] = []
    for item in args.replace:
        prefix, separator, token = item.partition("=")
        if not separator or not prefix or not token:
            parser.error(f"invalid replacement {item!r}; expected PREFIX=TOKEN")
        replacements.append((prefix, token))
    for prefix, token in sorted(replacements, key=lambda pair: len(pair[0]), reverse=True):
        content = content.replace(prefix, token)
    args.file.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
