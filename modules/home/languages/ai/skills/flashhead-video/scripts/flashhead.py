#!/usr/bin/env python3
"""Make a talking-head MP4 from a portrait and a speech clip using
SoulX-FlashHead on the GPU host (audio.cpp behind llama-swap).

    flashhead preset:jeff-desk speech.wav out.mp4 [--model lite|pro]
    flashhead portrait.png speech.wav out.mp4 [--model lite|pro]
    flashhead portraits

The speech goes to the server inline over HTTP (16 kHz mono WAV, which is what
FlashHead consumes). The portrait cannot: audio.cpp reads it from a
server-local path only. `preset:NAME` uses /portraits/NAME.png, baked into the
GPU host's container from the portraits/ directory of its deployment config, so no
copy is needed. A local image file is copied to ~/audiocpp/io on the GPU host
over ssh instead (mounted read-only as /io). `portraits` lists the presets over
ssh. Needs ffmpeg; ssh/scp access to the GPU host only for local image files and
for `portraits`.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

HOST_SSH = os.environ["TALKING_HEAD_SSH"]
API = os.environ["TALKING_HEAD_API"].rstrip("/") + "/audioapi/v1/tasks/run"
MODELS = {
    "lite": "audio-cpp/SoulX-FlashHead-Lite",
    "pro": "audio-cpp/SoulX-FlashHead-Pro",
}


def list_portraits():
    out = subprocess.run(
        ["ssh", HOST_SSH, "ls ~/audiocpp/portraits"], check=True, capture_output=True, text=True
    ).stdout
    for name in out.split():
        print("preset:" + name.removesuffix(".png"))


def main():
    if sys.argv[1:] == ["portraits"]:
        return list_portraits()

    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("portrait", help="preset:NAME or a local image file")
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

        if args.portrait.startswith("preset:"):
            name = args.portrait.removeprefix("preset:")
            if "/" in name or not name:
                sys.exit(f"bad preset name: {name!r}")
            remote_img = f"/portraits/{name}.png"
        else:
            local = Path(args.portrait)
            if not local.is_file():
                sys.exit(f"portrait not found: {local} (use preset:NAME for a preset)")
            staged = f"{args.output.stem}{local.suffix}"
            subprocess.run(["ssh", HOST_SSH, "mkdir -p ~/audiocpp/io"], check=True)
            subprocess.run(["scp", "-q", str(local), f"{HOST_SSH}:audiocpp/io/{staged}"], check=True)
            remote_img = f"/io/{staged}"

        body = {
            "model": MODELS[args.model],
            "audio_base64": base64.b64encode(wav.read_bytes()).decode(),
            "options": {
                "reference_image_file": remote_img,
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
