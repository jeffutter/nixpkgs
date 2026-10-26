"""YuE2 song generation via audio.cpp behind llama-swap.

Endpoints, model ids and ffmpeg come from the Nix wrapper (scripts/yue2), see
modules/home/languages/ai.nix. Every render embeds its recipe (style, lyrics,
plan, seed, bpm) as JSON in the MP3 comment tag, so `info`/`check` never need
side files.
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import uuid

import numpy as np

YUE2_API = os.environ["YUE2_API"]
YUE2_MODEL = os.environ["YUE2_MODEL"]
STT_API = os.environ["STT_API"]
STT_MODEL = os.environ["STT_MODEL"]


def post_json(url, body, timeout):
    req = urllib.request.Request(
        url, json.dumps(body).encode(), {"content-type": "application/json"}
    )
    try:
        return json.loads(urllib.request.urlopen(req, timeout=timeout).read())
    except urllib.error.HTTPError as e:
        sys.exit(f"{url}: HTTP {e.code}: {e.read().decode(errors='replace')[:2000]}")


def run_task(lyrics, options, timeout):
    return post_json(
        f"{YUE2_API}/audioapi/v1/tasks/run",
        {"model": YUE2_MODEL, "text": lyrics, "options": options},
        timeout,
    )


# ---------------------------------------------------------------- meter
# All BPM values in this tool count quarter notes per minute, whatever the
# meter. Plans use L:1/32, so a quarter note is 8 units.


def parse_meter(text):
    """(num, den) from an ABC M: value or the first 'N/D' in a style string."""
    if not text:
        return None
    t = text.strip()
    if t.startswith("C|"):
        return 2, 2
    if t.startswith("C"):
        return 4, 4
    m = re.search(r"\b(\d{1,2})/(\d{1,2})\b", t)
    return (int(m.group(1)), int(m.group(2))) if m else None


def is_compound(meter):
    """6/8, 9/8, 12/8: the felt beat is a dotted quarter, not a quarter."""
    num, den = meter
    return den == 8 and num % 3 == 0 and num > 3


def beat_units(meter):
    return 12 if is_compound(meter) else 32 // meter[1]


def meter_name(meter):
    return f"{meter[0]}/{meter[1]}"


def beat_name(meter):
    return "compound (dotted-quarter pulse)" if is_compound(meter) else "simple (quarter pulse)"


# ---------------------------------------------------------------- ABC plans


def abc_header(abc, key):
    m = re.search(rf"^{key}:(.*)$", abc, re.M)
    return m.group(1).strip() if m else None


def plan_bpm(abc):
    """The plan's Q: tempo in quarter notes per minute (Q:3/8=60 is 90)."""
    m = re.match(r"(?:(\d+)/(\d+)\s*=\s*)?(\d+)", abc_header(abc, "Q") or "")
    if not m:
        return None
    unit = int(m.group(1)) / int(m.group(2)) if m.group(1) else 0.25
    return round(int(m.group(3)) * unit * 4)


def plan_stats(abc):
    """Vocal onset positions within the bar, and total length in quarters.

    beat_fit is the share of vocal onsets on the beats of the plan's own
    meter. A melody that fights its header (dotted quarters under M:3/4,
    landing on 12 of a 24-unit bar) is sung in the meter the notes imply,
    not the header, so a low beat_fit predicts a meter mismatch.
    """
    meter = parse_meter(abc_header(abc, "M")) or (4, 4)
    bar = meter[0] * 32 // meter[1]
    beat = beat_units(meter)
    voice, pos, onsets = None, 0, []
    for line in abc.splitlines():
        if line.startswith("V:"):
            voice = line[2:].split()[0]
            continue
        if voice != "Vocal" or re.match(r"^(%|[A-Z]:)", line):
            continue
        for m in re.finditer(r"([A-Ga-gzZ])[,']*(\d*)", re.sub(r'"[^"]*"', "", line)):
            ch, d = m.group(1), int(m.group(2) or 1)
            if ch == "Z":
                pos += bar * d
                continue
            if ch != "z":
                onsets.append(pos % bar)
            pos += d
    n = len(onsets) or 1
    beat_fit = sum(o % beat == 0 for o in onsets) / n
    return {"meter": meter, "beat_fit": beat_fit, "quarters": pos / 8}


def set_tempo(abc, bpm):
    return re.sub(r"^Q:.*$", f"Q:1/4={bpm}", abc, flags=re.M)


def set_style_bpm(style, bpm):
    if re.search(r"\d+\s*BPM", style):
        return re.sub(r"\d+\s*BPM", f"{bpm} BPM", style)
    return f"{style}, {bpm} BPM"


def cmd_plan(a):
    lo, _, hi = a.seeds.partition("-")
    lyrics = open(a.lyrics).read()
    wanted = parse_meter(a.style)
    os.makedirs(a.dir, exist_ok=True)
    rows = []
    for seed in range(int(lo), int(hi or lo) + 1):
        t = time.time()
        r = run_task(lyrics, {"style": a.style, "cot": "melody", "stop_after": "abc", "seed": seed}, 900)
        abc = base64.b64decode(r["artifacts"][0]["payload"]).decode()
        path = os.path.join(a.dir, f"plan-{seed}.abc")
        open(path, "w").write(abc)
        s = plan_stats(abc)
        q = plan_bpm(abc) or 0
        secs = re.findall(r"^% (.+)$", abc, re.M)
        rows.append((wanted is None or s["meter"] == wanted, s["beat_fit"], seed, meter_name(s["meter"])))
        print(
            f"{path}: {time.time() - t:.0f}s M:{meter_name(s['meter'])} Q:{q} K:{abc_header(abc, 'K')} "
            f"beat_fit={s['beat_fit']:.2f} "
            f"length@Q={s['quarters'] / max(q, 1):.1f}min sections={','.join(secs)}",
            flush=True,
        )
    want = f"M:{meter_name(wanted)} from the style first, then " if wanted else ""
    print(f"\nranked by {want}beat_fit:")
    for match, fit, seed, m in sorted(rows, reverse=True):
        print(f"  plan-{seed}.abc M:{m} beat_fit={fit:.2f}{'' if match else '  (meter differs from style)'}")


# ---------------------------------------------------------------- audio


def decode(path, sr=44100):
    pcm = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(sr), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0, sr


def pulse(path, bpm):
    """ACF of the onset envelope at a dotted quarter vs a quarter.

    Simple meters (2/4, 3/4, 4/4) pulse every quarter; compound meters (6/8,
    9/8, 12/8) pulse every dotted quarter. ratio < 0.87 reads as simple,
    > 1.15 as compound, between is ambiguous; these cutoffs matched the
    user's ear on 3/4 vs 6/8 takes. Beats per bar (3/4 vs 4/4) is not
    detected: bar-level ACF read 6/8 takes as 3-grouped and 4/4 takes as
    unclear, so that is left to the ear.
    """
    x, sr = decode(path)
    hop_s, win = 0.010, 2048
    hop, w = int(sr * hop_s), np.hanning(win)
    lo, hi = int(80 * win / sr), int(5000 * win / sr)
    starts = np.arange(0, len(x) - win, hop)
    env = np.empty(len(starts))
    prev = None
    for k in range(0, len(starts), 2000):
        idx = starts[k:k + 2000, None] + np.arange(win)
        mag = np.log1p(30 * np.abs(np.fft.rfft(x[idx] * w, axis=1))[:, lo:hi])
        first = mag[:1] if prev is None else prev
        d = np.diff(np.vstack([first, mag]), axis=0)
        env[k:k + len(mag)] = np.maximum(d, 0).sum(axis=1)
        prev = mag[-1:]
    env -= env.mean()
    f = np.fft.rfft(env, 2 * len(env))
    acf = np.fft.irfft(f * np.conj(f))[: int(4 / hop_s)]
    acf /= acf[0]

    def peak(t):
        return acf[int(t * 0.97 / hop_s): int(t * 1.03 / hop_s) + 1].max()

    q = 60 / bpm
    r = peak(1.5 * q) / peak(q)
    compound = None if 0.87 <= r <= 1.15 else r > 1.15
    return r, compound


def transcribe(path):
    boundary = uuid.uuid4().hex
    parts = []
    for name, val in (("model", STT_MODEL), ("response_format", "json")):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{val}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="a.mp3"\r\n'
        f"Content-Type: audio/mpeg\r\n\r\n".encode() + open(path, "rb").read() + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    req = urllib.request.Request(
        f"{STT_API}/v1/audio/transcriptions", b"".join(parts),
        {"content-type": f"multipart/form-data; boundary={boundary}"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=600).read()).get("text", "")


def lyric_words(lyrics):
    return sum(len(l.split()) for l in lyrics.splitlines() if l.strip() and not l.strip().startswith("["))


def read_recipe(path):
    out = subprocess.run(
        ["ffprobe", "-loglevel", "error", "-show_entries", "format_tags=comment", "-of", "json", path],
        check=True, capture_output=True, text=True,
    ).stdout
    tag = json.loads(out).get("format", {}).get("tags", {}).get("comment")
    try:
        return json.loads(tag) if tag else None
    except json.JSONDecodeError:
        return None


def check(path, recipe):
    recipe = recipe or {}
    bpm = recipe.get("bpm")
    if bpm:
        r, compound = pulse(path, bpm)
        heard = ("ambiguous" if compound is None
                 else beat_name((6, 8) if compound else (4, 4)))
        line = f"  pulse @ {bpm} BPM: dotted/quarter ACF ratio {r:.2f} -> {heard}"
        meter = parse_meter(recipe.get("meter")) or parse_meter(recipe.get("style"))
        if meter and compound is not None:
            match = compound == is_compound(meter)
            line += f"; intended {meter_name(meter)} is {beat_name(meter)}: {'match' if match else 'MISMATCH'}"
        print(line)
    else:
        print("  meter: skipped (no BPM in recipe; put 'NN BPM' in the style or pass --bpm)")
    text = transcribe(path)
    words = text.split()
    print(f"  whisper: {len(words)} words", end="")
    if recipe and recipe.get("lyrics"):
        expected = lyric_words(recipe["lyrics"])
        ratio = len(words) / max(expected, 1)
        note = ("likely loops/repeats at the end" if ratio > 1.4
                else "lyrics missing or mumbled" if ratio < 0.6 else "ok")
        print(f" vs {expected} in lyrics ({ratio:.1f}x, {note})", end="")
    print(f"\n  first: {' '.join(words[:14])}\n  last:  {' '.join(words[-24:])}")


def cmd_render(a):
    lyrics = open(a.lyrics).read()
    style, options = a.style, {"seed": a.seed}
    plan = open(a.plan).read() if a.plan else None
    bpm = a.bpm
    meter = parse_meter(style)
    if plan:
        plan_q = plan_bpm(plan)
        meter = parse_meter(abc_header(plan, "M")) or meter
        bpm = bpm or plan_q
        if bpm != plan_q:
            plan = set_tempo(plan, bpm)
            print(f"plan written at {plan_q} BPM; at {bpm} BPM the song is {plan_q / bpm:.2f}x as long")
        options.update(cot="melody", abc=plan)
    if bpm:
        style = set_style_bpm(style, bpm)
    else:
        m = re.search(r"(\d+)\s*BPM", style)
        bpm = int(m.group(1)) if m else None
    options["style"] = style

    t = time.time()
    r = run_task(lyrics, options, 3300)
    wav = a.out + ".wav"
    open(wav, "wb").write(base64.b64decode(r["audio"]))
    recipe = {"style": style, "lyrics": lyrics, "seed": a.seed, "bpm": bpm,
              "meter": meter and meter_name(meter),
              "plan_file": a.plan and os.path.abspath(a.plan), "timing": r.get("timing")}
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame", "-q:a", "2",
         "-metadata", f"comment={json.dumps(recipe)}", a.out],
        check=True,
    )
    os.remove(wav)
    tm = r.get("timing") or {}
    print(f"{a.out}: {tm.get('audio_duration_ms', 0) / 1000:.0f}s audio in {time.time() - t:.0f}s wall")
    check(a.out, recipe)


def cmd_check(a):
    for p in a.files:
        print(p)
        recipe = read_recipe(p) or {}
        if a.bpm:
            recipe["bpm"] = a.bpm
        check(p, recipe)


def cmd_info(a):
    for p in a.files:
        recipe = read_recipe(p)
        print(f"== {p}")
        if not recipe:
            print("  (no embedded recipe)")
            continue
        for k in ("seed", "bpm", "meter", "plan_file", "timing", "style"):
            print(f"  {k}: {recipe.get(k)}")
        if a.lyrics:
            print(recipe.get("lyrics", ""))


def main():
    p = argparse.ArgumentParser(prog="yue2")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("plan", help="generate ABC melody plans only (~25s each), ranked by fit to the style's meter")
    s.add_argument("--lyrics", required=True)
    s.add_argument("--style", required=True)
    s.add_argument("--seeds", required=True, help="N or N-M")
    s.add_argument("--dir", default=".")
    s.set_defaults(fn=cmd_plan)

    s = sub.add_parser("render", help="render a song to MP3, then run check on it")
    s.add_argument("--lyrics", required=True)
    s.add_argument("--style", required=True)
    s.add_argument("--seed", type=int, required=True)
    s.add_argument("--out", required=True, help="output .mp3")
    s.add_argument("--plan", help="ABC plan from `yue2 plan`; pins melody, structure and length")
    s.add_argument("--bpm", type=int, help="tempo in quarter notes per minute; rewrites the plan's Q: and the style's 'NN BPM'")
    s.set_defaults(fn=cmd_render)

    s = sub.add_parser("check", help="simple/compound pulse check against the intended meter + Whisper lyric check")
    s.add_argument("files", nargs="+")
    s.add_argument("--bpm", type=int, help="override the BPM stored in the MP3")
    s.set_defaults(fn=cmd_check)

    s = sub.add_parser("info", help="show the recipe embedded in an MP3")
    s.add_argument("files", nargs="+")
    s.add_argument("--lyrics", action="store_true", help="also print the lyrics")
    s.set_defaults(fn=cmd_info)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
