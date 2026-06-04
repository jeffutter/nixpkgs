#!/usr/bin/env python3
"""Claude Code hook entry point: record events for permission-prompt stats.

Registered (in ~/.claude/settings.json) for these hook events:
  PermissionRequest, PermissionDenied, PostToolUse,
  UserPromptSubmit, Stop, SessionStart, SessionEnd

PostToolUse / PermissionDenied are captured so we can measure how long each
permission dialog sat unanswered: a dialog opens at PermissionRequest and is
resolved either by the tool running (PostToolUse) or being denied.

It reads the hook JSON from stdin, stamps it with the current time (hook
payloads carry no timestamp), and appends one JSON line to
  ~/.claude/permission-stats/events/<session_id>.jsonl

On SessionEnd it also writes a human-readable summary to
  ~/.claude/permission-stats/reports/<session_id>.txt

This hook is purely observational: it never writes to stdout and always exits 0,
so it cannot block a turn, alter context, or change a permission decision. Any
error is swallowed.
"""
import json
import os
import sys
import time

CAPTURED = {
    "PermissionRequest",
    "PermissionDenied",
    "PostToolUse",
    "UserPromptSubmit",
    "Stop",
    "SessionStart",
    "SessionEnd",
}

# Events for which we keep the full payload (tool_input + any extra top-level
# keys, e.g. a "reason"/"permission_suggestions" field), so we can see exactly
# why a dialog was shown. These are low-frequency, so the extra bytes are cheap.
DETAILED = {"PermissionRequest", "PermissionDenied"}

# Top-level payload keys we already capture or that are noise; everything else
# on a detailed event is stored under "extra" to surface undocumented fields
# such as the reason a prompt was triggered.
KNOWN_TOP = {
    "hook_event_name",
    "session_id",
    "cwd",
    "tool_name",
    "tool_input",
    "transcript_path",
}


def _truncate(value, limit=600):
    """Shrink large payload values so a Write/Edit prompt can't bloat the log."""
    if isinstance(value, str):
        return value if len(value) <= limit else value[:limit] + "…[truncated]"
    if isinstance(value, dict):
        return {k: _truncate(v, limit) for k, v in value.items()}
    if isinstance(value, list):
        return [_truncate(v, limit) for v in value[:50]]
    return value


def root_dir():
    override = os.environ.get("PERMISSION_STATS_DIR")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), ".claude", "permission-stats")


def append_event(events_dir, session_id, record):
    """Append one JSON line atomically (single small O_APPEND write)."""
    os.makedirs(events_dir, exist_ok=True)
    path = os.path.join(events_dir, f"{session_id}.jsonl")
    line = (json.dumps(record, separators=(",", ":")) + "\n").encode("utf-8")
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    try:
        os.write(fd, line)
    finally:
        os.close(fd)


def write_report(root, session_id):
    """Write the end-of-session summary; best-effort."""
    try:
        # report.py lives alongside this file (both deployed together via Nix);
        # the data dir (root) holds only events/ and reports/.
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import report

        text = report.report_for_session(session_id)
        reports_dir = os.path.join(root, "reports")
        os.makedirs(reports_dir, exist_ok=True)
        with open(os.path.join(reports_dir, f"{session_id}.txt"), "w") as fh:
            fh.write(text + "\n")
    except Exception:
        pass


def main():
    raw = sys.stdin.read()
    data = json.loads(raw)

    event = data.get("hook_event_name")
    if event not in CAPTURED:
        return

    session_id = data.get("session_id")
    if not session_id:
        return

    now = time.time()
    record = {
        "ts_ms": int(now * 1000),
        "iso": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now)) + f".{int((now % 1) * 1000):03d}Z",
        "event": event,
        "tool": data.get("tool_name"),
        "cwd": data.get("cwd"),
    }

    # For permission events, keep the tool input and any extra (possibly
    # undocumented) top-level fields so we can see the prompt's reason/details.
    if event in DETAILED:
        if "tool_input" in data:
            record["tool_input"] = _truncate(data.get("tool_input"))
        extra = {k: _truncate(v) for k, v in data.items() if k not in KNOWN_TOP}
        if extra:
            record["extra"] = extra

    root = root_dir()
    append_event(os.path.join(root, "events"), session_id, record)

    if event == "SessionEnd":
        write_report(root, session_id)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never break the session over a stats hook.
        pass
    sys.exit(0)
