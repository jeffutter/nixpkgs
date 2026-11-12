"""Build a GitHub PR review payload and a readable preview from markdown files.

Usage: python3 -I build_review.py <WORK> <commit id> <REQUEST_CHANGES|COMMENT|APPROVE>
Reads WORK/review-body.md and, if present, WORK/review-comments.md, where each
inline comment starts with a line "== <path>:<line> ==" followed by its markdown.
Writes WORK/review.json and WORK/review-preview.md.
"""

import json
import re
import sys
from pathlib import Path

EVENTS = {"REQUEST_CHANGES", "COMMENT", "APPROVE"}
HEADER = re.compile(r"^== (.+):(\d+) ==$")


def parse_comments(text):
    comments = []
    for line in text.splitlines():
        header = HEADER.match(line)
        if header:
            comments.append({"path": header[1], "line": int(header[2]), "side": "RIGHT", "body": []})
        elif comments:
            comments[-1]["body"].append(line)
        elif line.strip():
            sys.exit(f"text before the first '== path:line ==' header: {line!r}")
    for comment in comments:
        comment["body"] = "\n".join(comment["body"]).strip()
        if not comment["body"]:
            sys.exit(f"empty comment at {comment['path']}:{comment['line']}")
    return comments


def main():
    work, commit_id, event = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    if event not in EVENTS:
        sys.exit(f"event must be one of {sorted(EVENTS)}")
    body = (work / "review-body.md").read_text(encoding="utf-8").strip()
    comments_file = work / "review-comments.md"
    comments = parse_comments(comments_file.read_text(encoding="utf-8")) if comments_file.exists() else []

    review = {"commit_id": commit_id, "event": event, "body": body, "comments": comments}
    (work / "review.json").write_text(json.dumps(review, indent=2) + "\n", encoding="utf-8")

    preview = [f"# Draft PR review\n\nEvent: {event}. Inline comments: {len(comments)}.\n\n---\n\n{body}\n"]
    for comment in comments:
        preview.append(f"\n---\n\n### Inline: `{comment['path']}:{comment['line']}`\n\n{comment['body']}\n")
    (work / "review-preview.md").write_text("".join(preview), encoding="utf-8")
    print(f"review.json written: {event}, {len(comments)} inline comments")


if __name__ == "__main__":
    main()
