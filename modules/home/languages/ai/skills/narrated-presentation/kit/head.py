"""head: an optional talking head over an assembled presentation. Run from the project root.

  head timeline <video>                 scene and narration times of <video> -> talking-head/timeline.json
  head render [id ...] [--model M] [--size N] [--portrait P] [--seed N]
                                        FlashHead clip per narrated scene, plus idle; skips done clips
  head progress                         clips done, measured rate, ETA
  head place <video> [id ...]           a clear spot per narrated scene -> talking-head/placement.json
  head sheet <video> <out.png> <id ...> last frame of each scene with its head spot outlined
  head build <video> <out> [--from S --to E] [--stand-in CLIP]
                                        composite; audio and captions are copied untouched

<video> is the assembled MP4 without a head, whose work dir (out/<name>.work) `video assemble` left.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np

ROOT = Path(os.environ.get("PRESENT_ROOT", "."))
HEAD = ROOT / "talking-head"     # not "head/": the sandbox denies writes under any path named HEAD
CLIPS = HEAD / "clips"
FLASHHEAD = os.environ.get("FLASHHEAD", "flashhead")
W, H = 1920, 1080
LEAD, XFADE = 0.4, 0.8      # the video tool's default lead and its scene cross-fade
FADE = 0.2                  # alpha fade at each end of a speech clip over the idle loop
IDLE_S = 8                  # idle clip length; it plays forward and back
CROP = (320, 32, 16)        # square crop of a 384 FlashHead frame (size, x, y) that centres the face
SIZES = (216, 192, 168)     # head diameters to try, largest first (216 = 20% of the height)
INSET, PAD = 40, 20         # edge inset and clear margin around the head
SHADOW = 16                 # canvas margin around the disk for its drop shadow
RING = (0xE6, 0xE6, 0xF0)   # night theme text colour
S = 4                       # placement grid: 1 cell = 4x4 px


def sh(*args, **kw):
    return subprocess.run([str(a) for a in args], check=True, **kw)


def dur(p):
    return float(sh("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p,
                    capture_output=True, text=True).stdout)


def ff(*args):
    sh("ffmpeg", "-v", "error", "-y", *args)


def load(name):
    return json.loads((HEAD / name).read_text())


def speech_scenes():
    return [r for r in load("timeline.json")["scenes"] if not r["music"]]


# timeline -------------------------------------------------------------------------------------

def cmd_timeline(a):
    video = Path(a.video)
    work = video.parent / f"{video.stem}.work"
    scenes = json.loads((ROOT / "scenes.json").read_text())["scenes"]
    rows, start = [], 0.0
    for s in scenes:
        length = dur(work / f"{s['id']}.mov")
        rows.append({"id": s["id"], "start": round(start, 3), "length": round(length, 3),
                     "speech_at": round(start + s.get("lead", LEAD), 3),
                     "speech": round(dur(work / f"{s['id']}.clean.wav"), 3),
                     "clean": str(work / f"{s['id']}.clean.wav"), "music": bool(s.get("music"))})
        start += length - XFADE
    total = start + XFADE
    if abs(total - dur(video)) > 0.1:
        sys.exit(f"timeline {total:.2f}s does not match {video} ({dur(video):.2f}s): re-run `video assemble`")
    HEAD.mkdir(exist_ok=True)
    (HEAD / "timeline.json").write_text(json.dumps({"total": round(total, 3), "scenes": rows}, indent=1))
    sp = [r for r in rows if not r["music"]]
    print(f"{total:.1f}s video, {len(sp)} narrated scenes, {sum(r['speech'] for r in sp):.0f}s speech")


# render ---------------------------------------------------------------------------------------

def cmd_render(a):
    CLIPS.mkdir(parents=True, exist_ok=True)
    idle_wav = CLIPS / "idle.wav"
    if not idle_wav.exists():
        ff("-f", "lavfi", "-i", "anullsrc=r=16000:cl=mono", "-t", IDLE_S, idle_wav)
    jobs = [(r["id"], r["clean"]) for r in speech_scenes()] + [("idle", str(idle_wav))]
    if a.ids:
        jobs = [j for j in jobs if j[0] in a.ids]
    log = CLIPS / "times.log"
    for sid, src in jobs:
        out = CLIPS / f"{sid}.mp4"
        if out.exists() and out.stat().st_size:
            continue
        t = time.time()
        with open(CLIPS / f"{sid}.log", "w") as f:
            rc = subprocess.run([FLASHHEAD, a.portrait, src, str(out), "--model", a.model, "--size", str(a.size),
                                 "--seed", str(a.seed)], stdout=f, stderr=subprocess.STDOUT).returncode
        with open(log, "a") as f:
            f.write(f"{sid} exit {rc} wall {time.time() - t:.0f}s\n")
    with open(log, "a") as f:
        f.write("done\n")


def cmd_progress(a):
    want = {r["id"]: r["speech"] for r in speech_scenes()} | {"idle": float(IDLE_S)}
    text = (CLIPS / "times.log").read_text() if (CLIPS / "times.log").exists() else ""
    done = {m[1]: float(m[2]) for m in re.finditer(r"^(\S+) exit 0 wall (\d+)s", text, re.M) if m[1] in want}
    fails = sorted(set(re.findall(r"^(\S+) exit [1-9]", text, re.M)))
    have = {k for k in want if (CLIPS / f"{k}.mp4").exists()}
    rate = sum(done.values()) / sum(want[k] for k in done) if done else None
    left = sum(v for k, v in want.items() if k not in have)
    eta = f", {left * rate / 60:.0f} min left, ETA {datetime.now() + timedelta(seconds=left * rate):%H:%M}" if rate else ""
    print(f"{len(have)}/{len(want)} clips, {sum(want.values()) - left:.0f}/{sum(want.values()):.0f}s"
          + (f", rate {rate:.1f}x" if rate else "") + eta + f", failures {fails or 'none'}")


# place ----------------------------------------------------------------------------------------

def content_mask(video, a, b):
    """Every pixel that is not background in any frame of [a, b], on the 4 px grid."""
    # Full resolution then max-pool: averaging down hides 1-2 px lines such as dashed lifelines.
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{a}", "-t", f"{b - a}", "-i", str(video),
                             "-vf", "fps=4", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    union, size = np.zeros((H // S, W // S), bool), W * H * 3
    while (buf := proc.stdout.read(size)) and len(buf) == size:
        f = np.frombuffer(buf, np.uint8).reshape(H, W, 3).astype(np.int16)
        # Background from each frame's border: a terminal backdrop differs from a slide's.
        border = np.concatenate([f[:8].reshape(-1, 3), f[-8:].reshape(-1, 3), f[:, :8].reshape(-1, 3),
                                 f[:, -8:].reshape(-1, 3)])
        ink = np.abs(f - np.median(border, axis=0)).max(axis=2) > 22
        union |= ink.reshape(H // S, S, W // S, S).any(axis=(1, 3))
    proc.wait()
    return union


def candidates(d):
    """Top-left positions hugging the frame edges: the four corners, then edge spots nearest bottom right."""
    lo_x, hi_x, lo_y, hi_y = INSET, W - INSET - d, INSET, H - INSET - d
    edge = []
    for x in range(lo_x, hi_x + 1, 8):
        edge += [(abs(hi_x - x), (x, hi_y)), (abs(hi_x - x) + 400, (x, lo_y))]
    for y in range(lo_y, hi_y + 1, 8):
        edge += [(abs(hi_y - y) + 100, (hi_x, y)), (abs(hi_y - y) + 600, (lo_x, y))]
    return [(hi_x, hi_y), (lo_x, hi_y), (hi_x, lo_y), (lo_x, lo_y)] + [p for _, p in sorted(edge)]


def fits(mask, x, y, d):
    r, cx, cy = d / 2 + PAD, x + d / 2, y + d / 2
    yy, xx = np.mgrid[0:H // S, 0:W // S]
    return not (mask & ((xx * S + S / 2 - cx) ** 2 + (yy * S + S / 2 - cy) ** 2 <= r * r)).any()


def cmd_place(a):
    path = HEAD / "placement.json"
    place = json.loads(path.read_text()) if path.exists() else {}
    for r in speech_scenes():
        if a.ids and r["id"] not in a.ids:
            continue
        mask = content_mask(a.video, r["start"] + XFADE, r["start"] + r["length"] - XFADE)
        pick = None
        for d in SIZES:
            pick = next(({"x": x, "y": y, "d": d} for x, y in candidates(d) if fits(mask, x, y, d)), None)
            if pick:
                break
        place[r["id"]] = pick
        print(r["id"], pick or "no clear spot: head hidden")
    path.write_text(json.dumps(place, indent=1))


def cmd_sheet(a):
    tl = {r["id"]: r for r in load("timeline.json")["scenes"]}
    place = load("placement.json")
    tiles = []
    for i, sid in enumerate(a.ids):
        r, p = tl[sid], place.get(sid)
        vf = "scale=640:360"
        if p:
            cx, cy, rad = p["x"] + p["d"] / 2, p["y"] + p["d"] / 2, p["d"] / 2
            on = f"between(hypot(X-{cx},Y-{cy}),{rad - 5},{rad})"
            vf = f"format=rgb24,geq=r='if({on},255,r(X,Y))':g='if({on},40,g(X,Y))':b='if({on},40,b(X,Y))',{vf}"
        tile = HEAD / f"tile{i}.png"
        ff("-ss", f"{r['start'] + r['length'] - 1.0:.2f}", "-i", a.video, "-frames:v", "1", "-vf", vf, tile)
        tiles.append(tile)
    n = max(len(tiles), 2)
    args = sum((["-i", t] for t in tiles), [])
    if len(tiles) == 1:
        args += ["-f", "lavfi", "-i", "color=black:s=640x360:d=1"]
    layout = "|".join(f"{(k % 3) * 640}_{(k // 3) * 360}" for k in range(n))
    ff(*args, "-filter_complex", f"xstack=inputs={n}:layout={layout}:fill=black", "-frames:v", "1", a.out)
    print(a.out)


# build ----------------------------------------------------------------------------------------

def deco(d):
    """Shadow under the disk, ring over it, and the disk's alpha mask, as PNGs for diameter d."""
    c, s, r = (d + 2 * SHADOW) / 2, d + 2 * SHADOW, d / 2
    dist = f"hypot(X-{c}+0.5,Y-{c}+0.5)"
    under, over, mask = HEAD / f"under{d}.png", HEAD / f"over{d}.png", HEAD / f"mask{d}.png"
    ff("-f", "lavfi", "-i", f"color=black:s={s}x{s}:d=1,format=rgba",
       "-vf", f"geq=r=0:g=0:b=0:a='110*clip(({r}+6-{dist})/14,0,1)',gblur=sigma=5", "-frames:v", "1", under)
    ff("-f", "lavfi", "-i", f"color=black:s={s}x{s}:d=1,format=rgba",
       "-vf", f"geq=r={RING[0]}:g={RING[1]}:b={RING[2]}:a='120*clip(1.6-abs({dist}-{r - 1}),0,1)'",
       "-frames:v", "1", over)
    ff("-f", "lavfi", "-i", f"color=black:s={d}x{d}:d=1,format=gray",
       "-vf", f"geq=lum='clip(({r}-hypot(X-{r}+0.5,Y-{r}+0.5))*127+128,0,255)'", "-frames:v", "1", mask)
    return under, over, mask


def head_track(total, speech, idle, out):
    """The idle clip looped forward and back for the whole video, each speech clip laid over it at its start."""
    n = round(dur(idle) * 25) * 2
    inputs, last = ["-i", idle], "idle"
    chains = [f"[0:v]fps=25,split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1:a=0,"
              f"loop=loop=-1:size={n}:start=0,trim=duration={total},setpts=PTS-STARTPTS[idle]"]
    for i, (at, clip, length) in enumerate(speech, 1):
        inputs += ["-i", clip]
        chains.append(f"[{i}:v]fps=25,trim=duration={length},format=yuva420p,"
                      f"fade=t=in:st=0:d={FADE}:alpha=1,fade=t=out:st={length - FADE:.3f}:d={FADE}:alpha=1,"
                      f"setpts=PTS-STARTPTS+{at:.3f}/TB[c{i}]")
        chains.append(f"[{last}][c{i}]overlay=eof_action=pass[v{i}]")
        last = f"v{i}"
    script = HEAD / "head-track.filter"
    script.write_text(";\n".join(chains) + f";\n[{last}]format=yuv420p[v]")
    ff(*inputs, "-/filter_complex", script, "-map", "[v]", "-an", "-c:v", "libx264", "-crf", "16",
       "-preset", "fast", "-t", f"{total}", out)


def segments(tl, place):
    """Runs of consecutive scenes that share a head spot: (t0, t1, spot). Music scenes break a run."""
    segs = []
    for r in tl["scenes"]:
        p = None if r["music"] else place.get(r["id"])
        t0, t1 = r["start"], r["start"] + r["length"]
        if p and segs and segs[-1][2] == p and abs(segs[-1][1] - t0 - XFADE) < 0.01:
            segs[-1] = (segs[-1][0], t1, p)
        elif p:
            segs.append((t0, t1, p))
    return segs


def cmd_build(a):
    tl, place = load("timeline.json"), load("placement.json")
    speech = []
    for r in speech_scenes():
        clip = Path(a.stand_in) if a.stand_in else CLIPS / f"{r['id']}.mp4"
        if not clip.exists():
            sys.exit(f"{clip} missing: run `head render` first")
        speech.append((r["speech_at"], clip, min(r["speech"], dur(clip))))
    idle = Path(a.stand_in) if a.stand_in else CLIPS / "idle.mp4"
    track = HEAD / ("head-track-standin.mp4" if a.stand_in else "head-track.mp4")
    if not track.exists() or any(c.stat().st_mtime > track.stat().st_mtime for _, c, _ in speech):
        head_track(tl["total"], speech, idle, track)

    fps = sh("ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=r_frame_rate",
             "-of", "csv=p=0", a.video, capture_output=True, text=True).stdout.strip()
    segs = segments(tl, place)
    sizes = sorted({p["d"] for _, _, p in segs})
    inputs, idx, chains = ["-i", a.video, "-i", track], {}, []
    for d in sizes:
        idx[d] = (2 + 3 * len(idx), 3 + 3 * len(idx), 4 + 3 * len(idx))
        for png in deco(d):
            inputs += ["-loop", "1", "-i", png]
    cs, cx, cy = CROP
    chains.append(f"[1:v]fps={fps},crop={cs}:{cs}:{cx}:{cy},split={len(sizes)}" + "".join(f"[h{d}]" for d in sizes))
    for d in sizes:
        u, o, m = idx[d]
        n = sum(1 for s in segs if s[2]["d"] == d)
        chains.append(f"[h{d}]scale={d}:{d}:flags=lanczos,format=yuva420p[hs{d}];"
                      f"[{m}:v]format=gray,fps={fps}[m{d}];[hs{d}][m{d}]alphamerge[hm{d}];"
                      f"[{u}:v]fps={fps},format=yuva420p[u{d}];[u{d}][hm{d}]overlay={SHADOW}:{SHADOW}:shortest=1[hu{d}];"
                      f"[{o}:v]fps={fps},format=yuva420p[ring{d}];[hu{d}][ring{d}]overlay=0:0:shortest=1,split={n}"
                      + "".join(f"[disk{d}_{k}]" for k in range(n)))
    last, used = "0:v", {d: 0 for d in sizes}
    for i, (t0, t1, p) in enumerate(segs):
        d, k = p["d"], used[p["d"]]
        used[d] += 1
        # No trim: a branch that ends early stops reading the shared split and deadlocks the graph.
        chains.append(f"[disk{d}_{k}]fade=t=in:st={t0:.3f}:d={XFADE}:alpha=1,"
                      f"fade=t=out:st={t1 - XFADE:.3f}:d={XFADE}:alpha=1[s{i}]")
        chains.append(f"[{last}][s{i}]overlay={p['x'] - SHADOW}:{p['y'] - SHADOW}:eof_action=pass:"
                      f"enable='between(t,{t0:.3f},{t1:.3f})'[o{i}]")
        last = f"o{i}"
    script = HEAD / "composite.filter"
    script.write_text(";\n".join(chains) + f";\n[{last}]format=yuv420p[v]")
    window = ["-ss", f"{a.t0}", "-to", f"{a.to}"] if a.t0 is not None else []
    ff(*inputs, "-/filter_complex", script, "-map", "[v]", "-map", "0:a", "-map", "0:s?",
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
       "-c:a", "copy", "-c:s", "copy", "-map_metadata", "0", "-movflags", "+faststart", *window, a.out)
    # ffmpeg's MP4 muxer always enables one subtitle track; disable it so captions start off.
    sh("MP4Box", "-disable", "3", a.out, capture_output=True)
    same = all(sh("ffmpeg", "-v", "error", "-i", v, "-map", m, "-c", "copy", "-f", "md5", "-",
                  capture_output=True).stdout == sh("ffmpeg", "-v", "error", "-i", a.out, "-map", m, "-c", "copy",
                                                    "-f", "md5", "-", capture_output=True).stdout
               for v, m in ((a.video, "0:a"), (a.video, "0:s?"))) if not window else None
    hidden = [r["id"] for r in speech_scenes() if not place.get(r["id"])]
    print(f"{a.out}: {len(segs)} head segments, sizes {sizes}, hidden in {hidden or 'none'}"
          + ("" if same is None else f", audio and captions identical to the input: {'PASS' if same else 'FAIL'}"))


def main():
    ap = argparse.ArgumentParser(prog="head", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("timeline"); p.add_argument("video"); p.set_defaults(fn=cmd_timeline)
    p = sub.add_parser("render"); p.add_argument("ids", nargs="*")
    p.add_argument("--model", default="pro"); p.add_argument("--size", type=int, default=384)
    p.add_argument("--portrait", default="preset:jeff-desk"); p.add_argument("--seed", type=int, default=42)
    p.set_defaults(fn=cmd_render)
    p = sub.add_parser("progress"); p.set_defaults(fn=cmd_progress)
    p = sub.add_parser("place"); p.add_argument("video"); p.add_argument("ids", nargs="*"); p.set_defaults(fn=cmd_place)
    p = sub.add_parser("sheet"); p.add_argument("video"); p.add_argument("out"); p.add_argument("ids", nargs="+")
    p.set_defaults(fn=cmd_sheet)
    p = sub.add_parser("build"); p.add_argument("video"); p.add_argument("out"); p.add_argument("--stand-in")
    p.add_argument("--from", dest="t0", type=float); p.add_argument("--to", type=float); p.set_defaults(fn=cmd_build)
    a = ap.parse_args()
    a.fn(a)


main()
