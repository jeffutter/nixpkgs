"""Drawing and animation kit for narrated-presentation visuals.

Every scene script imports this, so colours, type, code panels, phones and motion match across
scenes and across the agents that draw them.

    still:      save_png(svg_string, "visuals/X.png")
    animation:  render_anim(frame_fn, seconds, "visuals/X.mp4")   # frame_fn(t) -> svg string
    timing:     CUES, END = scene_cues("X", {"name": "phrase from the caption"})

Run scene scripts through `present run visuals-src/X.py`, which puts this module and the
project's visuals-src/ on sys.path and pins resvg, ffmpeg and the fonts.
"""

import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from xml.sax.saxutils import escape

W, H, FPS = 1920, 1080, 30
ROOT = Path(os.environ.get("PRESENT_ROOT", Path.cwd())).resolve()
KIT = Path(__file__).resolve().parent
AUDIO_DIR = "audio/narration"
LEAD = 0.4  # must match video.py LEAD

# The night palette, shared with the video tool's slides, diagrams and terminal.
C = {
    "bg": "#0f1220", "panel": "#1a1e33", "panel_alt": "#242a45", "text": "#e6e6f0",
    "muted": "#8b90a8", "line": "#c3c7db", "grid": "#2a2f4a", "blue": "#7aa2f7",
    "pink": "#f7768e", "green": "#9ece6a", "amber": "#e0af68", "purple": "#bb9af7",
    "cyan": "#7dcfff",
}
FONT, MONO = "Inter", "JetBrains Mono"
RESVG = shutil.which("resvg") or "resvg"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
FFPROBE = shutil.which("ffprobe") or "ffprobe"
FONT_DIRS = [d for d in os.environ.get("VIDEO_FONT_DIRS", "").split(":") if d]


# ------------------------------------------------------------------ easing and timing

def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def ease(x):
    """Ease in-out cubic on 0..1."""
    x = clamp(x)
    return 4 * x * x * x if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def out_cubic(x):
    """Ease-out cubic on 0..1: the default for things arriving."""
    x = clamp(x)
    return 1 - (1 - x) ** 3


def prog(t, start, dur=0.6):
    """0 before start, eased in-out 0..1 over dur, 1 after."""
    return ease((t - start) / dur) if dur > 0 else float(t >= start)


def fin(t, start, dur=0.5):
    """Fade-in amount: ease-out 0..1 from start."""
    return out_cubic((t - start) / dur) if dur > 0 else float(t >= start)


def fout(t, start, dur=0.4):
    """Fade-out amount: 1 until start, then down to 0."""
    return 1 - fin(t, start, dur)


def lerp(a, b, p):
    return a + (b - a) * p


def pulse(t, start, dur=0.6, amp=0.1):
    """Scale factor: 1, a single sine bump of amp over dur from start, then 1."""
    d = t - start
    return 1 + amp * math.sin(math.pi * d / dur) if 0 <= d < dur else 1.0


def mix(a, b, k):
    """Blend two #rrggbb colours; k = 0 gives a, k = 1 gives b."""
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * k):02x}" for x, y in zip(pa, pb))


# ------------------------------------------------------------------ beat-synced motion

def beat_grid(bpm, offset):
    """(BAR, BEAT, offset). offset is when a downbeat is heard, in scene seconds. Music scenes
    other than the opener start on a downbeat with no lead, so offset is 0 there. For the opener,
    measure it: the music cut's offset into its bar plus the scene lead."""
    beat = 60 / bpm
    return 4 * beat, beat, offset


def beat_bump(t, start, beat, amount=0.06):
    """1 plus a fast-decaying bump on every beat from start: a pulse locked to the music."""
    if t < start:
        return 1.0
    phase = ((t - start) % beat) / beat
    return 1 + amount * max(0.0, 1 - phase * 3)


def on_beat(start, beat, k, land=0.1):
    """Start time for the k-th beat-timed arrival so its ease lands on the beat (eases read as
    landing about `land` s after they begin)."""
    return start + k * beat - land


# ------------------------------------------------------------------ primitives

def doc(body, bg=True):
    back = f'<rect width="{W}" height="{H}" fill="{C["bg"]}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">{back}{body}</svg>')


def text(x, y, s, size=28, fill=None, weight="normal", anchor="start", mono=False, opacity=1, extra=""):
    fam = MONO if mono else FONT
    return (f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill or C["text"]}" text-anchor="{anchor}" opacity="{opacity}" {extra}>'
            f'{escape(str(s))}</text>')


def rect(x, y, w, h, fill=None, stroke=None, sw=2, r=12, opacity=1, dash=None, extra=""):
    d = f'stroke-dasharray="{dash}"' if dash else ""
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill or "none"}" '
            f'stroke="{stroke or "none"}" stroke-width="{sw}" opacity="{opacity}" {d} {extra}/>')


def circle(cx, cy, r, fill=None, stroke=None, sw=2, opacity=1):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill or "none"}" stroke="{stroke or "none"}" '
            f'stroke-width="{sw}" opacity="{opacity}"/>')


def line(x1, y1, x2, y2, stroke=None, sw=3, opacity=1, dash=None, arrow=False):
    d = f'stroke-dasharray="{dash}"' if dash else ""
    s = (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke or C["line"]}" '
         f'stroke-width="{sw}" opacity="{opacity}" stroke-linecap="round" {d}/>')
    if arrow:
        s += arrowhead(x1, y1, x2, y2, stroke or C["line"], opacity)
    return s


def arrowhead(x1, y1, x2, y2, fill, opacity=1, size=16):
    a = math.atan2(y2 - y1, x2 - x1)
    p1 = (x2 - size * math.cos(a - 0.45), y2 - size * math.sin(a - 0.45))
    p2 = (x2 - size * math.cos(a + 0.45), y2 - size * math.sin(a + 0.45))
    return (f'<polygon points="{x2},{y2} {p1[0]:.1f},{p1[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}" '
            f'fill="{fill}" opacity="{opacity}"/>')


def group(body, dx=0, dy=0, opacity=1, scale=1):
    return f'<g transform="translate({dx},{dy}) scale({scale})" opacity="{opacity}">{body}</g>'


def scale_about(body, cx, cy, s):
    """Scale body about (cx, cy)."""
    return f'<g transform="translate({cx},{cy}) scale({s:.4f}) translate({-cx},{-cy})">{body}</g>'


def tw(s, size, mono=False):
    """Estimated text width in px (resvg has no text metrics here; keep a margin)."""
    return len(str(s)) * size * (0.6 if mono else 0.56)


# ------------------------------------------------------------------ motion wrappers

def rise(svg, t, start, dur=0.5, dy=40):
    """Slide-in: rise dy px and fade in from start. Empty before start."""
    p = fin(t, start, dur)
    if p <= 0:
        return ""
    return svg if p >= 1 else group(svg, 0, dy * (1 - p), p)


def fade(svg, t, start, dur=0.4):
    p = fin(t, start, dur)
    return "" if p <= 0 else (svg if p >= 1 else group(svg, opacity=p))


def xfade(a, b, q):
    """Cross-fade from svg a to svg b, q = 0..1."""
    return (group(a, opacity=1 - q) if q < 1 else "") + (group(b, opacity=q) if q > 0 else "")


def typed(s, t, start, cps=0.03):
    """The prefix of s typed so far at cps seconds per character."""
    return s[:max(0, int((t - start) / cps))] if t >= start else ""


# ------------------------------------------------------------------ labels and boxes

def pill(x, y, label, color, size=20, opacity=1, filled=False):
    """Small rounded tag. Use for type names, status, and the 'what if' / 'invented' tags."""
    w = int(len(label) * size * 0.6 + size * 1.2)
    h = int(size * 1.6)
    bg = color if filled else C["bg"]
    fg = C["bg"] if filled else color
    return (rect(x, y, w, h, fill=bg, stroke=color, sw=2, r=h // 2, opacity=opacity)
            + text(x + w / 2, y + h * 0.7, label, size=size, fill=fg, weight="bold",
                   anchor="middle", opacity=opacity))


def what_if(x, y, label="what if", opacity=1):
    """Amber outline tag for anything hypothetical or invented. Required on every such element."""
    return pill(x, y, label, C["amber"], size=16, opacity=opacity)


def chip(x, y, label, color, w=None, h=44, size=20, fill=None, opacity=1, dashed=False, mono=True):
    """Rounded value chip with a coloured outline; width is w or fitted to the label."""
    w = w or tw(label, size, mono) + size * 1.4
    return (rect(x, y, w, h, fill=fill or C["panel"], stroke=color, sw=2.5, r=h / 2, opacity=opacity,
                 dash="6 5" if dashed else None)
            + text(x + w / 2, y + h / 2 + size * 0.35, label, size=size, fill=color, weight="bold",
                   anchor="middle", mono=mono, opacity=opacity))


def heading(s, sub=None, y=110):
    out = text(120, y, s, size=56, weight="bold")
    if sub:
        out += text(120, y + 50, sub, size=28, fill=C["muted"])
    return out


def caption(x, y, s, color=None, size=22, anchor="start", opacity=1):
    return text(x, y, s, size=size, fill=color or C["muted"], anchor=anchor, opacity=opacity)


def src_label(x, y, s, opacity=1):
    """Muted mono source label under a code card, for example `src/app/config.json:12-20`."""
    return text(x, y, s, size=18, fill=C["muted"], mono=True, opacity=opacity)


def node_box(x, y, w, h, label, color, sub=None, fill=None, opacity=1, dash=None, size=22, mono=False,
             sw=3, label_color=None, sub_size=18):
    """Labelled box for diagrams: bold label in the colour, optional mono sublabel."""
    out = rect(x, y, w, h, fill=fill or C["panel"], stroke=color, sw=sw, r=14, dash=dash, opacity=opacity)
    lc = label_color or color
    if sub:
        out += text(x + w / 2, y + h / 2 - 2, label, size=size, weight="bold", fill=lc, anchor="middle",
                    mono=mono, opacity=opacity)
        out += text(x + w / 2, y + h / 2 + 24, sub, size=sub_size, fill=C["muted"], anchor="middle",
                    mono=True, opacity=opacity)
    else:
        out += text(x + w / 2, y + h / 2 + size * 0.35, label, size=size, weight="bold", fill=lc,
                    anchor="middle", mono=mono, opacity=opacity)
    return out


def step_box(x, y, w, h, lines, color, size=26, opacity=1, dashed=False, fill=None):
    """Panel box with centred text lines: a step in a lane or a staircase."""
    out = rect(x, y, w, h, fill=fill or C["panel"], stroke=color, sw=3, r=14, dash="8 6" if dashed else None)
    n = len(lines)
    for i, s in enumerate(lines):
        out += text(x + w / 2, y + h / 2 + size * 0.35 + (i - (n - 1) / 2) * size * 1.2, s, size=size,
                    weight="bold", anchor="middle")
    return group(out, opacity=opacity)


def stamp(cx, cy, label, color, angle=-18, size=32, opacity=1.0):
    """Rotated rubber-stamp label, for example STALE or REJECTED."""
    w = len(label) * size * 0.6 + 40
    return (f'<g transform="translate({cx},{cy}) rotate({angle})" opacity="{opacity}">'
            + rect(-w / 2, -size * 0.95, w, size * 1.9, fill=C["bg"], stroke=color, sw=4, r=10)
            + text(0, size * 0.35, label, size=size, fill=color, weight="bold", anchor="middle", mono=True)
            + "</g>")


# ------------------------------------------------------------------ glyphs

def tick(x, y, color=None, s=1.0, opacity=1):
    return (f'<path transform="translate({x},{y}) scale({s})" d="M0 10 L8 18 L22 0" fill="none" '
            f'stroke="{color or C["green"]}" stroke-width="4" stroke-linecap="round" '
            f'stroke-linejoin="round" opacity="{opacity}"/>')


def cross(x, y, color=None, s=1.0, opacity=1):
    return (f'<path transform="translate({x},{y}) scale({s})" d="M0 0 L20 20 M20 0 L0 20" fill="none" '
            f'stroke="{color or C["pink"]}" stroke-width="4" stroke-linecap="round" opacity="{opacity}"/>')


def strike(x, y, w, color=None, p=1.0, sw=4, opacity=1):
    """A line through text, drawn over p."""
    return line(x, y, x + w * clamp(p), y, stroke=color or C["pink"], sw=sw, opacity=opacity) if p > 0 else ""


def bolt(x, y, s=1.0, color=None, opacity=1):
    return (f'<path transform="translate({x},{y}) scale({s})" d="M14 0 L0 22 H10 L6 40 L22 16 H12 Z" '
            f'fill="{color or C["pink"]}" opacity="{opacity}"/>')


def lock_glyph(x, y, color=None, s=1.0, opacity=1):
    """Small padlock, about 14x18 px at s = 1, top-left at (x, y)."""
    c = color or C["amber"]
    return (f'<g transform="translate({x},{y}) scale({s})" opacity="{opacity}">'
            f'<path d="M3 8 V5 a4 4 0 0 1 8 0 V8" fill="none" stroke="{c}" stroke-width="2"/>'
            f'<rect x="0" y="8" width="14" height="10" rx="3" fill="{c}"/></g>')


def clock(cx, cy, color, r=34):
    return (circle(cx, cy, r, stroke=color, sw=4)
            + line(cx, cy, cx, cy - r * 0.6, stroke=color, sw=4) + line(cx, cy, cx + r * 0.45, cy, stroke=color, sw=4))


def finger(cx, cy, p, ring=0.0):
    """A tap: dot opacity p, plus an expanding ring 0..1."""
    out = ""
    if ring > 0:
        out += circle(cx, cy, 14 + 28 * ring, stroke=C["amber"], sw=3, opacity=(1 - ring) * 0.9)
    return out + circle(cx, cy, 14, fill=C["amber"], opacity=0.85 * p)


def wavy(x, y, w, color, amp=3, period=10, sw=2.5, opacity=1):
    """Squiggly error underline."""
    pts, n = [], int(w / (period / 2))
    for i in range(n + 1):
        pts.append(f"{x + i * period / 2:.1f},{y + (amp if i % 2 else -amp):.1f}")
    return (f'<polyline points="{" ".join(pts)}" fill="none" stroke="{color}" stroke-width="{sw}" '
            f'stroke-linejoin="round" opacity="{opacity}"/>')


def grid_bg(opacity=0.5, step=80, p=1.0):
    """The title-card grid; p draws it outward from the top-left (0..1)."""
    out = [line(i, 0, i, H * p, stroke=C["grid"], sw=1, opacity=opacity) for i in range(0, W + 1, step)]
    out += [line(0, j, W * p, j, stroke=C["grid"], sw=1, opacity=opacity) for j in range(0, H + 1, step)]
    return "".join(out)


# ------------------------------------------------------------------ paths

def _plen(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def arrow_path(pts, color=None, p=1.0, sw=3, dash=None, opacity=1, head=True):
    """Polyline with an arrowhead, drawn over p (0..1). Dashed lines fade in instead of drawing."""
    if p <= 0:
        return ""
    col = color or C["line"]
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    base = (f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{sw}" stroke-linejoin="round" '
            f'stroke-linecap="round"')
    if dash:
        s = base + f' stroke-dasharray="{dash}" opacity="{opacity * clamp(p)}"/>'
    else:
        L = _plen(pts)
        s = base + f' stroke-dasharray="{L * clamp(p):.1f} {L + 10:.1f}" opacity="{opacity}"/>'
    if head and p >= 0.999:
        s += arrowhead(pts[-2][0], pts[-2][1], pts[-1][0], pts[-1][1], col, opacity)
    return s


def along(pts, p):
    """Point at fraction p of a polyline: move a token along an arrow."""
    L = _plen(pts) * clamp(p)
    for i in range(len(pts) - 1):
        seg = math.dist(pts[i], pts[i + 1])
        if L <= seg or i == len(pts) - 2:
            f = L / seg if seg else 0
            return (lerp(pts[i][0], pts[i + 1][0], f), lerp(pts[i][1], pts[i + 1][1], f))
        L -= seg


# ------------------------------------------------------------------ code

_KW = {"type", "interface", "implements", "extends", "export", "import", "from", "const", "let", "function",
       "return", "if", "else", "for", "of", "in", "as", "satisfies", "true", "false", "null", "def", "class",
       "fn", "pub", "struct", "enum", "query", "mutation", "fragment", "on", "await", "async"}


def _json_spans(src):
    spans, i = [], 0
    for m in re.finditer(r'"(?:[^"\\]|\\.)*"(\s*:)?|-?\d+(?:\.\d+)?|true|false|null|//.*$', src):
        if m.start() > i:
            spans.append((src[i:m.start()], C["line"]))
        tok = m.group(0)
        if tok.startswith("//"):
            spans.append((tok, C["muted"]))
        elif m.group(1):
            spans.append((tok[: len(tok) - len(m.group(1))], C["blue"]))
            spans.append((m.group(1), C["line"]))
        elif tok.startswith('"'):
            spans.append((tok, C["green"]))
        else:
            spans.append((tok, C["amber"]))
        i = m.end()
    if i < len(src):
        spans.append((src[i:], C["line"]))
    return spans


def _code_spans(src):
    out, i = [], 0
    for m in re.finditer(r"//.*$|#.*$|\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'|@\w+|\b\w+\b", src):
        if m.start() > i:
            out.append((src[i:m.start()], C["line"]))
        tok = m.group(0)
        col = (C["muted"] if tok[0] in "/#" else C["green"] if tok[0] in "\"'" else C["cyan"]
               if tok[0] == "@" else C["purple"] if tok in _KW else C["text"])
        out.append((tok, col))
        i = m.end()
    if i < len(src):
        out.append((src[i:], C["line"]))
    return out


def _log_spans(src):
    out, i = [], 0
    for m in re.finditer(r"(\w+)=(\{[^}]*\}|\S+)", src):
        out.append((src[i:m.start()], C["line"]))
        out.append((m.group(1) + "=", C["muted"]))
        v = m.group(2)
        out.append((v, C["pink"] if (m.group(1), v) == ("level", "error") else C["green"]))
        i = m.end()
    out.append((src[i:], C["line"]))
    return out


def code_line_y(y, size, i, title=True):
    """Baseline y of line i in a code_panel placed at y: anchor arrows and underlines to code."""
    lh = size * 1.5
    return y + (60 if title else 24) + lh * (i + 1) - lh * 0.28


def code_char_x(x, size, col, nums=True):
    """Left x of character column col in a code_panel placed at x."""
    return x + (72 if nums else 28) + col * size * 0.6


def code_panel(x, y, w, lines, size=22, title=None, highlight=(), dim=(), lang="json", nums=True,
               line_colors=None, opacity=1, reveal=None, band_color=None, color=None):
    """A code card with window dots and a mono title. lang: json | code (ts, py, graphql, sql...)
    | log | plain. nums: True for 1.., a list of numbers (None = blank) for real line numbers, or
    False. highlight: indices on a panel_alt band with a coloured edge. dim: indices at 35%.
    line_colors: {i: colour} for a whole line. reveal: lines visible (float fades the last one).
    Keep to 14 lines. Returns (svg, height)."""
    lh = size * 1.5
    top = 60 if title else 24
    h = top + lh * len(lines) + 24
    out = [rect(x, y, w, h, fill=C["panel"], stroke=color or C["grid"], sw=3 if color else 2, r=16)]
    if title:
        out.append(circle(x + 28, y + 30, 7, fill=C["pink"]) + circle(x + 50, y + 30, 7, fill=C["amber"])
                   + circle(x + 72, y + 30, 7, fill=C["green"]))
        out.append(text(x + 100, y + 38, title, size=20, fill=C["muted"], mono=True))
    numbers = list(range(1, len(lines) + 1)) if nums is True else (nums or None)
    gx = x + (72 if numbers else 28)
    for i, src in enumerate(lines):
        op = 1.0
        if reveal is not None:
            op = clamp(reveal - i)
            if op <= 0:
                continue
        if i in dim:
            op *= 0.35
        ly = code_line_y(y, size, i, title)
        if i in highlight:
            out.append(rect(x + 8, ly - lh * 0.78, w - 16, lh, fill=C["panel_alt"], r=6, opacity=op))
            out.append(rect(x + 8, ly - lh * 0.78, 5, lh, fill=band_color or C["amber"], r=2, opacity=op))
        if numbers and numbers[i] is not None:
            out.append(text(x + 52, ly, numbers[i], size=size * 0.75, fill=C["muted"], anchor="end", mono=True,
                            opacity=op))
        if line_colors and i in line_colors:
            spans = [(src, line_colors[i])]
        else:
            spans = {"json": _json_spans, "code": _code_spans, "log": _log_spans}.get(
                lang, lambda s: [(s, C["text"])])(src)
        tsp = "".join(f'<tspan fill="{c}">{escape(t)}</tspan>' for t, c in spans)
        out.append(f'<text x="{gx}" y="{ly}" font-family="{MONO}" font-size="{size}" '
                   f'xml:space="preserve" opacity="{op}">{tsp}</text>')
    return group("".join(out), opacity=opacity), h


# ------------------------------------------------------------------ terminal

TAGCOL = {"blue": C["blue"], "green": C["green"], "pink": C["pink"], "amber": C["amber"],
          "muted": C["muted"], "purple": C["purple"], "cyan": C["cyan"], "text": C["text"]}


def parse_tags(s):
    """'{green}ok{reset}' -> [(text, colour, bold)]. Tags: colours above, {bold}, {reset}."""
    segs, col, bold, i = [], C["text"], False, 0
    for m in re.finditer(r"\{(\w+)\}", s):
        if m.start() > i:
            segs.append((s[i:m.start()], col, bold))
        tag = m.group(1)
        if tag == "reset":
            col, bold = C["text"], False
        elif tag == "bold":
            bold = True
        elif tag in TAGCOL:
            col = TAGCOL[tag]
        i = m.end()
    if i < len(s):
        segs.append((s[i:], col, bold))
    return segs


def plain(s):
    return "".join(t for t, _, _ in parse_tags(s))


def ev(t0, s, cps=None, pre="", until=1e9):
    """One terminal line: appears at t0, leaves at until. cps: seconds per typed character of s;
    pre (the prompt) is static."""
    return {"t": t0, "s": s, "cps": cps, "pre": pre, "until": until}


def term(t, events, x, y, w, h, size=20, title="~", marks=(), cursor=True):
    """A terminal window inside a scene, driven by ev() lines. Shows the newest lines that fit.
    marks: (event index, start char, end char, colour, kind band|underline|box, opacity), counted in
    the plain text of s. All output is canned: say so in the script's notes."""
    lh = size * 1.5
    cap = int((h - 64) // lh)
    vis = [(k, e) for k, e in enumerate(events) if e["t"] <= t < e["until"]][-cap:]
    cw = size * 0.6
    out = [rect(x, y, w, h, fill="#0b0e1a", stroke=C["grid"], sw=2, r=16),
           circle(x + 28, y + 28, 7, fill=C["pink"]) + circle(x + 50, y + 28, 7, fill=C["amber"])
           + circle(x + 72, y + 28, 7, fill=C["green"]),
           text(x + 100, y + 35, title, size=18, fill=C["muted"], mono=True)]
    last_end = None
    for vi, (k, e) in enumerate(vis):
        ty = y + 56 + lh * vi
        base = ty + lh * 0.7
        pre = plain(e["pre"])
        segs = parse_tags(e["s"])
        if e["cps"]:
            cut, left = [], max(0, int((t - e["t"]) / e["cps"]))
            for tx, col, b in segs:
                if left <= 0:
                    break
                cut.append((tx[:left], col, b))
                left -= len(tx)
            segs = cut
        for (mk, a, b, col, kind, mo) in marks:
            if mk == k and mo > 0:
                mx, mw = x + 24 + (len(pre) + a) * cw, (b - a) * cw
                if kind == "band":
                    out.append(rect(mx - 4, ty + 3, mw + 8, lh - 6, fill=C["panel_alt"], r=6, opacity=mo))
                elif kind == "underline":
                    out.append(line(mx, base + 6, mx + mw * mo, base + 6, stroke=col, sw=3))
                else:
                    out.append(rect(mx - 4, ty + 3, mw + 8, lh - 6, stroke=col, sw=2.5, r=6, opacity=mo))
        tsp = "".join(f'<tspan fill="{c}" font-weight="{"bold" if b else "normal"}">{escape(tx)}</tspan>'
                      for tx, c, b in parse_tags(e["pre"]) + segs)
        out.append(f'<text x="{x + 24}" y="{base}" font-family="{MONO}" font-size="{size}" '
                   f'xml:space="preserve">{tsp}</text>')
        last_end = (x + 24 + (len(pre) + sum(len(tx) for tx, _, _ in segs)) * cw, ty)
    if cursor and last_end and int(t * 2) % 2 == 0:
        out.append(rect(last_end[0] + 2, last_end[1] + 5, cw, lh - 10, fill=C["text"], r=2, opacity=0.8))
    return "".join(out)


# ------------------------------------------------------------------ phone mock-up
#
# phone() draws a 420x860 device and places its local coordinates on the canvas. Card helpers
# draw in phone-local coordinates: cards sit at CARD_X with width CARD_W in the content viewport
# (y VIEW_TOP..VIEW_BOT). Default placement: scale 1 at (180, 110); beside code use 0.78-0.9.

PHONE_W, PHONE_H = 420, 860
VIEW_TOP, VIEW_BOT = 172, 836
CARD_X, CARD_W = 28, 364
SCREEN = "#0b0e1a"


def tab_layout(tabs, ghost=None, avail=380):
    """Tab geometry in phone-local px: [{x, w, size}] per tab (ghost last). Pass ghost= from the
    first frame so the tabs do not shift when it appears."""
    labels = list(tabs) + ([ghost] if ghost else [])
    if not labels:
        return []
    raw = [len(s) * 9.2 + 24 for s in labels]
    f = clamp((avail - 8 * (len(labels) - 1)) / sum(raw), 0.75, 1.0)
    out, x = [], 28
    for r in raw:
        out.append({"x": x, "w": r * f, "size": 16 * f})
        x += r * f + 8
    return out


def phone(x, y, title="", tabs=(), active=0, body="", scale=1.0, opacity=1, badges=None, ghost_tab=None,
          hidden_tabs=(), scroll=0, overlay=""):
    """The device frame. tabs: labels; active: index, a float slides the underline. badges:
    {index: count}. ghost_tab: a dashed amber tab after the last (a proposed tab). hidden_tabs:
    drawn dashed and muted. body is clipped to the viewport; overlay is drawn above, unclipped."""
    out = [rect(0, 0, PHONE_W, PHONE_H, fill="#05070f", stroke="#3a4060", sw=3, r=56)]
    for by, bh in ((190, 60), (270, 60)):
        out.append(rect(-4, by, 4, bh, fill="#3a4060", r=2))
    out.append(rect(PHONE_W, 230, 4, 90, fill="#3a4060", r=2))
    out.append(rect(12, 12, 396, 836, fill=SCREEN, r=44))
    out.append(rect(150, 22, 120, 28, fill="#000000", r=14))
    out.append(text(40, 44, "9:41", size=17, weight="bold"))
    for i, bh in enumerate((6, 9, 12)):
        out.append(rect(300 + i * 6, 44 - bh, 4, bh, fill=C["text"], r=1))
    out.append(rect(352, 31, 24, 12, stroke=C["muted"], sw=1.5, r=3))
    out.append(rect(354, 33, 16.8, 8, fill=C["green"], r=2))
    if title:
        out.append(text(28, 98, title, size=28, weight="bold"))
    top = VIEW_TOP if tabs else VIEW_TOP - 48
    if tabs:
        geo = tab_layout(tabs, ghost_tab)
        for i, t in enumerate(tabs):
            g = geo[i]
            hid = i in hidden_tabs
            col = C["muted"] if hid else (C["text"] if round(active) == i else C["muted"])
            if hid:
                out.append(rect(g["x"], 122, g["w"], 36, stroke=C["muted"], sw=2, r=10, dash="6 5"))
            out.append(text(g["x"] + g["w"] / 2, 146, t, size=g["size"], anchor="middle", fill=col,
                            weight="bold" if round(active) == i and not hid else "normal",
                            opacity=0.5 if hid else 1))
        lo = int(clamp(math.floor(active), 0, len(tabs) - 1))
        hi = min(lo + 1, len(tabs) - 1)
        f = active - lo
        out.append(rect(lerp(geo[lo]["x"], geo[hi]["x"], f) + 12, 159,
                        lerp(geo[lo]["w"], geo[hi]["w"], f) - 24, 3, fill=C["blue"], r=2))
        for i, n in (badges or {}).items():
            cx = geo[i]["x"] + geo[i]["w"] - 8
            out.append(circle(cx, 128, 9, fill=C["pink"]) + text(cx, 132, n, size=12, weight="bold",
                                                                  fill=C["bg"], anchor="middle"))
        if ghost_tab:
            g = geo[len(tabs)]
            out.append(rect(g["x"], 122, g["w"], 36, stroke=C["amber"], sw=2, r=10, dash="6 5")
                       + text(g["x"] + g["w"] / 2, 146, ghost_tab, size=g["size"], anchor="middle",
                              fill=C["amber"], weight="bold"))
        out.append(line(12, 164, 408, 164, stroke=C["grid"], sw=1))
    out.append(f'<defs><clipPath id="pv{top}"><rect x="12" y="{top}" width="396" '
               f'height="{VIEW_BOT - top}"/></clipPath></defs>'
               f'<g clip-path="url(#pv{top})"><g transform="translate(0,{-scroll})">{body}</g></g>')
    out.append(f"<g>{overlay}</g>")
    out.append(rect(150, 832, 120, 5, fill=C["text"], r=3, opacity=0.4))
    return f'<g transform="translate({x},{y}) scale({scale})" opacity="{opacity}">{"".join(out)}</g>'


def card(x, y, w, h, title=None, color=None, body="", opacity=1, dashed=False, label=None):
    """A content card inside a phone: panel surface, optional title, outline colour and a small mono
    label above-right (for example the component's type name)."""
    out = [rect(x, y, w, h, fill=C["panel"], stroke=color or C["grid"], sw=2, r=14,
                dash="8 6" if dashed else None)]
    if title:
        out.append(text(x + 16, y + 30, title, size=18, weight="bold"))
    out.append(body)
    if label:
        out.append(text(x + w - 10, y - 8, label, size=13, fill=color or C["muted"], anchor="end", mono=True))
    return group("".join(out), opacity=opacity)


def list_row(x, y, title, caption=None, w=336, icon=None, tag=None, chevron=True):
    """List row, h 56: icon square (icon = its colour), title, caption, chevron, optional green tag."""
    out = [rect(x, y, w, 56, fill=C["panel_alt"], r=12, opacity=0.55),
           rect(x + 10, y + 10, 36, 36, fill=icon or C["panel_alt"], r=10, opacity=0.9 if icon else 1),
           text(x + 58, y + 25, title, size=15, weight="bold")]
    if caption:
        out.append(text(x + 58, y + 44, caption, size=13, fill=C["muted"]))
    if chevron:
        cx = x + w - 18
        out.append(f'<path d="M{cx} {y + 21} l7 7 l-7 7" fill="none" stroke="{C["muted"]}" '
                   f'stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>')
    if tag:
        tx = x + w - 40 - tw(tag, 12) - 14
        out.append(rect(tx, y + 19, tw(tag, 12) + 14, 18, fill=C["green"], r=6))
        out.append(text(tx + (tw(tag, 12) + 14) / 2, y + 32, tag, size=12, fill=C["bg"], weight="bold",
                        anchor="middle"))
    return "".join(out)


def skeleton(x, y, w, h, r=10, opacity=1, shimmer=None):
    """Loading placeholder block. shimmer: a time in seconds; the fill breathes."""
    fill = C["panel_alt"] if shimmer is None else mix(C["panel_alt"], "#343b5e", 0.5 + 0.5 * math.sin(shimmer * 4))
    return rect(x, y, w, h, fill=fill, r=r, opacity=opacity)


# ------------------------------------------------------------------ rendering

def _resvg_cmd(svg_path, png_path):
    cmd = [RESVG]
    for d in FONT_DIRS:
        cmd += ["--use-fonts-dir", d]
    return cmd + ["--sans-serif-family", FONT, "--monospace-family", MONO, str(svg_path), str(png_path)]


def save_png(svg, out):
    out = ROOT / out if not os.path.isabs(out) else Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    src = out.with_suffix(".svg")
    src.write_text(svg, encoding="utf-8")
    subprocess.run(_resvg_cmd(src, out), check=True, capture_output=True)
    print(f"wrote {out}")


def render_anim(frame_fn, seconds, out, fps=FPS, keep_svg_at=None):
    """Render frame_fn(t) for t in [0, seconds) to an H.264 MP4. Identical consecutive SVGs are
    rasterised once. keep_svg_at: a time whose SVG is saved beside the MP4 for review."""
    out = ROOT / out if not os.path.isabs(out) else Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    n = int(round(seconds * fps))
    with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
        tmp = Path(tmp)
        jobs, prev, prev_idx = [], None, -1
        for i in range(n):
            svg = frame_fn(i / fps)
            if svg == prev:
                jobs.append((i, prev_idx, None))
            else:
                (tmp / f"f{i:05}.svg").write_text(svg, encoding="utf-8")
                jobs.append((i, i, svg))
                prev, prev_idx = svg, i

        def raster(job):
            i, _src, svg = job
            if svg is not None:
                subprocess.run(_resvg_cmd(tmp / f"f{i:05}.svg", tmp / f"f{i:05}.png"),
                               check=True, capture_output=True)

        with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
            list(ex.map(raster, jobs))
        for i, src, svg in jobs:
            if svg is None:
                shutil.copyfile(tmp / f"f{src:05}.png", tmp / f"f{i:05}.png")
        subprocess.run([FFMPEG, "-y", "-v", "error", "-framerate", str(fps), "-i", str(tmp / "f%05d.png"),
                        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                        str(out)], check=True)
        if keep_svg_at is not None:
            out.with_suffix(".svg").write_text(frame_fn(keep_svg_at), encoding="utf-8")
    print(f"wrote {out} ({seconds:.1f}s, {n} frames)")


# ------------------------------------------------------------------ narration timing

def scene_cues(sid, marks):
    """Start times (s from scene start, lead included) of phrases in a scene's narration, and the
    narration end. marks: {name: exact substring of the scene's caption}. Uses the real clip via
    `video cues` when it exists, else estimates at 2.6 words per second. Never hard-code times:
    every re-voice changes them, and this re-times the scene on the next render."""
    scene = next(s for s in json.loads((ROOT / "scenes.json").read_text())["scenes"] if s["id"] == sid)
    caption = scene["caption"]
    lead = scene.get("lead", LEAD)
    for k, ph in marks.items():
        assert caption.find(ph) >= 0, f"{sid}: mark {k!r} phrase {ph!r} is not in the caption"
    if (ROOT / AUDIO_DIR / f"{sid}.opus").is_file():
        out = subprocess.run([sys.executable, "-I", str(KIT / "video.py"), "cues", str(ROOT / "scenes.json"),
                              "--only", sid], capture_output=True, text=True, check=True).stdout
        end = lead + float(re.search(r"narration ([\d.]+)s", out).group(1))
        chunks = [(float(m.group(1)), m.group(2)) for m in re.finditer(r"^\s+([\d.]+)s  (.*)$", out, flags=re.M)]
        spans, pos = [], 0
        for i, (start, txt) in enumerate(chunks):
            off = caption.find(txt, pos)
            stop = chunks[i + 1][0] if i + 1 < len(chunks) else end
            spans.append((off, off + len(txt), start, stop))
            pos = off + len(txt)
        res = {}
        for k, ph in marks.items():
            i = caption.find(ph)
            a, b, s0, s1 = next(sp for sp in spans if sp[0] <= i < sp[1] + 1)
            res[k] = round(s0 + (s1 - s0) * (i - a) / max(1, b - a), 2)
        return res, round(end, 2)
    res = {k: round(lead + len(caption[:caption.find(ph)].split()) / 2.6, 2) for k, ph in marks.items()}
    return res, round(lead + len(caption.split()) / 2.6, 2)
