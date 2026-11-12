"""Report which path:line anchors GitHub accepts for an inline PR review comment.

Usage: python3 -I diff_lines.py <diff.patch> <path:line> [<path:line> ...]
Prints "<path:line> ok" when the line is an added or context line on the new
side of a hunk, otherwise "<path:line> not-in-diff".
"""

import re
import sys


def commentable_lines(patch_path):
    lines = {}
    path = None
    new_line = 0
    with open(patch_path, encoding="utf-8", errors="replace") as patch:
        for raw in patch:
            if raw.startswith("+++ "):
                path = raw[6:].rstrip("\n") if raw.startswith("+++ b/") else None
                lines.setdefault(path, set())
                continue
            hunk = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
            if hunk:
                new_line = int(hunk.group(1))
                continue
            if path is None or raw.startswith(("diff ", "index ", "--- ")):
                continue
            if raw.startswith("+") or raw.startswith(" "):
                lines[path].add(new_line)
                new_line += 1
    return lines


def main():
    patch_path, *anchors = sys.argv[1:]
    lines = commentable_lines(patch_path)
    for anchor in anchors:
        path, _, line = anchor.rpartition(":")
        ok = line.isdigit() and int(line) in lines.get(path, set())
        print(f"{anchor} {'ok' if ok else 'not-in-diff'}")


if __name__ == "__main__":
    main()
