"""A narrated scene: every beat keyed to a phrase of the caption, never to a hard-coded time."""
from svgkit import *

SID = "A01-example"
CUES, END = scene_cues(SID, {"code": "Here is the file", "line": "this line"})
LENGTH = END + 1.6
CODE = ['{', '  "id": "example",', '  "items": []', '}']


def frame(t):
    out = [heading("An example scene", "replace me")]
    panel, _ = code_panel(120, 260, 900, CODE, title="src/example.json",
                          highlight=(1,) if t >= CUES["line"] else ())
    out.append(rise(panel, t, CUES["code"]))
    if t >= CUES["line"]:
        out.append(fade(what_if(1060, 300), t, CUES["line"]))
    return doc("".join(out))


render_anim(frame, LENGTH, f"visuals/{SID}.mp4", keep_svg_at=LENGTH - 0.1)
