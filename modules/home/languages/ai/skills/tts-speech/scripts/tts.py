#!/usr/bin/env python3
"""Text-to-speech through an OpenAI-compatible /v1/audio/speech endpoint.

Stdlib plus curl on PATH. The endpoint is a base URL read from the TTS_API environment
variable (the skill wrapper sets it); --api overrides it.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.request

DEFAULT_API = os.environ.get("TTS_API")
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
    out = args.out or f"speech-{args.model}-{args.voice}.{args.format}"
    audio = fetch(base_url(args.api) + "/audio/speech", json.dumps(body), args.timeout, out)
    print(out)
    print(f"model={args.model} voice={args.voice} bytes={audio}", file=sys.stderr)


# Exit codes where curl saw a short or reset body: retry. HTTP errors (22) are final.
RETRY_EXIT = {18, 52, 55, 56, 92}


def fetch(url: str, payload: str, timeout: int, out: str, attempts: int = 3) -> int:
    """POST with curl and write OUT only after curl reports a complete body.

    The sandbox egress proxy truncates urllib reads of this endpoint; curl does not, and
    exits 18 on a short body.
    """
    tmp = out + ".part"
    for attempt in range(1, attempts + 1):
        proc = subprocess.run(
            ["curl", "-sS", "--fail-with-body", "--max-time", str(timeout), "-X", "POST",
             "-H", "Content-Type: application/json", "--data-binary", "@-", "-o", tmp, url],
            input=payload.encode(), capture_output=True,
        )
        if proc.returncode == 0 and os.path.getsize(tmp) > 0:
            os.replace(tmp, out)
            return os.path.getsize(out)
        if proc.returncode == 22:
            msg = open(tmp, encoding="utf-8", errors="replace").read()[:500] if os.path.exists(tmp) else ""
            os.path.exists(tmp) and os.remove(tmp)
            sys.exit(f"HTTP error: {msg or proc.stderr.decode(errors='replace')[:500]}")
        print(f"attempt {attempt}/{attempts} failed (curl exit {proc.returncode})", file=sys.stderr)
        if proc.returncode not in RETRY_EXIT and proc.returncode != 0:
            break
    if os.path.exists(tmp):
        os.remove(tmp)
    sys.exit(f"download failed: {proc.stderr.decode(errors='replace')[:300]}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--api", default=DEFAULT_API, help="base URL (default: $TTS_API)")
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
    if not args.api:
        sys.exit("no endpoint: set TTS_API or pass --api URL")
    args.fn(args)


if __name__ == "__main__":
    main()
