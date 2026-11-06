"""Find the beat phase of a take and print the level of each bar, to pick bar-aligned cuts.

present music-scan music/take.mp3 [bpm]   (bpm defaults to 120; use the tempo the take was rendered at)
"""

import array
import math
import subprocess
import sys

from svgkit import FFMPEG

RATE = 8000
path = sys.argv[1]
bpm = float(sys.argv[2]) if len(sys.argv) > 2 else 120.0
pcm = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
                     capture_output=True, check=True).stdout
x = array.array("h", pcm)
hop = RATE // 100  # 10 ms frames
env = [math.sqrt(sum(v * v for v in x[i:i + hop]) / hop) for i in range(0, len(x) - hop, hop)]
flux = [max(0.0, env[i] - env[i - 1]) for i in range(1, len(env))]
beat = 60.0 / bpm
# Beat phase: the offset whose beat grid collects the most onset energy.
best = max(range(int(beat * 100)), key=lambda o: sum(flux[int(o + k * beat * 100)]
                                                    for k in range(int(len(flux) / (beat * 100)) - 1)))
phase = best / 100
bar = beat * 4
print(f"length {len(x) / RATE:.2f}s, beat {beat:.4f}s, bar {bar:.3f}s, phase {phase:.2f}s")
for b in range(int((len(x) / RATE - phase) / bar)):
    t = phase + b * bar
    seg = env[int(t * 100):int((t + bar) * 100)]
    db = 20 * math.log10(max(1.0, sum(seg) / len(seg)) / 32768)
    print(f"bar {b:3} {t:6.2f}s {db:6.1f} dB {'#' * max(0, int(db + 40))}")
