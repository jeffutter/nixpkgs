"""Re-render every scene visual in scenes.json order: present render-all [id-prefix ...]

Run it after any re-voice: scene_cues re-times each scene from its new clip.
"""

import json
import subprocess
import sys

from svgkit import KIT, ROOT

prefixes = sys.argv[1:]
failed = []
for scene in json.loads((ROOT / "scenes.json").read_text())["scenes"]:
    sid = scene["id"]
    script = ROOT / "visuals-src" / f"{sid}.py"
    if not script.is_file() or (prefixes and not sid.startswith(tuple(prefixes))):
        continue
    proc = subprocess.run([sys.executable, "-I", str(KIT / "present.py"), "run", str(script)],
                          capture_output=True, text=True, cwd=ROOT)
    print(f"{'ok  ' if proc.returncode == 0 else 'FAIL'} {sid}", flush=True)
    if proc.returncode:
        failed.append(sid)
        print(proc.stderr[-1500:])
sys.exit(1 if failed else 0)
