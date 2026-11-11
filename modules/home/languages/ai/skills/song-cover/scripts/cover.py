"""Cover-song helper: audio -> ABC score (SheetSage2), lyric drafts (STT), plan and
reharmonization checks, and take timing. Rendering is done by the yue2 tool.

Endpoints come from the Nix wrapper (scripts/cover), see pkgs/song-cover-skill.
Everything except `status`, `transcribe`, `lyrics` and `timing` runs offline.
"""

import argparse
import base64
import collections
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

def require_env(name):
    """Return the environment variable, or exit saying which one is missing."""
    value = os.environ.get(name)
    if not value:
        sys.exit(f"{name} is not set: export it in your environment (see SKILL.md)")
    return value


AUDIOCPP = require_env("COVER_API").rstrip("/") + "/upstream/audiocpp"
SHEETSAGE_MODEL = os.environ["SHEETSAGE_MODEL"]
WORDS_MODEL = os.environ["WORDS_MODEL"]  # model that returns word timestamps
COVER_STT_API = require_env("COVER_STT_API").rstrip("/")
STT_MODEL = os.environ["STT_MODEL"]


# ------------------------------------------------------------------ http
def http(url, data=None, headers=None, timeout=900):
    req = urllib.request.Request(url, data, headers or {})
    try:
        return urllib.request.urlopen(req, timeout=timeout).read()
    except urllib.error.HTTPError as e:
        sys.exit(f"{url}: HTTP {e.code}: {e.read().decode(errors='replace')[:1500]}")
    except urllib.error.URLError as e:
        sys.exit(f"{url}: {e.reason}")


def multipart(url, fields, file_field, path, timeout=900):
    b = "----cover" + os.urandom(8).hex()
    body = b""
    for k, v in fields.items():
        body += f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    body += (f'--{b}\r\nContent-Disposition: form-data; name="{file_field}"; '
             f'filename="{os.path.basename(path)}"\r\nContent-Type: audio/wav\r\n\r\n').encode()
    body += open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    return json.loads(http(url, body, {"Content-Type": f"multipart/form-data; boundary={b}"}, timeout))


def to_wav(src, rate, dst):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", str(rate),
                    "-c:a", "pcm_s16le", dst], check=True)


# ---------------------------------------------------------------- status
def cmd_status(a):
    d = json.loads(http(f"{AUDIOCPP}/v1/models", timeout=60))
    want = ("SheetSage2", "Yue2", "parakeet")
    for m in d["data"]:
        if any(w.lower() in m["id"].lower() for w in want):
            print(f"{m['id']:45} loaded={m.get('loaded')}")
    print("loaded=False is normal: the first call loads the model and takes a few minutes.")


# ------------------------------------------------------------ transcribe
def cmd_transcribe(a):
    """Audio -> ABC. SheetSage2 takes WAV only, uploaded through the UI endpoint first.
    Use the FP32 model: the Q8 build changes notes."""
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "upload.wav")
        to_wav(a.audio, 44100, wav)
        up = json.loads(http(f"{AUDIOCPP}/v1/ui/upload", open(wav, "rb").read(),
                             {"Content-Type": "audio/wav", "X-AudioCPP-Filename": "upload.wav"}, 300))
    r = json.loads(http(f"{AUDIOCPP}/v1/tasks/run",
                        json.dumps({"model": SHEETSAGE_MODEL,
                                    "request": {"audio": up["path"], "options": {}}}).encode(),
                        {"content-type": "application/json"}, 1800))
    abc = r["text"]
    open(a.out, "w").write(abc if abc.endswith("\n") else abc + "\n")
    p = parse_abc(abc)
    print(f"wrote {a.out} ({r.get('timing', {}).get('wall_ms', 0) / 1000:.0f}s)")
    print(f"meter {p['meter']}  Q {p['q']}  key {p['key']}  vocal notes {sum(len(n) for _, n in p['sections'])}")
    print("sections:", ", ".join(f"{n}={len(notes)} notes" for n, notes in p["sections"]))
    print(f"chords used: {' '.join(sorted(set(c for _, _, c in p['chords'])))}")


# ------------------------------------------------------------------ lyrics
def cmd_lyrics(a):
    """Draft lyrics from the recording with STT. It has no sections and mishears; the
    agent must restructure the draft and the user must confirm it."""
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        to_wav(a.audio, 16000, wav)
        r = multipart(f"{COVER_STT_API}/v1/audio/transcriptions", {"model": STT_MODEL}, "file", wav, 600)
    text = r["text"].strip()
    open(a.out, "w").write(text + "\n")
    print(f"wrote {a.out}: {len(text.split())} words (draft, unstructured, may contain mishearings)")


# ----------------------------------------------------------------- ABC parse
PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
SHARP_ORDER = "FCGDAEB"
FLAT_ORDER = "BEADGCF"
# (tonic semitone, minor?) -> signed accidental count (+ sharps, - flats)
MAJOR_FIFTHS = {"C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5, "F#": 6, "C#": 7,
                "F": -1, "Bb": -2, "Eb": -3, "Ab": -4, "Db": -5, "Gb": -6, "Cb": -7}
MINOR_FIFTHS = {"A": 0, "E": 1, "B": 2, "F#": 3, "C#": 4, "G#": 5, "D#": 6, "A#": 7,
                "D": -1, "G": -2, "C": -3, "F": -4, "Bb": -5, "Eb": -6, "Ab": -7}


def key_signature(k):
    m = re.match(r"\s*([A-G][#b]?)\s*(m|min|minor|mix|dor|lyd|phr|loc)?", k)
    tonic, mode = m.group(1), (m.group(2) or "")
    n = (MINOR_FIFTHS if mode.startswith("m") else MAJOR_FIFTHS).get(tonic, 0)
    if mode in ("mix", "dor", "lyd", "phr", "loc"):
        shift = {"mix": -1, "dor": -2, "lyd": 1, "phr": -4, "loc": -5}[mode]
        n = MAJOR_FIFTHS.get(tonic, 0) + shift - 0  # approximate; rare in transcriptions
    return {x: 1 for x in SHARP_ORDER[:n]} if n >= 0 else {x: -1 for x in FLAT_ORDER[:-n]}


TOK = re.compile(r'"([^"]*)"|([_^=]*)([A-Ga-g])([,\']*)(\d*)(/?\d*)(-?)|z(\d*)|Z(\d*)|(\|)')


def parse_abc(text):
    """Vocal voice only. -> dict(meter, q, key, sections[(name, notes)], chords[(sec, bar, name)]).
    A note is (onset16ths_in_section_chain, duration, pitch_class). Ties are merged.
    Notes carry bar-local accidentals and the key signature."""
    meter, q, key, unit = None, None, "C", 16
    voice, sec, sections, chords = None, None, [], []
    sig, acc, t, bar, tie, bar_units, last = {}, {}, 0, 0, False, 12, None
    for line in text.splitlines():
        if line.startswith("M:"): meter = line[2:].strip()
        elif line.startswith("L:"): unit = int(line[2:].split("/")[1])
        elif line.startswith("Q:"): q = line[2:].strip()
        elif line.startswith("K:"):
            key = line[2:].strip(); sig = key_signature(key)
            if meter and "/" in meter:
                num, den = (int(x) for x in meter.split("/"))
                bar_units = num * unit // den
        elif line.startswith("V:") and "clef" not in line: voice = line.split()[1]
        elif line.startswith("%"):
            sec = [line[1:].strip(), []]; sections.append(sec)
        elif voice == "Vocal" and not re.match(r"[A-Za-z]:", line):
            if sec is None: sec = ["start", []]; sections.append(sec)
            for m in TOK.finditer(line):
                if m.group(1) is not None:
                    chords.append((sec[0], bar, m.group(1)))
                elif m.group(3):
                    a, n = m.group(2), m.group(3).upper()
                    pc = PC[n] + (sig.get(n, 0) if not a else 0)
                    if a: acc[n] = a; pc += {"^": 1, "_": -1, "=": 0}[a[-1]]
                    elif n in acc: pc += {"^": 1, "_": -1, "=": 0}[acc[n][-1]]
                    d = int(m.group(5) or 1)
                    if tie and last: last[1] += d
                    else:
                        last = [t, d, pc % 12]; sec[1].append(last)
                    tie = bool(m.group(7)); t += d
                elif m.group(8) is not None:
                    t += int(m.group(8) or 1)
                elif m.group(9) is not None:
                    t += bar_units * int(m.group(9) or 1)
                elif m.group(10):
                    acc = {}; bar += 1
    return dict(meter=meter, q=q, key=key, sections=[(n, s) for n, s in sections], chords=chords, unit=unit)


# ------------------------------------------------------------ fit (lyrics)
def syllables(word):
    w = re.sub(r"[^a-z']", "", word.lower())
    if not w: return 0
    n = len(re.findall(r"[aeiouy]+", w))
    if w.endswith("e") and not w.endswith(("le", "ee")) and n > 1: n -= 1
    return max(n, 1)


def lyric_sections(path):
    secs, cur = [], None
    for l in open(path).read().splitlines():
        m = re.match(r"\s*\[([^\]:]+)", l)
        if m: cur = [m.group(1).strip(), []]; secs.append(cur)
        elif l.strip() and cur is not None: cur[1].append(l.strip())
    return secs


def cmd_fit(a):
    """Notes in each sung plan section against syllables in the matching lyric section."""
    p = parse_abc(open(a.plan).read())
    sung = [(n, notes) for n, notes in p["sections"] if notes]
    ly = lyric_sections(a.lyrics)
    print(f"plan: {len(sung)} sung sections, lyrics: {len(ly)} sections")
    if len(sung) != len(ly):
        print("  section counts differ: the plan sections and the lyric sections will not pair up one to one.")
    for i, (n, notes) in enumerate(sung):
        if i >= len(ly): print(f"  plan {n}: {len(notes)} notes, no lyric section"); continue
        lines = ly[i][1]
        syl = sum(syllables(w) for l in lines for w in l.split())
        ratio = syl / max(len(notes), 1)
        flag = "ok" if 0.8 <= ratio <= 1.15 else "words crowd the melody" if ratio > 1.15 else "melody has spare notes (melisma)"
        print(f"  plan {n:8} {len(notes):3} notes | lyrics [{ly[i][0]}] {len(lines)} lines {syl:3} syllables | {ratio:.2f} {flag}")
    print("A ratio near 1.0 is the best case. Counts cannot prove that words land on the right notes; the user's ear decides.")


# ------------------------------------------------------- chord vocabulary
QUAL = {  # quality -> chord tones (semitones above root)
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10),
    "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9), "9": (0, 4, 7, 10, 2), "m9": (0, 3, 7, 10, 2),
    "maj9": (0, 4, 7, 11, 2), "7sus4": (0, 5, 7, 10), "sus4": (0, 5, 7), "sus2": (0, 2, 7),
    "dim": (0, 3, 6), "m7b5": (0, 3, 6, 10), "add9": (0, 4, 7, 2), "5": (0, 7),
    "11": (0, 4, 7, 10, 2, 5), "m11": (0, 3, 7, 10, 2, 5), "13": (0, 4, 7, 10, 2, 9),
    "6/9": (0, 4, 7, 9, 2), "maj7#11": (0, 4, 7, 11, 6), "m(maj7)": (0, 3, 7, 11),
}
SAFE = {"", "m", "7", "maj7", "m7", "6", "m6", "9", "m9", "maj9", "7sus4", "sus4", "5", "add9", "m7b5", "dim"}


def chord_pcs(name):
    """-> (root pc, bass pc, quality, set of pcs) or None when the symbol is not understood."""
    m = re.match(r"^([A-G][#b]?)(.*?)(?:/([A-G][#b]?))?$", name)
    if not m: return None
    def pc(s): return (PC[s[0]] + {"#": 1, "b": -1}.get(s[1:], 0)) % 12
    root, qual, bass = pc(m.group(1)), m.group(2), m.group(3)
    if qual not in QUAL: return None
    s = {(root + i) % 12 for i in QUAL[qual]}
    # tensions a vocal line may sit on: 9th, 11th, 13th (and #11 over major chords)
    if qual not in ("dim", "5"):
        s |= {(root + i) % 12 for i in ((2, 6, 9) if "maj" in qual or qual in ("", "6", "6/9", "add9") else (2, 5, 9))}
    b = pc(bass) if bass else root
    s.add(b)
    return root, b, qual, s


def cmd_reharm_check(a):
    """Verify a reharmonized ABC keeps the melody and that every chord fits the notes it covers."""
    def strip(t): return [re.sub(r'"[^"]*"', "", l) for l in t.splitlines()
                          if not l.startswith("w:")]
    o, n = open(a.original).read(), open(a.new).read()
    same = strip(o) == strip(n)
    print("melody identical to original (chords stripped):", "YES" if same else "NO")
    if not same:
        ol, nl = strip(o), strip(n)
        for i, (x, y) in enumerate(zip(ol, nl)):
            if x != y: print(f"  first difference at line {i + 1}:\n   orig {x[:100]}\n   new  {y[:100]}"); break
        else: print(f"  line counts differ: {len(ol)} vs {len(nl)} (sections added or removed)")
    p = parse_abc(n)
    # chord covers the vocal notes from its position to the next chord; position by re-walking
    # the vocal lines with note onsets.
    spans = chord_spans(n, p)
    worst, unknown, risky = [], set(), set()
    for name, notes in spans:
        c = chord_pcs(name)
        if c is None: unknown.add(name); continue
        if c[2] not in SAFE or ("/" in name and c[1] != c[0] and c[2] not in SAFE): risky.add(name)
        tot = sum(d for d, _ in notes)
        out = sum(d for d, pc in notes if pc not in c[3])
        if tot and out / tot > a.tolerance: worst.append((out / tot, name, tot))
    print(f"chord symbols: {len(set(x for x, _ in spans))} distinct, {len(spans)} instances")
    print("  vocabulary:", " ".join(sorted(set(x for x, _ in spans))))
    if unknown: print("  not understood by this checker (check by hand):", " ".join(sorted(unknown)))
    if risky:
        print("  outside the safe vocabulary (in this session's tests, exotic symbols such as 13sus4 or stacked slash chords"
              " made YuE2 drift off the plan's timeline):", " ".join(sorted(risky)))
    print(f"  chords with more than {a.tolerance:.0%} of the covered melody outside the chord and its tensions: {len(worst)}")
    for r, name, tot in sorted(worst, reverse=True)[:12]: print(f"    {name:12} {r:.0%} of {tot} sixteenths")


def chord_spans(text, parsed):
    """[(chord name, [(duration, pc)])] with notes assigned to the chord in force at their onset."""
    sig = key_signature(parsed["key"]); voice = None; acc = {}
    cur, spans, tie = None, [], False
    for line in text.splitlines():
        if line.startswith("V:") and "clef" not in line: voice = line.split()[1]
        elif voice == "Vocal" and not re.match(r"[A-Za-z]:", line) and not line.startswith("%"):
            for m in TOK.finditer(line):
                if m.group(1) is not None: cur = [m.group(1), []]; spans.append(cur)
                elif m.group(3):
                    a_, n = m.group(2), m.group(3).upper()
                    pc = PC[n] + (sig.get(n, 0) if not a_ else 0)
                    if a_: acc[n] = a_; pc += {"^": 1, "_": -1, "=": 0}[a_[-1]]
                    elif n in acc: pc += {"^": 1, "_": -1, "=": 0}[acc[n][-1]]
                    if cur: cur[1].append((int(m.group(5) or 1), pc % 12))
                elif m.group(10): acc = {}
    return [(n, notes) for n, notes in spans]


# ------------------------------------------------------------------ timing
def cmd_timing(a):
    """Word onsets of a rendered take (Parakeet word timestamps) against the plan's expected length."""
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "t.wav")
        to_wav(a.take, 16000, wav)
        r = multipart(f"{AUDIOCPP}/v1/audio/transcriptions/details", {"model": WORDS_MODEL}, "file", wav, 600)
    sr = r["sample_rate"]
    t = [w["start_sample"] / sr for w in r["words"]]
    if not t: sys.exit("no words found: the take may be instrumental or the lyrics were dropped")
    print(f"words {len(t)}  first {t[0]:.1f}s  last {t[-1]:.1f}s")
    gaps = [(round(x, 1), round(y, 1)) for x, y in zip(t, t[1:]) if y - x > a.gap]
    print(f"gaps over {a.gap:.0f}s:", gaps or "none")
    if a.plan:
        p = parse_abc(open(a.plan).read())
        total16 = 0
        for _, notes in p["sections"]:
            for on, d, _ in notes: total16 = max(total16, on + d)
        bpm = a.bpm or float(re.search(r"=(\d+)", p["q"]).group(1))
        end = total16 / p["unit"] * 4 * (60 / bpm)  # unit 16 -> a sixteenth is a quarter of a beat
        print(f"last vocal note in the plan ends at about {end:.1f}s at {bpm:.0f} BPM; last sung word at {t[-1]:.1f}s")
        if t[-1] > end + 8: print("  the take runs long: likely drift off the plan's timeline")
    if a.json: json.dump(r, open(a.json, "w"))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status", help="which audio.cpp models are configured and loaded").set_defaults(f=cmd_status)
    s = sub.add_parser("transcribe", help="audio -> ABC score with SheetSage2")
    s.add_argument("audio"); s.add_argument("--out", required=True); s.set_defaults(f=cmd_transcribe)
    s = sub.add_parser("lyrics", help="draft lyrics from the recording with STT")
    s.add_argument("audio"); s.add_argument("--out", required=True); s.set_defaults(f=cmd_lyrics)
    s = sub.add_parser("fit", help="notes vs syllables per section (offline)")
    s.add_argument("plan"); s.add_argument("lyrics"); s.set_defaults(f=cmd_fit)
    s = sub.add_parser("reharm-check", help="melody unchanged and chords fit it (offline)")
    s.add_argument("original"); s.add_argument("new")
    s.add_argument("--tolerance", type=float, default=0.12); s.set_defaults(f=cmd_reharm_check)
    s = sub.add_parser("timing", help="word timing of a rendered take")
    s.add_argument("take"); s.add_argument("--plan"); s.add_argument("--bpm", type=float)
    s.add_argument("--gap", type=float, default=6); s.add_argument("--json"); s.set_defaults(f=cmd_timing)
    a = ap.parse_args(); a.f(a)


if __name__ == "__main__":
    main()
