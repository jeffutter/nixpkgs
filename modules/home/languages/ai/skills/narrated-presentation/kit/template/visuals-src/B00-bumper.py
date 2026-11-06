"""Part 2 bumper: four bars of the take."""
from _bumper import *

LENGTH = 4 * BAR
render_anim(lambda t: bumper(t, 2, "for <audience>"), LENGTH, "visuals/B00-bumper.mp4", keep_svg_at=3 * BAR)
