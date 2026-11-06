"""Title card, part bumpers and the outro, all locked to the music's beat grid.

Edit TITLE, BPM, PARTS and READ_NEXT for the project. Music scenes after the opener start on a
downbeat with no lead, so their t = 0 is beat 1. The opener's grid is offset: set OPENER_SYNC to
when its first downbeat is heard (cut offset into the bar plus the 0.4 s lead), then nudge by eye
against the music until the title pulse sits on the beat. Everything beat-timed in a scene uses
the same grid; a piece pulsing on its own grid looks wrong even when the rest is right.
"""

from svgkit import *

TITLE, SUBTITLE = "Title", "Subtitle"
BPM = 120.0
BAR, BEAT, _ = beat_grid(BPM, 0.0)
OPENER_SYNC = 0.3
# (part title, accent colour); bumper(t, n) shows part n (1-based) and lights it in the strip.
PARTS = [("The big picture", C["purple"]), ("Part two", C["blue"]), ("Part three", C["cyan"])]
READ_NEXT = [("Guide", "docs/guide.md"), ("Reference", "docs/reference.md")]
DOTS = (C["purple"], C["blue"], C["cyan"], C["green"])


def dots(cx, y, t, start, opacity=1):
    """Four accent dots arriving half a beat apart, then pulsing on every beat."""
    out = []
    for i, col in enumerate(DOTS):
        q = prog(t, start + i * BEAT * 0.5, 0.25)
        if q > 0:
            r = 12 * beat_bump(t, start + 2 * BEAT, BEAT, 0.35) * q
            out.append(circle(cx - 75 + i * 50, y, round(r, 2), fill=col, opacity=opacity))
    return "".join(out)


def opener(t, length):
    """The title card over the jingle: grid draws out, title slams in on bar 1 and pulses on the
    beat, subtitle types on bar 2, a fade to bg over the last second. Add the topic's own pieces
    (a phone filling, a diagram building), each arriving on beats of the same grid."""
    g = OPENER_SYNC
    out = [grid_bg(0.6, p=prog(t, 0.0, 1.6))]
    p = prog(t, BAR, 0.25)
    if p > 0:
        s = lerp(1.6, 1.0, p) * beat_bump(t, BAR + g, BEAT, 0.025)
        out.append(f'<g transform="translate({W / 2},{H / 2 - 120}) scale({s:.4f})" opacity="{p:.3f}">'
                   + text(0, 40, TITLE, size=150, weight="bold", anchor="middle") + "</g>")
        out.append(rect(W / 2 - 300 * p, H / 2 - 50, 600 * p, 8, fill=C["blue"], r=4))
    n = int(clamp((t - 2 * BAR) / (BAR * 0.9)) * len(SUBTITLE))
    if n:
        out.append(text(W / 2, H / 2 + 30, SUBTITLE[:n], size=48, fill=C["muted"], anchor="middle"))
    out.append(dots(W / 2, H / 2 + 120, t, on_beat(3 * BAR + g, BEAT, 0)))
    f = prog(t, length - 1.2, 1.0)
    if f > 0:
        out.append(rect(0, 0, W, H, fill=C["bg"], r=0, opacity=f))
    return doc("".join(out))


def bumper(t, part, who=""):
    """Four bars: part number on beat 2, title types over bar 2, audience line and dots on bar 3,
    the parts strip on bar 3 beat 2 (this one lit, earlier ones ticked)."""
    title, color = PARTS[part - 1]
    out = [grid_bg()]
    q = prog(t, BEAT, 0.3)
    if q > 0:
        out.append(text(W / 2, lerp(300, 330, q), f"Part {part}", size=40, weight="bold", fill=C["muted"],
                        anchor="middle", opacity=q))
        out.append(rect(W / 2 - 140 * q, 362, 280 * q, 6, fill=color, r=3))
    n = int(clamp((t - BAR) / (BAR * 0.8)) * len(title))
    if n:
        s = beat_bump(t, 2 * BAR, BEAT, 0.02)
        out.append(f'<g transform="translate({W / 2},480) scale({s:.4f})">'
                   + text(0, 0, title[:n], size=96, weight="bold", anchor="middle") + "</g>")
    w = prog(t, 2 * BAR, 0.3)
    if w > 0 and who:
        out.append(text(W / 2, lerp(590, 570, w), who, size=34, fill=color, anchor="middle", opacity=w))
    out.append(dots(W / 2, 680, t, 2 * BAR))
    s0 = prog(t, 2 * BAR + BEAT, 0.4)
    if s0 > 0:
        step = min(200, (W - 200) / len(PARTS))
        x0 = W / 2 - len(PARTS) * step / 2
        for i, (_name, col) in enumerate(PARTS):
            lit, done = i == part - 1, i < part - 1
            x = x0 + i * step
            out.append(rect(x + 10, 790, step - 20, 64, fill=C["panel_alt"] if lit else C["panel"],
                            stroke=col if lit else C["grid"], sw=3 if lit else 2, r=32, opacity=s0))
            out.append(text(x + step / 2, 832, f"{i + 1}", size=26, weight="bold", anchor="middle",
                            fill=col if (lit or done) else C["muted"], opacity=s0))
    return doc("".join(out))


def outro(t, length, tagline="Thanks for watching."):
    """Closing card over the take's last phrase. Pieces arrive on bars 1-3, hold, then leave one per
    beat from bar 6 in reverse order, each drifting down as it fades; the title holds alone with its
    pulse easing off and fades to bg over the last FADE s. Make the scene 12-16 s: a short outro
    feels abrupt."""
    FADE, leave0 = 2.5, 6 * BAR

    def gone(order):
        q = prog(t, leave0 + order * BEAT, 0.6)
        return 1 - q, 20 * q

    out = [grid_bg()]
    p = prog(t, BEAT, 0.3)
    if p > 0:
        ease_off = 1 - prog(t, leave0 + 5 * BEAT, 2 * BAR)
        s = lerp(1.5, 1.0, p) * (1 + (beat_bump(t, BAR, BEAT, 0.02) - 1) * ease_off)
        out.append(f'<g transform="translate({W / 2},380) scale({s:.4f})" opacity="{p:.3f}">'
                   + text(0, 0, TITLE, size=96, weight="bold", anchor="middle") + "</g>")
        out.append(rect(W / 2 - 320 * p, 420, 640 * p, 8, fill=C["blue"], r=4))
    keep, dy = gone(2)
    g = prog(t, BAR, 0.3)
    if g > 0 and keep > 0:
        out.append(text(W / 2, lerp(530, 510, g) + dy, tagline, size=56, weight="bold", fill=C["green"],
                        anchor="middle", opacity=g * keep))
    keep, dy = gone(1)
    if keep > 0:
        out.append(f'<g transform="translate(0,{dy:.1f})">' + dots(W / 2, 600, t, BAR + 2 * BEAT, keep) + "</g>")
    keep, dy = gone(0)
    for i, (name, path) in enumerate(READ_NEXT):
        d = prog(t, 2 * BAR + i * BEAT, 0.3) * keep
        if d > 0:
            y = 700 + i * 64 + dy
            out.append(text(W / 2 - 20, y, name, size=30, weight="bold", anchor="end", opacity=d))
            out.append(text(W / 2 + 20, y, path, size=24, fill=C["muted"], mono=True, opacity=d))
    f = prog(t, length - FADE, FADE)
    if f > 0:
        out.append(rect(0, 0, W, H, fill=C["bg"], r=0, opacity=f))
    return doc("".join(out))
