#!/usr/bin/env python3
"""Compute permission-prompt statistics for Claude Code sessions.

Reads the per-session event logs written by ``capture.py`` and reports, for a
session: the number of permission prompts, the total session duration, the
permission prompts per minute, and the average *processing* time between
permission prompts -- excluding time spent idle waiting for the user to type a
normal (non-permission) prompt.

Usage:
  report.py --latest [--json]       # most recently active session
  report.py --all [--json]          # one-line summary of every captured session
  report.py <session_id> [--json]   # a specific session
  report.py --prompts [session_id]  # list each permission prompt + its reason/command
  report.py --cleanup <days> [-n]   # delete logs older than <days> (-n = dry run)

The event-log directory defaults to ~/.claude/permission-stats/events and can be
overridden with $PERMISSION_STATS_DIR (pointing at the permission-stats root).
"""
from __future__ import annotations

import json
import os
import sys
import time

# Events we record. Permission prompts are the thing we measure; the rest let us
# subtract user-typing time and measure how long dialogs sat unanswered.
PERMISSION = "PermissionRequest"
PERMISSION_DENIED = "PermissionDenied"
POST_TOOL = "PostToolUse"
USER_PROMPT = "UserPromptSubmit"
STOP = "Stop"
SESSION_START = "SessionStart"
SESSION_END = "SessionEnd"

# Events that resolve an open permission dialog (tool ran, or was denied).
RESOLUTION = (POST_TOOL, PERMISSION_DENIED)


def root_dir() -> str:
    override = os.environ.get("PERMISSION_STATS_DIR")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), ".claude", "permission-stats")


def events_dir() -> str:
    return os.path.join(root_dir(), "events")


def load_events(path: str) -> list[dict]:
    """Read a session's JSONL event log, sorted by timestamp. Bad lines skipped."""
    events: list[dict] = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    events.sort(key=lambda e: e.get("ts_ms", 0))
    return events


def _user_idle_intervals(events: list[dict]) -> list[tuple[int, int]]:
    """Periods where Claude sat waiting for the user to type a normal prompt.

    An idle period starts at a SessionStart or Stop (Claude is done / waiting)
    and ends at the next UserPromptSubmit. Only the most recent Stop before a
    given prompt counts, so successive Stops collapse to one interval.
    """
    intervals: list[tuple[int, int]] = []
    idle_start: int | None = None
    for e in events:
        kind = e.get("event")
        ts = e.get("ts_ms", 0)
        if kind in (STOP, SESSION_START):
            idle_start = ts
        elif kind == USER_PROMPT:
            if idle_start is not None and ts > idle_start:
                intervals.append((idle_start, ts))
            idle_start = None
    return intervals


def _permission_wait_ms(events: list[dict], fallback_end: int) -> int:
    """Wall-clock time during which at least one permission dialog was open.

    A dialog opens at PermissionRequest and closes when the tool runs
    (PostToolUse) or is denied (PermissionDenied). Multiple dialogs can be open
    at once (parallel tool calls), so we track the count of open dialogs and sum
    only the spans where the count is above zero -- this is the union of the
    pending intervals, not their sum, so overlapping prompts aren't double
    counted. Resolution events while nothing is pending (auto-approved tools)
    are ignored. If the session ends with a dialog still open (you walked away),
    it's closed at the last recorded timestamp.
    """
    pending = 0
    wait_start: int | None = None
    total = 0
    for e in events:
        kind = e.get("event")
        ts = e.get("ts_ms", 0)
        if kind == PERMISSION:
            if pending == 0:
                wait_start = ts
            pending += 1
        elif kind in RESOLUTION and pending > 0:
            pending -= 1
            if pending == 0 and wait_start is not None:
                total += ts - wait_start
                wait_start = None
    if pending > 0 and wait_start is not None and fallback_end > wait_start:
        total += fallback_end - wait_start
    return total


def _overlap(a: int, b: int, intervals: list[tuple[int, int]]) -> int:
    """Total overlap (ms) of [a, b] with a list of intervals."""
    total = 0
    for s, e in intervals:
        lo, hi = max(a, s), min(b, e)
        if hi > lo:
            total += hi - lo
    return total


def compute(events: list[dict]) -> dict:
    """Compute the metrics from a session's events."""
    if not events:
        return {"empty": True}

    first_ts = events[0]["ts_ms"]
    last_ts = events[-1]["ts_ms"]

    starts = [e["ts_ms"] for e in events if e.get("event") == SESSION_START]
    ends = [e["ts_ms"] for e in events if e.get("event") == SESSION_END]
    session_start = starts[0] if starts else first_ts
    session_end = ends[-1] if ends else last_ts
    total_ms = max(0, session_end - session_start)

    perm_ts = [e["ts_ms"] for e in events if e.get("event") == PERMISSION]
    perm_count = len(perm_ts)

    idle = _user_idle_intervals(events)
    user_idle_ms = sum(b - a for a, b in idle)
    user_prompts = sum(1 for e in events if e.get("event") == USER_PROMPT)

    # Time spent with a permission dialog open and unanswered.
    perm_wait_ms = _permission_wait_ms(events, last_ts)
    avg_perm_wait_ms = (perm_wait_ms / perm_count) if perm_count else None

    minutes = total_ms / 60000.0
    prompts_per_min = (perm_count / minutes) if minutes > 0 else 0.0
    # Same rate, but measured against active (non-idle-waiting) time.
    active_ms = max(0, total_ms - user_idle_ms)
    active_minutes = active_ms / 60000.0
    prompts_per_active_min = (perm_count / active_minutes) if active_minutes > 0 else 0.0

    # Processing time between consecutive permission prompts, minus any portion
    # spent idle waiting for a normal user prompt. Time spent deciding on a
    # permission dialog itself is kept (it is permission-related).
    gaps: list[int] = []
    for a, b in zip(perm_ts, perm_ts[1:]):
        gaps.append((b - a) - _overlap(a, b, idle))
    avg_processing_ms = (sum(gaps) / len(gaps)) if gaps else None

    return {
        "empty": False,
        "permission_prompts": perm_count,
        "user_prompts": user_prompts,
        "total_ms": total_ms,
        "user_idle_ms": user_idle_ms,
        "active_ms": active_ms,
        "permission_wait_ms": perm_wait_ms,
        "avg_permission_wait_ms": avg_perm_wait_ms,
        "prompts_per_min": prompts_per_min,
        "prompts_per_active_min": prompts_per_active_min,
        "avg_processing_between_prompts_ms": avg_processing_ms,
        "session_start_ms": session_start,
        "session_end_ms": session_end,
        "completed": bool(ends),
    }


def _fmt_duration(ms: float | None) -> str:
    if ms is None:
        return "n/a"
    secs = ms / 1000.0
    if secs < 60:
        return f"{secs:.1f}s"
    m, s = divmod(int(round(secs)), 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}h{m:02d}m{s:02d}s"
    return f"{m}m{s:02d}s"


def render(stats: dict, session_id: str | None = None) -> str:
    if stats.get("empty"):
        return "No events recorded for this session."
    lines = []
    if session_id:
        lines.append(f"Session: {session_id}")
    status = "completed" if stats["completed"] else "in progress / no SessionEnd"
    lines.append(f"Status:                         {status}")
    lines.append(f"Permission prompts:             {stats['permission_prompts']}")
    lines.append(f"User prompts:                   {stats['user_prompts']}")
    lines.append(f"Total session duration:         {_fmt_duration(stats['total_ms'])}")
    lines.append(f"Time idle (awaiting user input): {_fmt_duration(stats['user_idle_ms'])}")
    lines.append(f"Active time:                    {_fmt_duration(stats['active_ms'])}")
    lines.append(
        "Time waiting at permission prompts: "
        f"{_fmt_duration(stats['permission_wait_ms'])}"
        f"  (avg {_fmt_duration(stats['avg_permission_wait_ms'])}/prompt)"
    )
    lines.append(f"Prompts per minute (total):     {stats['prompts_per_min']:.2f}")
    lines.append(f"Prompts per minute (active):    {stats['prompts_per_active_min']:.2f}")
    lines.append(
        "Avg processing between prompts: "
        f"{_fmt_duration(stats['avg_processing_between_prompts_ms'])}"
        "  (excl. non-permission user wait)"
    )
    return "\n".join(lines)


# Substrings that flag a payload field as explaining why a prompt was shown.
_REASON_HINTS = ("reason", "suggest", "rule", "explan", "message", "decision")


def _command_summary(tool, tool_input) -> str:
    """A short, human description of what a permission prompt was asking for."""
    if not isinstance(tool_input, dict):
        return ""
    if tool == "Bash" and "command" in tool_input:
        return str(tool_input["command"])
    for key in ("command", "file_path", "path", "url", "pattern", "query"):
        if key in tool_input:
            return f"{key}={tool_input[key]}"
    return ""


def _reason_fields(extra) -> dict:
    """Pull any reason-like fields out of a prompt's extra payload keys."""
    if not isinstance(extra, dict):
        return {}
    return {
        k: v for k, v in extra.items()
        if any(h in k.lower() for h in _REASON_HINTS)
    }


def list_prompts(events: list[dict]) -> str:
    """List each permission prompt with its command and any reason/detail fields."""
    prompts = [e for e in events if e.get("event") == PERMISSION]
    if not prompts:
        return "No permission prompts recorded for this session."
    out = []
    for i, e in enumerate(prompts, 1):
        out.append(f"[{i}] {e.get('iso', '?')}  {e.get('tool') or '(unknown tool)'}")
        cmd = _command_summary(e.get("tool"), e.get("tool_input"))
        if cmd:
            out.append(f"    command: {cmd}")
        extra = e.get("extra") or {}
        reasons = _reason_fields(extra)
        if reasons:
            for k, v in reasons.items():
                out.append(f"    {k}: {v}")
        elif extra:
            out.append(f"    (no reason-like field; payload extras: {', '.join(sorted(extra))})")
        elif "tool_input" in e or "extra" in e:
            out.append("    (this permission payload carried no extra/reason fields)")
        else:
            out.append("    (no detail captured — event predates reason capture)")
    return "\n".join(out)


def _session_files() -> list[str]:
    d = events_dir()
    if not os.path.isdir(d):
        return []
    return [
        os.path.join(d, f) for f in os.listdir(d) if f.endswith(".jsonl")
    ]


def _path_for(session_id: str) -> str:
    return os.path.join(events_dir(), f"{session_id}.jsonl")


def cleanup(days: float, dry_run: bool = False) -> list[str]:
    """Delete event logs (and their reports) last modified more than `days` ago.

    Returns the session ids removed. Uses file modification time, so an active
    session is never deleted mid-flight.
    """
    cutoff = time.time() - days * 86400
    reports = os.path.join(root_dir(), "reports")
    removed: list[str] = []
    for path in _session_files():
        if os.path.getmtime(path) >= cutoff:
            continue
        sid = os.path.basename(path)[: -len(".jsonl")]
        removed.append(sid)
        if dry_run:
            continue
        os.remove(path)
        report_file = os.path.join(reports, f"{sid}.txt")
        if os.path.exists(report_file):
            os.remove(report_file)
    return removed


def report_for_session(session_id: str) -> str:
    """Render a session's report by id; used by capture.py on SessionEnd."""
    path = _path_for(session_id)
    if not os.path.exists(path):
        return f"No event log found for session {session_id}."
    stats = compute(load_events(path))
    return render(stats, session_id)


def _main(argv: list[str]) -> int:
    dry_run = "-n" in argv or "--dry-run" in argv
    args = [a for a in argv if a not in ("--json", "-n", "--dry-run")]
    as_json = "--json" in argv

    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    if args[0] == "--cleanup":
        if len(args) < 2:
            print("Usage: report.py --cleanup <days> [-n]")
            return 1
        try:
            days = float(args[1])
        except ValueError:
            print(f"Invalid number of days: {args[1]!r}")
            return 1
        if days < 0:
            print("Days must be non-negative.")
            return 1
        removed = cleanup(days, dry_run=dry_run)
        verb = "Would remove" if dry_run else "Removed"
        if not removed:
            print(f"No sessions older than {days:g} day(s).")
        else:
            print(f"{verb} {len(removed)} session(s) older than {days:g} day(s):")
            for sid in removed:
                print(f"  {sid}")
        return 0

    if args[0] == "--prompts":
        # --prompts [session_id]; defaults to the latest session.
        if len(args) >= 2:
            sid = args[1]
            path = _path_for(sid)
            if not os.path.exists(path):
                print(f"No event log found for session {sid} (looked in {events_dir()}).")
                return 1
        else:
            files = sorted(_session_files(), key=os.path.getmtime, reverse=True)
            if not files:
                print("No sessions captured yet.")
                return 0
            path = files[0]
            sid = os.path.basename(path)[: -len(".jsonl")]
        print(f"Session: {sid}")
        print(list_prompts(load_events(path)))
        return 0

    if args[0] == "--all":
        files = sorted(_session_files(), key=os.path.getmtime, reverse=True)
        rows = []
        for path in files:
            sid = os.path.basename(path)[: -len(".jsonl")]
            stats = compute(load_events(path))
            if stats.get("empty"):
                continue
            rows.append((sid, stats))
        if as_json:
            print(json.dumps({sid: s for sid, s in rows}, indent=2))
            return 0
        if not rows:
            print("No sessions captured yet.")
            return 0
        hdr = (
            f"{'SESSION':36}  {'PROMPTS':>7}  {'DURATION':>10}  {'P/MIN':>6}  "
            f"{'AVG GAP':>10}  {'PERM WAIT':>10}"
        )
        print(hdr)
        print("-" * len(hdr))
        for sid, s in rows:
            print(
                f"{sid:36}  {s['permission_prompts']:>7}  "
                f"{_fmt_duration(s['total_ms']):>10}  {s['prompts_per_min']:>6.2f}  "
                f"{_fmt_duration(s['avg_processing_between_prompts_ms']):>10}  "
                f"{_fmt_duration(s['permission_wait_ms']):>10}"
            )
        return 0

    if args[0] == "--latest":
        files = sorted(_session_files(), key=os.path.getmtime, reverse=True)
        if not files:
            print("No sessions captured yet.")
            return 0
        path = files[0]
        sid = os.path.basename(path)[: -len(".jsonl")]
    else:
        sid = args[0]
        path = _path_for(sid)
        if not os.path.exists(path):
            print(f"No event log found for session {sid} (looked in {events_dir()}).")
            return 1

    stats = compute(load_events(path))
    if as_json:
        print(json.dumps({"session_id": sid, **stats}, indent=2))
    else:
        print(render(stats, sid))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
