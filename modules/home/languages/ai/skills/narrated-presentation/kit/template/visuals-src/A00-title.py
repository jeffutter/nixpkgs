"""Opening title card over the walk-on jingle."""
from _bumper import *

LENGTH = 20.0  # match the jingle cut's length in music.json
render_anim(lambda t: opener(t, LENGTH), LENGTH, "visuals/A00-title.mp4", keep_svg_at=3 * BAR)
