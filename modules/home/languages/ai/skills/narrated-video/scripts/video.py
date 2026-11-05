#!/usr/bin/env python3
"""Build a narrated technical walkthrough video from a scene list.

Subcommands (run `video <cmd> -h` for arguments):
  voice     render each scene's narration with the TTS server, skipping unchanged scenes
  diagram   D2 / Mermaid (Pele) / Vega-Lite / SVG source -> 1920x1080 night-theme PNG
  terminal  shot-list JSON -> simulated terminal MP4 in a window frame on a backdrop
  slides    Marp Markdown -> HTML deck, and per-slide PNGs when a browser can start
  cues      print each scene's narration length and caption cue times (for timing beats)
  assemble  scenes + narration -> one MP4 with transitions, loudness and soft captions
  check     print an MP4's streams, caption default flag, loudness and peak
  frame     extract one frame of a video as PNG

Tools come from PATH (the skill's wrapper pins them). Paths in scenes.json are
relative to the scenes.json directory.
"""

import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape

HERE = Path(__file__).resolve().parent
W, H, FPS, RATE = 1920, 1080, 30, 48000

# Night theme. Every renderer below reads these, so a new theme is one edit here.
NIGHT = {
    "bg": "#0f1220", "panel": "#1a1e33", "panel_alt": "#242a45", "text": "#e6e6f0",
    "muted": "#8b90a8", "line": "#c3c7db", "grid": "#2a2f4a", "blue": "#7aa2f7",
    "pink": "#f7768e", "green": "#9ece6a", "amber": "#e0af68", "purple": "#bb9af7",
    "cyan": "#7dcfff",
}
FONT, MONO = "Inter", "JetBrains Mono"

# Voice styles chosen by Jeff (2026-11-03). Add a style here, never ad hoc in a call.
VOICE_STYLES = {
    # Default: Breeze with a relaxed instruct; guidance_scale 2 turns on CFG so it takes effect.
    "relaxed": {"model": "breeze", "options": {
        "instruct": "Speak in a relaxed, friendly, conversational tone, like explaining "
                    "something interesting to a colleague.",
        "guidance_scale": 2.0}, "prefix": ""},
    # Backup: Higgs reads inline tags and ignores instruct.
    "expressive": {"model": "higgs", "options": {}, "prefix": "<|prosody:expressive_high|>"},
    # Only when a really enthusiastic read is wanted.
    "enthusiastic": {"model": "higgs", "options": {}, "prefix": "<|emotion:enthusiasm|>"},
}
VOICE, SEED = "jeff", 7

LEAD = 0.4  # silence before narration in each scene
TRANSITION = 0.8
# Tail silence must cover the transition so narration never overlaps the next scene.
TAIL = TRANSITION + 0.5
LOUDNESS = {"I": -20.0, "TP": -2.0, "LRA": 11.0}
FADE_IN, FADE_OUT = 0.05, 0.3
CAPTION_MAX_CHARS = 90
XFADE_NAMES = {
    "fade", "fadeblack", "fadewhite", "dissolve", "wipeleft", "wiperight", "wipeup",
    "wipedown", "slideleft", "slideright", "slideup", "slidedown", "circleopen",
    "circleclose", "radial", "pixelize", "zoomin", "smoothleft", "smoothright",
    "hblur", "distance",
}
VIDEO_EXT = {".mp4", ".mov", ".webm", ".mkv"}


def run(cmd, **kw):
    proc = subprocess.run([str(c) for c in cmd], capture_output=True, text=True, **kw)
    if proc.returncode != 0:
        sys.exit(f"command failed: {' '.join(map(str, cmd))}\n{(proc.stderr or proc.stdout)[-3000:]}")
    return proc


def need(*names):
    missing = [n for n in names if not shutil.which(n)]
    if missing:
        sys.exit(f"missing on PATH: {missing} (run through the skill's `video` wrapper)")


def duration(path):
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
               "-of", "default=nw=1:nk=1", path]).stdout
    return float(out.strip())


def load_scenes(path):
    path = Path(path).resolve()
    scenes = json.loads(path.read_text())["scenes"]
    ids = [s["id"] for s in scenes]
    if len(set(ids)) != len(ids):
        sys.exit("scene ids must be unique")
    return path.parent, scenes


# ---------------------------------------------------------------- voice

def voice_body(scene, style):
    spec = VOICE_STYLES[style]
    text = spec["prefix"] + scene.get("say", scene["caption"])
    return {"model": spec["model"], "voice": VOICE, "input": text, "response_format": "opus",
            "seed": SEED, **spec["options"]}


def speak(api, body, out):
    """POST with curl and accept the file only when its size matches Content-Length."""
    with tempfile.TemporaryDirectory() as tmp:
        body_file, hdr = Path(tmp, "body.json"), Path(tmp, "hdr")
        body_file.write_text(json.dumps(body))
        proc = subprocess.run(
            ["curl", "-sS", "--max-time", "900", "-o", str(out), "-D", str(hdr),
             "-w", "%{http_code}", "-X", "POST", f"{api}/audio/speech",
             "-H", "Content-Type: application/json", "--data-binary", f"@{body_file}"],
            capture_output=True, text=True)
        if proc.returncode != 0 or proc.stdout.strip() != "200" or not out.is_file():
            return f"curl rc={proc.returncode} http={proc.stdout.strip()} {proc.stderr.strip()[:200]}"
        lengths = re.findall(r"(?im)^content-length:\s*(\d+)", hdr.read_text(errors="replace"))
        if lengths and int(lengths[-1]) != out.stat().st_size:
            return f"truncated: got {out.stat().st_size} of {lengths[-1]} bytes"
    return None


def cmd_voice(a):
    need("curl")
    base, scenes = load_scenes(a.scenes)
    api = os.environ.get("TTS_API", "https://llama.home.jeffutter.com/v1").rstrip("/")
    outdir = base / "audio" / a.style
    outdir.mkdir(parents=True, exist_ok=True)
    failed = []
    for scene in scenes:
        if a.only and scene["id"] not in a.only:
            continue
        body = voice_body(scene, a.style)
        out, stamp = outdir / f"{scene['id']}.opus", outdir / f"{scene['id']}.request.json"
        request = json.dumps(body, sort_keys=True, ensure_ascii=False)
        if out.is_file() and stamp.is_file() and stamp.read_text() == request:
            print(f"have {out.relative_to(base)}")
            continue
        out.unlink(missing_ok=True)
        stamp.unlink(missing_ok=True)
        for attempt in range(1, 4):
            err = speak(api, body, out)
            if err is None:
                stamp.write_text(request)
                print(f"ok {out.relative_to(base)} ({duration(out):.1f}s, try {attempt})")
                break
            print(f"retry {scene['id']}: {err}", file=sys.stderr)
            out.unlink(missing_ok=True)
        else:
            failed.append(scene["id"])
    if failed:
        sys.exit(f"FAILED: {', '.join(failed)}")


# ---------------------------------------------------------------- diagram

def to_svg(src, tmp):
    """Render a diagram source to SVG; the kind comes from the file name."""
    name = src.name
    out = Path(tmp) / "diagram.svg"
    if name.endswith(".d2"):
        run(["d2", "--pad", "30", src, out])
    elif name.endswith(".mmd"):
        run(["node", HERE / "pele.mjs", src, out, json.dumps(NIGHT), FONT, MONO])
    elif name.endswith(".vl.json"):
        run(["vl2svg", src, out])
    elif name.endswith(".svg"):
        shutil.copy(src, out)
    else:
        sys.exit(f"unknown diagram kind: {name} (use .d2, .mmd, .vl.json or .svg)")
    return out.read_text(encoding="utf-8")


def slide_svg(svg, title):
    """Fit a diagram SVG into the content box of a 1920x1080 slide with a title."""
    svg = re.sub(r"<\?xml[^>]*\?>", "", svg).strip()
    # resvg ignores @font-face, so map D2's embedded font families to installed fonts.
    svg = re.sub(r"@font-face\s*\{[^}]*\}", "", svg)
    svg = re.sub(r'font-family:\s*"?d2-\d+-font-bold"?', f'font-family: "{FONT}"; font-weight: bold', svg)
    svg = re.sub(r'font-family:\s*"?d2-\d+-font-(regular|italic)"?', f'font-family: "{FONT}"', svg)
    svg = re.sub(r'font-family:\s*"?d2-\d+-font-mono[a-z-]*"?', f'font-family: "{MONO}"', svg)

    # D2 cuts edges under labels with mask rects sized for its own font; widen them.
    def widen(m):
        x, y, w, h = (float(v) for v in m.groups())
        nw = w * 1.15 + 12
        return f'<rect x="{x - (nw - w) / 2}" y="{y - 3}" width="{nw}" height="{h + 6}" fill="black">'

    svg = re.sub(r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([\d.]+)" height="([\d.]+)" fill="black">',
                 widen, svg)
    m = re.match(r"<svg\b([^>]*)>", svg)
    attrs = re.sub(r'\s(width|height|x|y|preserveAspectRatio)="[^"]*"', "", m.group(1))
    top = 220 if title else 80
    box = f'x="80" y="{top}" width="1760" height="{H - top - 60}"'
    svg = f'<svg{attrs} {box} preserveAspectRatio="xMidYMid meet">' + svg[m.end():]
    heading = (f'<text x="120" y="150" font-family="{FONT}" font-weight="bold" font-size="64" '
               f'fill="{NIGHT["text"]}">{escape(title)}</text>') if title else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<rect width="{W}" height="{H}" fill="{NIGHT["bg"]}"/>\n{heading}\n{svg}\n</svg>\n')


def rasterize(svg_path, png_path):
    cmd = ["resvg"]
    for d in filter(None, os.environ.get("VIDEO_FONT_DIRS", "").split(":")):
        cmd += ["--use-fonts-dir", d]
    run(cmd + ["--sans-serif-family", FONT, "--monospace-family", MONO, svg_path, png_path])


def cmd_diagram(a):
    need("resvg")
    src, out = Path(a.src).resolve(), Path(a.out).resolve()
    with tempfile.TemporaryDirectory() as tmp:
        svg = to_svg(src, tmp)
        if "var(" in svg:
            print("warning: unresolved CSS var() in SVG; resvg will draw those black", file=sys.stderr)
        if "foreignObject" in svg:
            print("warning: foreignObject in SVG; resvg drops HTML labels", file=sys.stderr)
        slide = out.with_suffix(".slide.svg")
        slide.write_text(slide_svg(svg, a.title), encoding="utf-8")
        rasterize(slide, out)
    print(f"wrote {out} (and {slide.name}, the slide SVG)")


# ---------------------------------------------------------------- terminal

COLOR_TAGS = {k: "\x1b[38;2;{};{};{}m".format(*(int(NIGHT[k][i:i + 2], 16) for i in (1, 3, 5)))
              for k in ("blue", "green", "pink", "amber", "muted", "purple", "cyan", "text")}
COLOR_TAGS.update({"bold": "\x1b[1m", "reset": "\x1b[0m"})


def ansi(text):
    """Expand {blue}...{reset} style tags and turn newlines into CRLF for the terminal."""
    def tag(m):
        if m.group(1) not in COLOR_TAGS:
            sys.exit(f"unknown tag {{{m.group(1)}}}; known: {sorted(COLOR_TAGS)}")
        return COLOR_TAGS[m.group(1)]
    return re.sub(r"\{(\w+)\}", tag, text).replace("\r\n", "\n").replace("\n", "\r\n")


def cast_events(spec):
    rng = random.Random(42)
    prompt = ansi(spec.get("prompt", "{blue}{bold}${reset} "))
    type_delay = spec.get("type_delay", 0.065)
    shots, end = spec["shots"], spec["end"]
    events = [(0.0, prompt)]
    for i, shot in enumerate(shots):
        t = shot["at"]
        for ch in shot["cmd"]:
            events.append((t, ch))
            t += type_delay * rng.uniform(0.7, 1.4)
        t += 0.3
        events.append((t, "\r\n"))
        for delay, text in shot.get("out", []):
            t += delay
            events.append((t, ansi(text)))
        events.append((t + 0.02, "\r\n" + prompt))
        nxt = shots[i + 1]["at"] if i + 1 < len(shots) else end
        if t >= nxt:
            sys.exit(f"shot {i} ({shot['cmd']!r}) ends at {t:.2f}s, after the next beat at {nxt}s")
    return events


def backdrop(path, win_w, win_h, title, bar_h=56, radius=16):
    """1920x1080 night gradient with a soft-shadowed, rounded macOS-style window frame."""
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    top, bottom = (22, 26, 48), (10, 12, 24)
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    rng = random.Random(7)
    for y in range(H):
        k = y / (H - 1)
        r, g, b = (top[c] + (bottom[c] - top[c]) * k for c in range(3))
        for x in range(W):
            glow = max(0.0, 1 - ((x - 480) ** 2 + (y - 200) ** 2) ** 0.5 / 1400) ** 2
            # Dither noise hides 8-bit banding in the dark gradient after H.264.
            n = rng.uniform(-1.5, 1.5)
            px[x, y] = (int(r + 16 * glow + n), int(g + 20 * glow + n), int(b + 44 * glow + n))
    x0, y0 = (W - win_w) // 2, (H - win_h) // 2
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x0, y0 + 18, x0 + win_w, y0 + win_h + 18), radius, fill=150)
    bg.paste(Image.new("RGB", (W, H)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(28)))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((x0, y0, x0 + win_w, y0 + win_h), radius, fill=(26, 30, 51),
                        outline=(52, 58, 88), width=2)
    d.rounded_rectangle((x0 + 1, y0 + 1, x0 + win_w - 1, y0 + bar_h), radius, fill=(36, 40, 66))
    d.rectangle((x0 + 1, y0 + bar_h - radius, x0 + win_w - 1, y0 + bar_h), fill=(36, 40, 66))
    d.line((x0 + 1, y0 + bar_h, x0 + win_w - 1, y0 + bar_h), fill=(52, 58, 88), width=2)
    for i, col in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx, cy = x0 + 30 + i * 30, y0 + bar_h // 2
        d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=col)
    font_file = os.environ.get("VIDEO_MONO_FONT")
    if title and font_file:
        d.text((x0 + win_w // 2, y0 + bar_h // 2), title, font=ImageFont.truetype(font_file, 20),
               fill=(139, 144, 168), anchor="mm")
    bg.save(path)


def cmd_terminal(a):
    need("agg", "ffmpeg", "ffprobe")
    spec_path, out = Path(a.shots).resolve(), Path(a.out).resolve()
    spec = json.loads(spec_path.read_text())
    cols, rows, end = spec.get("cols", 84), spec.get("rows", 17), spec["end"]
    work = out.parent / f"{out.stem}.work"
    work.mkdir(parents=True, exist_ok=True)
    cast, gif, bd = work / "term.cast", work / "term.gif", work / "backdrop.png"
    header = {"version": 2, "width": cols, "height": rows, "timestamp": 0,
              "env": {"TERM": "xterm-256color", "SHELL": "/bin/bash"}}
    with cast.open("w") as f:
        f.write(json.dumps(header) + "\n")
        for t, data in cast_events(spec):
            f.write(json.dumps([round(t, 3), "o", data]) + "\n")
        # A no-op event pins the end time so the final hold is part of the cast.
        f.write(json.dumps([end, "o", ""]) + "\n")
    n = NIGHT
    palette = [n["panel"], n["text"], n["bg"], n["pink"], n["green"], n["amber"], n["blue"],
               n["purple"], n["cyan"], n["text"], n["muted"], n["pink"], n["green"], n["amber"],
               n["blue"], n["purple"], n["cyan"], "#ffffff"]
    agg = ["agg", "--text-font-family", MONO, "--font-size", str(spec.get("font_size", 30)),
           "--line-height", "1.4", "--theme", ",".join(c.lstrip("#") for c in palette),
           "--idle-time-limit", str(end + 5), "--last-frame-duration", "0", "--no-loop", "-q"]
    for d in filter(None, os.environ.get("VIDEO_FONT_DIRS", "").split(":")):
        agg += ["--font-dir", d]
    run(agg + [cast, gif])
    size = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                "stream=width,height", "-of", "csv=p=0", gif]).stdout.strip().split(",")
    gw, gh = int(size[0]), int(size[1])
    # Window = terminal + 36 px side padding + 56 px title bar + 28 px top and bottom padding.
    win_w, win_h = gw + 72, gh + 56 + 56
    if win_w > W - 40 or win_h > H - 40:
        sys.exit(f"terminal {gw}x{gh} is too big for the frame; lower cols, rows or font_size")
    backdrop(bd, win_w, win_h, spec.get("title", ""))
    gx, gy = (W - win_w) // 2 + 36, (H - win_h) // 2 + 56 + 28
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-loop", "1", "-framerate", FPS,
         "-i", bd, "-i", gif, "-filter_complex",
         f"[1:v]fps={FPS},tpad=stop_mode=clone:stop_duration={end + 5}[t];"
         f"[0:v][t]overlay={gx}:{gy}:shortest=1,format=yuv420p[v]",
         "-map", "[v]", "-t", end, "-r", FPS, "-c:v", "libx264", "-preset", "slow", "-crf", "14",
         "-x264-params", "aq-mode=3", "-pix_fmt", "yuv420p", "-an", "-movflags", "+faststart", out])
    print(f"wrote {out} ({duration(out):.2f}s, terminal {gw}x{gh}); work files in {work.name}/")


# ---------------------------------------------------------------- slides

def cmd_slides(a):
    need("marp")
    deck, outdir = Path(a.deck).resolve(), Path(a.outdir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    theme = Path(a.theme).resolve() if a.theme else HERE.parent / "assets" / "night.css"
    common = ["marp", "--html", "--theme-set", theme, "--allow-local-files"]
    run(common + ["--bespoke.osc=false", "-o", outdir / "deck.html", deck], cwd=deck.parent)
    print(f"wrote {outdir / 'deck.html'}")
    if a.html_only:
        return
    proc = subprocess.run([str(c) for c in common + ["--images", "png", "-o", outdir / "slide.png", deck]],
                          capture_output=True, text=True, cwd=deck.parent)
    pngs = sorted(outdir.glob("slide.*.png"))
    if proc.returncode == 0 and pngs:
        for i, p in enumerate(pngs, 1):
            p.rename(outdir / f"slide-{i:02}.png")
        print(f"wrote {len(pngs)} PNGs: slide-01.png .. slide-{len(pngs):02}.png")
        return
    print("marp PNG export failed (headless Chrome could not start):\n"
          f"{(proc.stderr or proc.stdout).strip()[-600:]}\n"
          "Use the HTML route: see 'Slides without a browser launch' in SKILL.md.", file=sys.stderr)
    sys.exit(2)


# ---------------------------------------------------------------- captions and assembly

def srt_time(t):
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def clean_narration(src, dst):
    """Remove the TTS noise floor and fade both ends so clips do not start or stop abruptly."""
    length = duration(src)
    chain = (f"highpass=f=70,afftdn=nr=12:nf=-50:tn=1,aresample={RATE},"
             f"aformat=channel_layouts=stereo,afade=t=in:d={FADE_IN},"
             f"afade=t=out:st={max(0.0, length - FADE_OUT):.3f}:d={FADE_OUT}")
    run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", chain, "-c:a", "pcm_s16le", dst])
    return duration(dst)


def pauses(audio):
    """Midpoints of the pauses between phrases in a narration clip."""
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", audio,
               "-af", "silencedetect=n=-40dB:d=0.18", "-f", "null", "-"]).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
    return [(a + b) / 2 for a, b in zip(starts, ends)]


def caption_chunks(text):
    """Sentences, short ones merged, long ones split at the comma nearest their middle."""
    chunks = []
    for sentence in re.split(r"(?<=[.?!])\s+", text.strip()):
        if chunks and len(chunks[-1]) + len(sentence) < 40:
            chunks[-1] += " " + sentence
            continue
        while len(sentence) > CAPTION_MAX_CHARS:
            commas = [m.end() for m in re.finditer(r",\s", sentence)]
            if not commas:
                break
            cut = min(commas, key=lambda i: abs(i - len(sentence) / 2))
            chunks.append(sentence[:cut].strip())
            sentence = sentence[cut:].strip()
        chunks.append(sentence)
    return chunks


def caption_cues(text, narration, gaps):
    """Time each chunk by its share of characters, then snap boundaries to real pauses."""
    chunks = caption_chunks(text)
    total = sum(len(c) for c in chunks)
    bounds, used, acc = [0.0], set(), 0
    for chunk in chunks[:-1]:
        acc += len(chunk)
        guess = narration * acc / total
        near = [g for g in gaps if g > bounds[-1] + 0.5 and g not in used and abs(g - guess) < 1.5]
        snap = min(near, key=lambda g: abs(g - guess)) if near else guess
        used.add(snap)
        bounds.append(snap)
    bounds.append(narration)
    return [(bounds[i], bounds[i + 1], c) for i, c in enumerate(chunks)]


def scene_audio(base, scene, style):
    if scene.get("audio"):
        return base / scene["audio"]
    for ext in ("opus", "wav", "mp3", "flac"):
        p = base / "audio" / style / f"{scene['id']}.{ext}"
        if p.is_file():
            return p
    sys.exit(f"{scene['id']}: no narration in audio/{style}/ (run `video voice` first)")


def render_scene(scene, base, work, style):
    visual = base / scene["visual"]
    if not visual.is_file():
        sys.exit(f"{scene['id']}: visual {scene['visual']} not found")
    audio = work / f"{scene['id']}.clean.wav"
    narration = clean_narration(scene_audio(base, scene, style), audio)
    length = LEAD + narration + TAIL
    is_video = visual.suffix.lower() in VIDEO_EXT
    if is_video:
        length = max(length, duration(visual))
    scale = (f"scale={W}:{H}:force_original_aspect_ratio=decrease,"
             f"pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=0x{NIGHT['bg'][1:]},setsar=1,fps={FPS},format=yuv420p")
    if is_video:
        vin = ["-i", visual]
        vfilter = f"[0:v]{scale},tpad=stop_mode=clone:stop_duration={length}[v]"
    else:
        vin = ["-loop", "1", "-framerate", FPS, "-i", visual]
        vfilter = f"[0:v]{scale}[v]"
    lead_ms = int(LEAD * 1000)
    out = work / f"{scene['id']}.mov"
    run(["ffmpeg", "-y", "-v", "error", *vin, "-i", audio,
         "-filter_complex", f"{vfilter};[1:a]adelay={lead_ms}|{lead_ms},apad[a]",
         "-map", "[v]", "-map", "[a]", "-t", f"{length:.3f}", "-c:v", "libx264", "-preset", "medium",
         "-crf", "18", "-c:a", "pcm_s16le", "-ar", RATE, out])
    cues = caption_cues(scene["caption"], narration, pauses(audio)) if scene.get("caption") else []
    return out, duration(out), narration, cues


def cmd_cues(a):
    need("ffmpeg", "ffprobe")
    base, scenes = load_scenes(a.scenes)
    with tempfile.TemporaryDirectory() as tmp:
        for scene in scenes:
            if a.only and scene["id"] not in a.only:
                continue
            clean = Path(tmp) / "n.wav"
            narration = clean_narration(scene_audio(base, scene, a.style), clean)
            print(f"{scene['id']}: narration {narration:.2f}s, starts {LEAD}s into the scene")
            for start, _, text in caption_cues(scene.get("caption", ""), narration, pauses(clean)):
                print(f"  {LEAD + start:6.2f}s  {text}")


def cmd_assemble(a):
    need("ffmpeg", "ffprobe", "MP4Box")
    base, scenes = load_scenes(a.scenes)
    out = Path(a.out).resolve()
    work = out.parent / f"{out.stem}.work"
    work.mkdir(parents=True, exist_ok=True)
    for scene in scenes[1:]:
        if scene.get("transition", "fade") not in XFADE_NAMES:
            sys.exit(f"{scene['id']}: unknown transition {scene['transition']!r}; use one of {sorted(XFADE_NAMES)}")

    clips = []
    for scene in scenes:
        path, length, narration, cues = render_scene(scene, base, work, a.style)
        clips.append((scene, path, length, cues))
        print(f"{scene['id']}: {length:.2f}s (narration {narration:.2f}s, {len(cues)} cues)")

    # Chain xfade/acrossfade; each join starts TRANSITION seconds before the previous end.
    inputs, filters, srt_cues = [], [], []
    start, vlast, alast = 0.0, "0:v", "0:a"
    for i, (scene, path, length, cues) in enumerate(clips):
        inputs += ["-i", path]
        if i > 0:
            filters.append(f"[{vlast}][{i}:v]xfade=transition={scene.get('transition', 'fade')}:"
                           f"duration={TRANSITION}:offset={start:.3f}[v{i}]")
            filters.append(f"[{alast}][{i}:a]acrossfade=d={TRANSITION}[a{i}]")
            vlast, alast = f"v{i}", f"a{i}"
        srt_cues += [(start + LEAD + s, start + LEAD + e, text) for s, e, text in cues]
        print(f"{scene['id']} starts at {start:.2f}s in the video")
        start += length - TRANSITION
    label = lambda x: x if ":" in x else f"[{x}]"

    mix = work / "mix.mov"
    graph = ["-filter_complex", ";".join(filters)] if filters else []
    run(["ffmpeg", "-y", "-v", "error", *inputs, *graph, "-map", label(vlast), "-map", label(alast),
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
         "-c:a", "pcm_s16le", mix])

    # Two-pass loudnorm: measure, then apply as a linear gain so pauses are not pumped up.
    target = ":".join(f"{k}={v}" for k, v in LOUDNESS.items())
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", mix, "-vn",
               "-af", f"loudnorm={target}:print_format=json", "-f", "null", "-"]).stderr
    m = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
    measured = (f"measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
                f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:"
                f"offset={m['target_offset']}:linear=true")

    srt = out.with_suffix(".srt")
    srt.write_text("".join(f"{n}\n{srt_time(s)} --> {srt_time(e)}\n{text}\n\n"
                           for n, (s, e, text) in enumerate(srt_cues, 1)))
    run(["ffmpeg", "-y", "-v", "error", "-i", mix, "-i", srt,
         "-map", "0:v", "-map", "0:a", "-map", "1:s", "-c:v", "copy",
         "-af", f"loudnorm={target}:{measured},aresample={RATE}",
         "-c:a", "aac", "-b:a", "192k", "-c:s", "mov_text",
         "-metadata:s:s:0", "language=eng", "-disposition:s:0", "0",
         "-movflags", "+faststart", out])
    # ffmpeg's MP4 muxer always enables one subtitle track; disable it so captions start off.
    run(["MP4Box", "-disable", "3", out])
    print(f"wrote {out} ({duration(out):.2f}s, {len(srt_cues)} caption cues) and {srt.name}")


def cmd_check(a):
    need("ffmpeg", "ffprobe")
    info = json.loads(run(["ffprobe", "-v", "error", "-show_entries",
                           "format=duration:stream=codec_type,codec_name,width,height:stream_disposition=default",
                           "-of", "json", a.video]).stdout)
    for s in info["streams"]:
        size = f" {s['width']}x{s['height']}" if "width" in s else ""
        default = "default" if s.get("disposition", {}).get("default") else "not default"
        print(f"{s['codec_type']}: {s['codec_name']}{size} ({default})")
    print(f"duration: {float(info['format']['duration']):.2f}s")
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", a.video, "-vn",
               "-af", "ebur128=peak=true", "-f", "null", "-"]).stderr
    summary = err[err.rfind("Summary:"):]
    loud = re.search(r"I:\s+(-?[\d.]+) LUFS", summary)
    peak = re.search(r"Peak:\s+(-?[\d.]+) dBFS", summary)
    print(f"loudness: {loud.group(1) if loud else '?'} LUFS (target {LOUDNESS['I']}), "
          f"true peak: {peak.group(1) if peak else '?'} dBFS (limit {LOUDNESS['TP']})")


def cmd_frame(a):
    need("ffmpeg")
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", a.seconds, "-i", a.video,
         "-frames:v", "1", a.out])
    print(f"wrote {a.out}")


def main():
    p = argparse.ArgumentParser(prog="video", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    styles = sorted(VOICE_STYLES)

    s = sub.add_parser("voice", help="render narration for every scene")
    s.add_argument("scenes")
    s.add_argument("--style", choices=styles, default="relaxed")
    s.add_argument("--only", nargs="*", help="scene ids to render (default: all)")
    s.set_defaults(fn=cmd_voice)

    s = sub.add_parser("diagram", help="diagram source -> 1920x1080 PNG")
    s.add_argument("src", help=".d2, .mmd (Pele), .vl.json (Vega-Lite) or .svg")
    s.add_argument("out", help="output .png")
    s.add_argument("--title", default="", help="slide title above the diagram")
    s.set_defaults(fn=cmd_diagram)

    s = sub.add_parser("terminal", help="shot list JSON -> terminal MP4")
    s.add_argument("shots")
    s.add_argument("out", help="output .mp4")
    s.set_defaults(fn=cmd_terminal)

    s = sub.add_parser("slides", help="Marp deck -> deck.html (+ slide-NN.png)")
    s.add_argument("deck")
    s.add_argument("outdir")
    s.add_argument("--theme", help="Marp theme CSS (default: the skill's night.css)")
    s.add_argument("--html-only", action="store_true")
    s.set_defaults(fn=cmd_slides)

    s = sub.add_parser("cues", help="print narration length and caption cue times per scene")
    s.add_argument("scenes")
    s.add_argument("--style", choices=styles, default="relaxed")
    s.add_argument("--only", nargs="*")
    s.set_defaults(fn=cmd_cues)

    s = sub.add_parser("assemble", help="scenes + narration -> MP4")
    s.add_argument("scenes")
    s.add_argument("out")
    s.add_argument("--style", choices=styles, default="relaxed", help="which audio/<style>/ to use")
    s.set_defaults(fn=cmd_assemble)

    s = sub.add_parser("check", help="print streams, caption default flag, loudness and peak")
    s.add_argument("video")
    s.set_defaults(fn=cmd_check)

    s = sub.add_parser("frame", help="extract one frame as PNG")
    s.add_argument("video")
    s.add_argument("seconds", type=float)
    s.add_argument("out")
    s.set_defaults(fn=cmd_frame)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
