#!/usr/bin/env python3
"""Mask DLP-triggering runs in a Claude Code session log. Prints metadata only, never content."""
import argparse
import glob
import json
import os
import re
import sys

OPAQUE = re.compile(r"[A-Za-z0-9+/=_-]{40,}")


def is_opaque(run):
    # Runs without both a digit and a letter are directory names or dashes, not IDs.
    if not (re.search(r"\d", run) and re.search(r"[A-Za-z]", run)):
        return False
    # A file path splits into short segments; base64 has a long segment or + and = padding.
    if "/" in run and "+" not in run and "=" not in run:
        return max(len(seg) for seg in run.split("/")) >= 40
    return True


def mask(text):
    return OPAQUE.sub(lambda m: "<ID>" if is_opaque(m.group(0)) else m.group(0), text)


def transform(obj):
    if isinstance(obj, dict):
        # Thinking signatures must stay intact or the API rejects the resumed history.
        return {k: (v if k == "signature" else transform(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [transform(v) for v in obj]
    if isinstance(obj, str):
        return mask(obj)
    return obj


def count_runs(obj):
    if isinstance(obj, dict):
        return sum(count_runs(v) for k, v in obj.items() if k != "signature")
    if isinstance(obj, list):
        return sum(count_runs(v) for v in obj)
    if isinstance(obj, str):
        return sum(1 for r in OPAQUE.findall(obj) if is_opaque(r))
    return 0


def find_session(session_id):
    pattern = os.path.expanduser(f"~/.claude/projects/*/{session_id}.jsonl")
    matches = glob.glob(pattern)
    if len(matches) != 1:
        sys.exit(f"expected one log for {session_id}, found {len(matches)}")
    return matches[0]


def tool_uses(records):
    uses = {}
    for i, rec in enumerate(records, 1):
        content = (rec.get("message") or {}).get("content")
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "tool_use":
                    inp = json.dumps(part.get("input"), ensure_ascii=False)
                    uses[part.get("id")] = (i, part.get("name"), mask(inp)[:400])
    return uses


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session_id")
    ap.add_argument("--out-dir", default="/tmp/claude-502")
    args = ap.parse_args()

    src = find_session(args.session_id)
    with open(src) as f:
        lines = f.readlines()
    records = [json.loads(line) for line in lines]
    uses = tool_uses(records)

    out_lines = []
    changed = 0
    print(f"log: {src}")
    print(f"records: {len(records)}")
    for i, (line, rec) in enumerate(zip(lines, records), 1):
        scanned = {k: rec[k] for k in ("message", "toolUseResult") if k in rec}
        runs = count_runs(scanned)
        if not runs:
            out_lines.append(line if line.endswith("\n") else line + "\n")
            continue
        changed += 1
        new = dict(rec)
        new.update(transform(scanned))
        out_lines.append(json.dumps(new, ensure_ascii=False) + "\n")
        print(f"line {i}: type={rec.get('type')} runs={runs}")
        content = (rec.get("message") or {}).get("content")
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "tool_result":
                    use = uses.get(part.get("tool_use_id"))
                    if use:
                        print(f"  from line {use[0]} {use[1]}: {use[2]}")

    left = sum(count_runs({k: json.loads(l).get(k) for k in ("message", "toolUseResult")})
               for l in out_lines)
    base = os.path.basename(src)[:-len(".jsonl")]
    clean = os.path.join(args.out_dir, f"{base}-clean.jsonl")
    backup = os.path.join(args.out_dir, f"{base}-backup.jsonl")
    with open(clean, "w") as f:
        f.writelines(out_lines)
    print(f"changed records: {changed}")
    print(f"opaque runs left: {left}")
    print(f"clean copy: {clean}")
    print(f"install: cp {src} {backup} && cp {clean} {src}")


if __name__ == "__main__":
    main()
