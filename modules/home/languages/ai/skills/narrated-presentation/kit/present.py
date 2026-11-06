"""present: the narrated-presentation toolkit. Run it from the project root.

  present init <dir>             copy the project template into <dir> (refuses to overwrite)
  present scenes                 script.md (+ say.json) -> scenes.json
  present video <args>           the video tool: voice, cues, assemble, check, frame, slides, diagram, terminal
  present run <file.py> [args]   run a scene script or helper with this kit and visuals-src/ importable
  present render-all [prefix]    re-render every scene script (after any re-voice)
  present music                  cut music scenes and beds from music.json
  present music-scan <take> [bpm]   bar grid and level per bar, to pick cuts
  present stt-check [id ...]     transcribe narration and diff it against the script
  present audio-stats [file ...] loudness and band balance per clip
  present ab-speech <id>         raw versus processed narration for one scene
  present prosody <file ...>     rough pitch and loudness spread per clip
"""

import os
import runpy
import shutil
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent
TOOLS = {"scenes": "build_scenes.py", "render-all": "render_all.py", "music": "cut_music.py",
         "music-scan": "music_scan.py", "stt-check": "stt_check.py", "audio-stats": "audio_stats.py",
         "ab-speech": "ab_speech.py", "prosody": "prosody.py", "video": "video.py"}


def run_file(path, args):
    root = Path.cwd()
    os.environ["PRESENT_ROOT"] = str(root)
    sys.path[:0] = [str(KIT), str(root / "visuals-src")]
    sys.argv = [str(path), *args]
    runpy.run_path(str(path), run_name="__main__")


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        sys.exit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "init":
        if not args:
            sys.exit("usage: present init <dir>")
        dst = Path(args[0])
        if (dst / "script.md").exists():
            sys.exit(f"{dst}/script.md exists; init only starts new projects")
        shutil.copytree(KIT / "template", dst, dirs_exist_ok=True)
        for p in [dst, *dst.rglob("*")]:
            p.chmod(0o755 if p.is_dir() else 0o644)
        print(f"started {dst}: edit script.md, say.json and music.json, then `present scenes`")
        return
    if cmd == "run":
        if not args:
            sys.exit("usage: present run <file.py> [args]")
        return run_file(Path(args[0]).resolve(), args[1:])
    if cmd not in TOOLS:
        sys.exit(f"unknown command {cmd!r}\n{__doc__}")
    run_file(KIT / TOOLS[cmd], args)


main()
