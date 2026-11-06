"""Transcribe each narration clip and diff it against the scene's `say` text: present stt-check [id ...]

Uses the stt-transcribe skill's tool (STT_TOOL, set by the present wrapper). Prints the similarity
per scene and the differing words for any scene under 0.97. Expect noise: spelled-out acronyms come
back joined ("c m s" -> "cms"), numbers come back as digits, and "eye dee" comes back as "id".
Flag real word changes and misreadings for Jeff's ear; do not re-voice on a mishearing alone.
"""

import difflib
import json
import os
import re
import subprocess
import sys

from svgkit import AUDIO_DIR, ROOT


def transcribe(path):
    return subprocess.run([os.environ["STT_TOOL"], "transcribe", str(path)], capture_output=True, text=True,
                          check=True).stdout.strip()


def words(s):
    return re.findall(r"[a-z0-9']+", s.lower().replace("-", " "))


only = set(sys.argv[1:])
for scene in json.loads((ROOT / "scenes.json").read_text())["scenes"]:
    if scene.get("audio") or (only and scene["id"] not in only):
        continue
    want = words(scene.get("say", scene["caption"]))
    got = words(transcribe(ROOT / AUDIO_DIR / f"{scene['id']}.opus"))
    sm = difflib.SequenceMatcher(a=want, b=got)
    print(f"{sm.ratio():.3f} {scene['id']}")
    if sm.ratio() < 0.97:
        for op, a1, a2, b1, b2 in sm.get_opcodes():
            if op != "equal":
                print(f"      {op}: script={' '.join(want[a1:a2])!r} heard={' '.join(got[b1:b2])!r}")
