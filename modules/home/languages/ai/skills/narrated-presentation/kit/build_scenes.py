"""Generate scenes.json from script.md: present scenes

A scene is a `### <id>` block in script.md. The lines this reads:
  - Narration: <caption text>         narrated scene (one line, written for the ear)
  ... Audio: `music/<file>.wav`        music scene (jingle, bumper, outro); no narration
  - Voice: presenter|relaxed|dramatic optional; default DEFAULT_VOICE
  - Transition: <xfade name>          optional; default fade
Spellings for the TTS come from say.json: {"replace": [[from, to], ...], "regex": [[pattern, to], ...]},
applied in order to the caption to make the scene's "say" text.

A music scene gets lead 0 so its visual's t = 0 is the cut's first downbeat (the opener keeps the
default lead). The narrated scene before a music scene gets a pre-roll bed that fades the music in;
the narrated scene after it gets a bed that continues the music under its first words, with a longer
lead. `present music` writes those bed files.
"""

import json
import os
import re
from pathlib import Path

DEFAULT_VOICE = "presenter"
BED_LEAD = 1.2

root = Path(os.environ.get("PRESENT_ROOT", Path.cwd()))
text = (root / "script.md").read_text()
say_cfg = json.loads((root / "say.json").read_text()) if (root / "say.json").is_file() else {}
blocks = re.split(r"^### ", text, flags=re.M)[1:]

scenes, words = [], 0
for b in blocks:
    sid = b.splitlines()[0].strip().split(" ")[0]
    ext = "mp4" if (root / f"visuals/{sid}.mp4").exists() else "png"
    audio = re.search(r"Audio: `([^`]+)`", b)
    trans = re.search(r"^- Transition: (\w+)", b, flags=re.M)
    if audio:
        sc = {"id": sid, "audio": audio.group(1), "music": True, "visual": f"visuals/{sid}.{ext}"}
        if scenes:
            sc["lead"] = 0.0
            if not scenes[-1].get("music"):
                scenes[-1]["bed"] = f"music/bed-{scenes[-1]['id']}.wav"
    else:
        m = re.search(r"^- Narration: (.+)$", b, flags=re.M)
        if not m:
            continue  # a notes block, not a scene
        cap = m.group(1).strip()
        assert "—" not in cap and "–" not in cap, f"{sid}: no em or en dashes in narration"
        words += len(cap.split())
        voice = re.search(r"^- Voice: (\w+)", b, flags=re.M)
        sc = {"id": sid, "visual": f"visuals/{sid}.{ext}", "caption": cap,
              "voice": voice.group(1) if voice else DEFAULT_VOICE}
        say = cap
        for a, z in say_cfg.get("replace", []):
            say = say.replace(a, z)
        for a, z in say_cfg.get("regex", []):
            say = re.sub(a, z, say)
        if say != cap:
            sc["say"] = say
        if scenes and scenes[-1].get("music"):
            sc["bed"] = f"music/bed-{sid}.wav"
            sc["lead"] = BED_LEAD
    if scenes:
        sc["transition"] = trans.group(1) if trans else "fade"
    scenes.append(sc)

ids = [s["id"] for s in scenes]
assert len(ids) == len(set(ids)), "scene ids must be unique"
(root / "scenes.json").write_text(json.dumps({"scenes": scenes}, indent=2, ensure_ascii=False) + "\n")
print(len(scenes), "scenes", words, "words, about", round(words / 2.6 / 60, 1), "min of speech")
