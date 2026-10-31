#!/usr/bin/env python3
"""Submit ComfyUI API-format graphs to the dgx-spark and download the result.

  comfy [--host H] gen TEMPLATE --prompt "..." [--seed N] [--width W] [--height H] [--out F.png]
  comfy models                      list loader/LoRA files ComfyUI can see
  comfy upload IMAGE                upload an input image, print its ComfyUI name
  comfy info IMAGE.png              print the graph embedded in a ComfyUI PNG

TEMPLATE is one of:
  - a template JSON: {"params": {name: ["node.inputs.field", ...]},
                      "defaults": {name: value}, "graph": {API graph}}
  - a bare API-format graph JSON (no named params; steer it with --set)
  - a PNG made by ComfyUI (its embedded graph is reused; steer it with --set)

Host: --host HOST_OR_URL, else $COMFY_HOST, else the dgx-spark at
http://192.168.10.14:8000/upstream/comfyui. A bare host (or one on port 8000) is
reached through llama-swap, which starts the ComfyUI container (and evicts any
conflicting LLM) on demand; a cold start adds roughly 20-40 s. Any other
explicit port, e.g. 192.168.10.14:8014, is treated as ComfyUI itself.
"""
import argparse
import json
import mimetypes
import os
import random
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zlib

DEFAULT_HOST = "http://192.168.10.14:8000/upstream/comfyui"
BASE = DEFAULT_HOST
POLL_TIMEOUT = int(os.environ.get("COMFY_TIMEOUT", "900"))


def resolve_host(spec):
    """Turn --host / COMFY_HOST into the base URL of ComfyUI's API.

    A full URL with a path is used as given. A bare host (or URL without a path)
    on the default llama-swap port 8000, or with no port, gets llama-swap's
    /upstream/comfyui prefix, which also starts the container on demand. Any
    other explicit port is taken to be ComfyUI itself (e.g. host:8014, or :8188
    inside the container) and used as given.
    """
    if "://" not in spec:
        spec = "http://" + spec
    parts = urllib.parse.urlsplit(spec)
    if parts.path.strip("/"):
        return spec.rstrip("/")
    if parts.port in (None, 8000):
        host = parts.hostname + (":8000" if parts.port is None else f":{parts.port}")
        return f"{parts.scheme}://{host}/upstream/comfyui"
    return f"{parts.scheme}://{parts.netloc}"


def http(method, path, body=None, headers=None, retries=3):
    req_headers = dict(headers or {})
    data = body
    if isinstance(body, (dict, list)):
        data = json.dumps(body).encode()
        req_headers["Content-Type"] = "application/json"
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(BASE + path, data=data, headers=req_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            # 4xx is the caller's graph being wrong: report it, don't retry.
            if e.code < 500:
                sys.exit(f"HTTP {e.code} from ComfyUI:\n{format_error(detail)}")
            last = f"HTTP {e.code}: {detail[:300]}"
        except urllib.error.URLError as e:
            last = str(e)
        # The first request after a ComfyUI upgrade or a cold start can 500 once.
        time.sleep(5)
    sys.exit(f"ComfyUI unreachable at {BASE} after {retries} tries: {last}")


def format_error(text):
    try:
        d = json.loads(text)
    except ValueError:
        return text[:1500]
    lines = [d.get("error", {}).get("message", "") if isinstance(d.get("error"), dict) else str(d.get("error", ""))]
    for nid, ne in (d.get("node_errors") or {}).items():
        for err in ne.get("errors", []):
            lines.append(f"  node {nid} ({ne.get('class_type')}): {err.get('message')} - {err.get('details')}")
    return "\n".join(l for l in lines if l)


def png_graph(path):
    """Return the API-format graph ComfyUI embeds in its PNG 'prompt' text chunk."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{path} is not a PNG")
    pos = 8
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"tEXt" and chunk.startswith(b"prompt\x00"):
            return json.loads(chunk.split(b"\x00", 1)[1].decode("latin-1"))
        if ctype == b"iTXt" and chunk.startswith(b"prompt\x00"):
            rest = chunk.split(b"\x00", 1)[1]
            comp = rest[0]
            text = rest[2:].split(b"\x00", 2)[2]
            return json.loads((zlib.decompress(text) if comp else text).decode())
    sys.exit(f"{path} has no embedded ComfyUI graph")


def load_template(arg):
    if arg.lower().endswith(".png"):
        return {"params": {}, "defaults": {}, "graph": png_graph(arg)}
    with open(arg) as f:
        t = json.load(f)
    if "graph" in t:
        return t
    return {"params": {}, "defaults": {}, "graph": t}


def parse_value(text):
    """JSON if it parses (numbers, true, [\"15\",0]), else a plain string."""
    try:
        return json.loads(text)
    except ValueError:
        return text


def set_path(graph, path, value):
    node, *rest = path.split(".")
    if node not in graph:
        sys.exit(f"graph has no node {node!r} (from {path!r})")
    cur = graph[node]
    for key in rest[:-1]:
        cur = cur[key]
    cur[rest[-1]] = value


def cmd_gen(a):
    t = load_template(a.template)
    graph = json.loads(json.dumps(t["graph"]))
    seed = random.randrange(2**32) if a.seed in (None, "random") else int(a.seed)
    explicit = {"seed": seed if a.seed not in (None, "random") else None}
    for name in ("prompt", "negative", "width", "height", "steps", "cfg", "sampler", "scheduler", "batch"):
        explicit[name] = getattr(a, name)
    explicit = {k: v for k, v in explicit.items() if v is not None}

    available = t.get("params", {})
    if not available:
        # Bare graph or PNG: the only param we can find without a map is the seed.
        available = {"seed": [f"{nid}.inputs.{k}" for nid, n in graph.items()
                              for k in n.get("inputs", {}) if k in ("seed", "noise_seed")]}
    for item in a.param or []:
        name, _, raw = item.partition("=")
        explicit[name] = parse_value(raw)
    for name in explicit:
        if name not in available:
            sys.exit(f"template has no {name!r} param (has: {', '.join(available) or 'none'}); use --set")
    # Template defaults first, then explicit flags on top; the seed is always applied.
    values = {**t.get("defaults", {}), **explicit, "seed": seed}
    for name, value in values.items():
        for path in available.get(name, []):
            set_path(graph, path, value)
    for item in a.set or []:
        path, _, raw = item.partition("=")
        set_path(graph, path, parse_value(raw))

    if a.dry_run:
        print(json.dumps(graph, indent=2))
        return

    started = time.time()
    resp = json.loads(http("POST", "/prompt", {"prompt": graph, "client_id": str(uuid.uuid4())}))
    pid = resp["prompt_id"]
    while True:
        hist = json.loads(http("GET", f"/history/{pid}"))
        if pid in hist:
            break
        if time.time() - started > POLL_TIMEOUT:
            sys.exit(f"timed out after {POLL_TIMEOUT}s waiting for {pid}")
        time.sleep(2)
    entry = hist[pid]
    if entry["status"]["status_str"] != "success":
        msgs = [m[1].get("exception_message", "") for m in entry["status"]["messages"] if m[0] == "execution_error"]
        sys.exit("generation failed: " + (msgs[0] if msgs else json.dumps(entry["status"])[:500]))

    images = [i for out in entry["outputs"].values() for i in out.get("images", []) if i.get("type") == "output"]
    if not images:
        sys.exit("generation succeeded but produced no output images (no SaveImage node?)")
    stem = a.out or f"{os.path.splitext(os.path.basename(a.template))[0]}-{seed}.png"
    base, ext = os.path.splitext(stem)
    for n, img in enumerate(images, 1):
        q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
        dest = stem if len(images) == 1 else f"{base}-{n}{ext or '.png'}"
        with open(dest, "wb") as f:
            f.write(http("GET", "/view?" + q))
        print(dest)
    print(f"seed={seed} time={time.time() - started:.1f}s", file=sys.stderr)


def cmd_models(a):
    info = json.loads(http("GET", "/object_info"))
    loaders = [
        ("diffusion (UNETLoader)", "UNETLoader", "unet_name"),
        ("diffusion GGUF (UnetLoaderGGUF)", "UnetLoaderGGUF", "unet_name"),
        ("text encoders (CLIPLoader)", "CLIPLoader", "clip_name"),
        ("VAE (VAELoader)", "VAELoader", "vae_name"),
        ("LoRA (LoraLoaderModelOnly)", "LoraLoaderModelOnly", "lora_name"),
    ]
    for label, cls, field in loaders:
        try:
            files = info[cls]["input"]["required"][field][0]
        except KeyError:
            files = ["(node unavailable)"]
        print(f"{label}:")
        for f in files:
            print(f"  {f}")
    print("CLIPLoader types:", ", ".join(info["CLIPLoader"]["input"]["required"]["type"][0]))
    print("samplers:", ", ".join(info["KSampler"]["input"]["required"]["sampler_name"][0]))
    print("schedulers:", ", ".join(info["KSampler"]["input"]["required"]["scheduler"][0]))


def cmd_upload(a):
    boundary = uuid.uuid4().hex
    name = os.path.basename(a.image)
    with open(a.image, "rb") as f:
        payload = f.read()
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
        f"Content-Type: {ctype}\r\n\r\n"
    ).encode() + payload + f"\r\n--{boundary}--\r\n".encode()
    r = json.loads(http("POST", "/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}))
    print(r["name"])


def cmd_info(a):
    print(json.dumps(png_graph(a.image), indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--host", metavar="HOST_OR_URL",
                   help="ComfyUI/llama-swap host or URL (default: $COMFY_HOST, else the dgx-spark)")
    sub = p.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen", help="generate an image from a template")
    g.add_argument("template")
    g.add_argument("--prompt")
    g.add_argument("--negative")
    g.add_argument("--seed", help="integer, or 'random' (default)")
    g.add_argument("--width", type=int)
    g.add_argument("--height", type=int)
    g.add_argument("--steps", type=int)
    g.add_argument("--cfg", type=float)
    g.add_argument("--sampler")
    g.add_argument("--scheduler")
    g.add_argument("--batch", type=int)
    g.add_argument("--param", action="append", metavar="NAME=VALUE",
                   help="template-specific param not covered by a flag, e.g. image=foo.png, shift=5 (repeatable)")
    g.add_argument("--set", action="append", metavar="NODE.inputs.FIELD=VALUE",
                   help="override any node input; VALUE is JSON when it parses (repeatable)")
    g.add_argument("--out", help="output PNG path (batches get -1, -2 suffixes)")
    g.add_argument("--dry-run", action="store_true", help="print the final graph, submit nothing")
    g.set_defaults(fn=cmd_gen)
    sub.add_parser("models", help="list model files ComfyUI sees").set_defaults(fn=cmd_models)
    u = sub.add_parser("upload", help="upload an input image")
    u.add_argument("image")
    u.set_defaults(fn=cmd_upload)
    i = sub.add_parser("info", help="print the graph embedded in a PNG")
    i.add_argument("image")
    i.set_defaults(fn=cmd_info)
    a = p.parse_args()
    global BASE
    BASE = resolve_host(a.host or os.environ.get("COMFY_HOST") or DEFAULT_HOST)
    a.fn(a)


if __name__ == "__main__":
    main()
