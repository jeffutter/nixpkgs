"""Rough prosody numbers for narration clips, to compare TTS settings: present prosody a.wav ...

Prints, per clip: pitch spread (standard deviation of voiced F0 in semitones), pitch range (5th to
95th percentile, semitones), loudness spread (dB standard deviation of voiced frames), pause count
(silences over 250 ms), and words per second when a .txt with the same stem sits beside the clip.
Bigger spreads mean a less monotone read. The autocorrelation pitch tracker makes octave errors, so
treat small differences as noise and let Jeff's ear decide.
"""

import subprocess
import sys
from pathlib import Path

import numpy as np

from svgkit import FFMPEG

SR, HOP, WIN = 16000, 160, 640


def load(path):
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768


def analyse(x):
    n = (len(x) - WIN) // HOP
    frames = np.stack([x[i * HOP:i * HOP + WIN] for i in range(n)]) * np.hanning(WIN)
    db = 20 * np.log10(np.sqrt((frames ** 2).mean(1)) + 1e-9)
    voiced = db > db.max() - 30
    lo, hi = SR // 400, SR // 60
    ac = np.fft.irfft(np.abs(np.fft.rfft(frames, 2 * WIN)) ** 2)[:, :hi + 1]
    ac /= ac[:, :1] + 1e-9
    lag = lo + ac[:, lo:hi + 1].argmax(1)
    ok = voiced & (ac[np.arange(n), lag] > 0.5)
    f0 = SR / lag
    semis = 12 * np.log2(f0[ok] / np.median(f0[ok]))
    pauses, run = 0, 0
    for s in ~voiced:
        run = run + 1 if s else 0
        if run == 25:
            pauses += 1
    return semis.std(), np.percentile(semis, 95) - np.percentile(semis, 5), db[voiced].std(), pauses, len(x) / SR


print(f"{'clip':34} {'F0 sd':>6} {'F0 rng':>6} {'dB sd':>6} {'pauses':>6} {'secs':>6} {'w/s':>5}")
for p in map(Path, sys.argv[1:]):
    sd, rng, dbsd, pauses, secs = analyse(load(p))
    txt = p.with_suffix(".txt")
    wps = f"{len(txt.read_text().split()) / secs:5.2f}" if txt.is_file() else "    -"
    print(f"{p.name:34} {sd:6.2f} {rng:6.2f} {dbsd:6.2f} {pauses:6d} {secs:6.1f} {wps}")
