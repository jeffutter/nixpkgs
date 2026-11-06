"""Cut every music scene and the beds around it from one take: present music

Run after `present video voice` and the visuals: the pre-roll bed length depends on the scene before.
Reads music.json in the project root:

  {
    "take": "music/take.mp3",
    "bpm": 126,                         the tempo the take was rendered at
    "gain_window": [28.8, 46.0],        loudest stretch with vocals; sets the one shared gain
    "music_lufs": -22.0,                that stretch's loudness after gain (speech is -20)
    "cuts": {
      "<music scene id>": {"start": 28.40, "length": 19.60},
      "<bumper id>": {"start": 15.49, "bars": 4},
      "<quiet bumper id>": {"start": 45.96, "bars": 4, "extra_db": 5.0},
      "<outro id>": {"start": 61.20, "to_end": true, "fade_out": 3.0}
    }
  }

Times come from `present music-scan <take> <bpm>`; start cuts on a bar line. A cut writes to the
path in its scene's `Audio:` line. Every cut shares one gain so the take keeps its dynamics;
extra_db lifts one quiet cut. The scene after a music scene gets a bed that continues the take,
holds full level briefly, ducks under the voice and fades out. The scene before one gets a pre-roll
that fades the take in and lines up sample for sample with the music scene, so the crossfade is
seamless. A scene between two music scenes gets both, summed.
"""

import json
import os
import re
import subprocess
from pathlib import Path

from svgkit import AUDIO_DIR, FFMPEG, FFPROBE

ROOT = Path(os.environ.get("PRESENT_ROOT", Path.cwd()))
TRANSITION, TAIL, LEAD = 0.8, 1.3, 0.4  # must match video.py
PRE_ROLL = 2.2  # seconds of fade-in at the end of the scene before a music scene
BED_FULL, BED_DUCK, BED_DUCK_DB, BED_END = 0.9, 1.3, -12.0, 4.5

cfg = json.loads((ROOT / "music.json").read_text())
TAKE = ROOT / cfg["take"]
BPM = cfg.get("bpm", 120.0)
BAR = 4 * 60 / BPM


def ff(*args):
    return subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-y", *map(str, args)],
                          capture_output=True, text=True, check=True).stderr


def lufs(start, length):
    err = ff("-ss", start, "-t", length, "-i", TAKE, "-af", "ebur128", "-f", "null", "-")
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def seconds(path):
    return float(subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                 str(path)], capture_output=True, text=True, check=True).stdout)


def cut(dst, start, length, envelope, pad=0.0, extra=0.0):
    """Take [start, start+length) with a volume envelope (expression in t), after pad s of silence."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    chain = (f"volume={GAIN + extra:.2f}dB,volume='{envelope}':eval=frame,aresample=48000,"
             f"aformat=channel_layouts=stereo")
    if pad > 0:
        chain += f",adelay={int(pad * 1000)}|{int(pad * 1000)}"
    ff("-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", TAKE, "-af", chain, "-c:a", "pcm_s16le", dst)


def mix_beds(pieces):
    """Write each bed file; a scene between two music scenes gets both its pieces summed."""
    for dst, parts in pieces.items():
        if len(parts) == 1:
            cut(dst, *parts[0])
            continue
        tmps = []
        for k, part in enumerate(parts):
            tmp = dst.with_name(f"{dst.stem}.part{k}.wav")
            cut(tmp, *part)
            tmps.append(tmp)
        args = [x for t in tmps for x in ("-i", t)]
        ff(*args, "-filter_complex", f"amix=inputs={len(tmps)}:duration=longest:normalize=0", "-c:a", "pcm_s16le", dst)
        for t in tmps:
            t.unlink()


a, b = cfg["gain_window"]
GAIN = cfg.get("music_lufs", -22.0) - lufs(a, b - a)
take_len = seconds(TAKE)
scenes = json.loads((ROOT / "scenes.json").read_text())["scenes"]
index = {s["id"]: i for i, s in enumerate(scenes)}
duck = 10 ** (BED_DUCK_DB / 20)
beds = {}
for sid, c in cfg["cuts"].items():
    i = index[sid]
    start, extra = c["start"], c.get("extra_db", 0.0)
    length = take_len - start if c.get("to_end") else c.get("length", c.get("bars", 4) * BAR)
    fo = c.get("fade_out", 0.0)
    envelope = f"if(gt(t,{length - fo:.3f}),max(0,({length:.3f}-t)/{fo}),1)" if fo else "1"
    cut(ROOT / scenes[i]["audio"], start, length, envelope, extra=extra)
    print(f"{scenes[i]['audio']}: take {start:.2f}-{start + length:.2f}s")
    nxt = scenes[i + 1] if i + 1 < len(scenes) else None
    if nxt and nxt.get("bed"):
        env = (f"if(lt(t,{BED_FULL}),1,if(lt(t,{BED_DUCK}),1-(1-{duck:.3f})*(t-{BED_FULL})/{BED_DUCK - BED_FULL:.2f},"
               f"{duck:.3f}*max(0,({BED_END}-t)/{BED_END - BED_DUCK:.2f})))")
        beds.setdefault(ROOT / nxt["bed"], []).append((start + length - TRANSITION, BED_END, env, 0.0, extra))
        print(f"  {nxt['bed']}: continues from {start + length - TRANSITION:.2f}s")
    prev = scenes[i - 1] if i > 0 else None
    if prev and prev.get("bed") and not prev.get("music"):
        prev_len = prev.get("lead", LEAD) + seconds(ROOT / AUDIO_DIR / f"{prev['id']}.opus") + TAIL
        if prev["visual"].endswith(".mp4"):  # the assembler holds a scene for its whole video
            prev_len = max(prev_len, seconds(ROOT / prev["visual"]))
        take_from = start - PRE_ROLL + TRANSITION
        beds.setdefault(ROOT / prev["bed"], []).append((take_from, PRE_ROLL, f"pow(t/{PRE_ROLL},2)",
                                                        prev_len - PRE_ROLL, extra))
        print(f"  {prev['bed']}: fades in from {take_from:.2f}s over the last {PRE_ROLL}s of {prev_len:.2f}s")
mix_beds(beds)
print(f"gain {GAIN:+.2f} dB")
