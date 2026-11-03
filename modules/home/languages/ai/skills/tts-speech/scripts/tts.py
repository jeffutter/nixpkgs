#!/usr/bin/env python3
"""Text-to-speech through an OpenAI-compatible /v1/audio/speech endpoint.

Stdlib only. The endpoint is a base URL (llama-swap by default); --api or the
TTS_API environment variable points it elsewhere.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_API = os.environ.get("TTS_API", "https://llama.home.jeffutter.com/v1")
TTS_MARKERS = ("tts", "breeze", "higgs", "kokoro")


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
        name = m["id"]
        if any(k in name for k in TTS_MARKERS) and name != "tts-1" and name != "tts":
            aliases = (m.get("meta", {}).get("llamaswap", {}) or {}).get("aliases") or []
            print(name + (f"  (aliases: {', '.join(aliases)})" if aliases else ""))


def cmd_say(args):
    if args.file:
        text = sys.stdin.read() if args.file == "-" else open(args.file, encoding="utf-8").read()
    else:
        text = args.text
    text = (text or "").strip()
    if not text:
        sys.exit("no input text: pass TEXT or --file")
    body = {"model": args.model, "input": text, "voice": args.voice, "response_format": args.format}
    for kv in args.option:
        key, _, val = kv.partition("=")
        try:
            val = json.loads(val)
        except ValueError:
            pass
        body[key] = val
    req = urllib.request.Request(
        base_url(args.api) + "/audio/speech",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as r:
            audio = r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')[:500]}")
    out = args.out or f"speech-{args.model}-{args.voice}.{args.format}"
    with open(out, "wb") as f:
        f.write(audio)
    print(out)
    print(f"model={args.model} voice={args.voice} bytes={len(audio)}", file=sys.stderr)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--api", default=DEFAULT_API, help="base URL (default: %(default)s)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("models", help="list TTS models the endpoint serves").set_defaults(fn=cmd_models)
    s = sub.add_parser("say", help="synthesize speech to a file")
    s.add_argument("text", nargs="?", help="text to speak (or use --file)")
    s.add_argument("--file", help="read text from this file, or - for stdin")
    s.add_argument("--model", default="breeze")
    s.add_argument("--voice", default="jeff")
    s.add_argument("--format", default="mp3", choices=["mp3", "wav", "opus", "aac", "flac", "pcm"])
    s.add_argument("--option", action="append", default=[], metavar="KEY=VALUE",
                   help="extra request field, VALUE read as JSON when it parses (repeatable)")
    s.add_argument("--timeout", type=int, default=600)
    s.add_argument("--out")
    s.set_defaults(fn=cmd_say)
    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
