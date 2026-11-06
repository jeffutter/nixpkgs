"""Write an A/B pair for one narration clip: plain de-noise versus the speech chain the assembler uses.

present ab-speech <scene-id>    -> out/ab-<id>-raw.wav, out/ab-<id>-chain.wav
"""

import subprocess
import sys

sid = sys.argv[1]
sys.argv = [sys.argv[0]]
import video  # noqa: E402

from svgkit import AUDIO_DIR, FFMPEG, ROOT  # noqa: E402

src = ROOT / AUDIO_DIR / f"{sid}.opus"
raw = ROOT / "out" / f"ab-{sid}-raw.wav"
chain = ROOT / "out" / f"ab-{sid}-chain.wav"
raw.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([FFMPEG, "-y", "-v", "error", "-i", src, "-af",
                "highpass=f=70,afftdn=nr=12:nf=-50:tn=1,loudnorm=I=-20:TP=-2", "-ar", "48000", raw], check=True)
video.clean_narration(src, chain)
print(raw, chain)
