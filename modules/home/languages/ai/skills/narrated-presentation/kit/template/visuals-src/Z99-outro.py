"""Closing card over the take's last phrase."""
from _bumper import *

LENGTH = 16.0  # the outro cut's length (to_end: take length minus its start)
render_anim(lambda t: outro(t, LENGTH), LENGTH, "visuals/Z99-outro.mp4", keep_svg_at=3 * BAR)
