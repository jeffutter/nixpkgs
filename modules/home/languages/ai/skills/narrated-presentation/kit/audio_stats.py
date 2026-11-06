"""Per-clip loudness and band balance, to compare narration clips and music cuts.

present audio-stats [file ...]   (default: every scene's audio in scene order)
Columns: integrated LUFS, then RMS dB in four bands relative to the clip's full-band RMS.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

from svgkit import AUDIO_DIR, FFMPEG, ROOT

BANDS = {"<250": "lowpass=f=250", "250-1k": "highpass=f=250,lowpass=f=1000",
         "1k-4k": "highpass=f=1000,lowpass=f=4000", ">4k": "highpass=f=4000"}


def ff(args):
    return subprocess.run([FFMPEG, "-hide_banner", "-nostats", *args], capture_output=True, text=True).stderr


def rms(path, chain):
    err = ff(["-i", str(path), "-af", f"{chain}astats=measure_overall=RMS_level:measure_perchannel=0",
              "-f", "null", "-"])
    return float(re.findall(r"RMS level dB: (-?[\d.]+|-inf)", err)[-1])


def lufs(path):
    err = ff(["-i", str(path), "-af", "ebur128", "-f", "null", "-"])
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


files = [Path(f) for f in sys.argv[1:]]
if not files:
    scenes = json.loads((ROOT / "scenes.json").read_text())["scenes"]
    files = [ROOT / (s["audio"] if s.get("audio") else f"{AUDIO_DIR}/{s['id']}.opus") for s in scenes]
print(f"{'file':40} {'LUFS':>6} " + " ".join(f"{b:>7}" for b in BANDS))
for f in files:
    full = rms(f, "")
    print(f"{f.stem[:40]:40} {lufs(f):6.1f} " + " ".join(f"{rms(f, c + ',') - full:7.1f}" for c in BANDS.values()))
