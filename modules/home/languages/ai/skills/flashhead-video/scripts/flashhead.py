#!/usr/bin/env python3
"""Make a talking-head MP4 from a portrait image and a speech clip using
SoulX-FlashHead on the dgx-spark (audio.cpp behind llama-swap).

    flashhead portrait.png speech.wav out.mp4 [--model lite|pro]

audio.cpp only reads server-local paths, so both inputs are copied to
~/audiocpp/io on the spark over ssh (mounted read-only as /io in the
container). The speech is converted to 16 kHz mono WAV first, which is what
FlashHead consumes. Needs ffmpeg and ssh/scp access to the spark.
"""

import argparse
import base64
import json
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import os

SPARK_SSH = os.environ["FLASHHEAD_SSH"]
API = os.environ["FLASHHEAD_API"].rstrip("/") + "/audioapi/v1/tasks/run"
MODELS = {
    "lite": "audio-cpp/SoulX-FlashHead-Lite",
    "pro": "audio-cpp/SoulX-FlashHead-Pro",
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("portrait", type=Path)
    ap.add_argument("audio", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--model", choices=MODELS, default="pro")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--size", type=int, default=512, help="square output size, divisible by 32")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory(prefix="flashhead-") as tmp:
        wav = Path(tmp) / "speech.wav"
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(args.audio), "-ar", "16000", "-ac", "1", str(wav)],
            check=True,
        )
        stem = args.output.stem
        suffix = args.portrait.suffix
        remote_wav, remote_img = f"{stem}.wav", f"{stem}{suffix}"
        subprocess.run(["ssh", SPARK_SSH, "mkdir -p ~/audiocpp/io"], check=True)
        subprocess.run(
            ["scp", "-q", str(wav), f"{SPARK_SSH}:audiocpp/io/{remote_wav}"], check=True
        )
        subprocess.run(
            ["scp", "-q", str(args.portrait), f"{SPARK_SSH}:audiocpp/io/{remote_img}"], check=True
        )

        body = {
            "model": MODELS[args.model],
            "audio": f"/io/{remote_wav}",
            "options": {
                "reference_image_file": f"/io/{remote_img}",
                "width": args.size,
                "height": args.size,
                "seed": args.seed,
            },
        }
        req = urllib.request.Request(
            API, json.dumps(body).encode(), {"content-type": "application/json"}
        )
        try:
            result = json.loads(urllib.request.urlopen(req, timeout=3600).read())
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')[:2000]}")

        arts = sorted(
            (a for a in result["artifacts"] if a["id"].startswith("soulx_flashhead_video_")),
            key=lambda a: int(a["meta"]["chunk_index"]),
        )
        if not arts:
            sys.exit("no video artifacts in response: " + json.dumps(result)[:500])
        first = arts[0]["meta"]
        cmd = [
            "ffmpeg", "-v", "error", "-y",
            "-f", "rawvideo", "-pixel_format", "rgb24",
            "-video_size", f"{first['width']}x{first['height']}",
            "-framerate", first["fps"], "-i", "pipe:0",
            "-i", str(wav), "-c:a", "aac", "-shortest",
            "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", str(args.output),
        ]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with subprocess.Popen(cmd, stdin=subprocess.PIPE) as p:
            # Video comes in whole 24-frame blocks, so it can outrun the audio;
            # -shortest then makes ffmpeg exit early and close the pipe.
            try:
                for a in arts:
                    p.stdin.write(base64.b64decode(a["payload"]))
                p.stdin.close()
            except BrokenPipeError:
                pass
            if p.wait():
                sys.exit("ffmpeg failed")
    print(args.output)


if __name__ == "__main__":
    main()
