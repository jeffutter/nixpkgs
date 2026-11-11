#!/usr/bin/env python3
"""Speech-to-text through an OpenAI-compatible /v1/audio/transcriptions endpoint.

Stdlib only. The endpoint is a base URL read from the STT_API environment variable;
--api overrides it.
"""
import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
import uuid

DEFAULT_API = os.environ.get("STT_API")
ASR_MARKERS = ("parakeet", "whisper", "nemotron-asr", "crisperwhisper", "canary", "asr")


def base_url(api: str) -> str:
    """Accept a bare host, host:port, a base URL, or a URL ending in /v1."""
    api = api.rstrip("/")
    if "://" not in api:
        api = "http://" + api
    if not api.endswith("/v1"):
        api += "/v1"
    return api


def cmd_models(args):
    with urllib.request.urlopen(base_url(args.api) + "/models", timeout=30) as r:
        data = json.load(r)["data"]
    for m in data:
        if any(k in m["id"] for k in ASR_MARKERS):
            aliases = (m.get("meta", {}).get("llamaswap", {}) or {}).get("aliases") or []
            print(m["id"] + (f"  (aliases: {', '.join(aliases)})" if aliases else ""))


def multipart(fields: dict, filename: str, content: bytes):
    boundary = uuid.uuid4().hex
    ctype = mimetypes.guess_type(filename)[0] or "application/octet-stream"
    parts = []
    for k, v in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(filename)}"\r\n'
        f"Content-Type: {ctype}\r\n\r\n".encode()
        + content
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def cmd_transcribe(args):
    multiple = len(args.files) > 1
    for path in args.files:
        with open(path, "rb") as f:
            content = f.read()
        fields = {"model": args.model}
        if args.language:
            fields["language"] = args.language
        body, ctype = multipart(fields, path, content)
        req = urllib.request.Request(
            base_url(args.api) + "/audio/transcriptions", data=body, headers={"Content-Type": ctype}
        )
        try:
            with urllib.request.urlopen(req, timeout=args.timeout) as r:
                result = json.load(r)
        except urllib.error.HTTPError as e:
            sys.exit(f"{path}: HTTP {e.code}: {e.read().decode(errors='replace')[:500]}")
        # The server returns JSON whatever response_format asks for.
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            if multiple:
                print(f"== {path}")
            print(result.get("text", "").strip())
            t = result.get("timing", {})
            if t:
                print(
                    f"model={args.model} audio={t.get('audio_duration_ms', 0) / 1000:.1f}s "
                    f"wall={t.get('wall_ms', 0) / 1000:.1f}s",
                    file=sys.stderr,
                )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--api", default=DEFAULT_API, help="base URL (default: $STT_API)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("models", help="list speech-to-text models the endpoint serves").set_defaults(fn=cmd_models)
    s = sub.add_parser("transcribe", help="transcribe audio files to text on stdout")
    s.add_argument("files", nargs="+", help="audio files (mp3, m4a, wav, ...)")
    s.add_argument("--model", default="parakeet")
    s.add_argument("--language", help="language hint, e.g. en")
    s.add_argument("--json", action="store_true", help="print the full JSON response")
    s.add_argument("--timeout", type=int, default=600)
    s.set_defaults(fn=cmd_transcribe)
    args = p.parse_args()
    if not args.api:
        sys.exit("no endpoint: set STT_API or pass --api URL")
    args.fn(args)


if __name__ == "__main__":
    main()
