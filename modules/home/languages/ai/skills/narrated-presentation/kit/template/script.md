# <Title> (script and storyboard)

## Story overview

<One paragraph: who watches, what they can do afterwards, and the running examples. Then the parts as a numbered ladder from general to specific, each with its audience and the point where an audience can stop.>

## Production reference (read once, applies to every scene)

Canvas 1920x1080, 30 fps, the night palette in `svgkit.C`. Fonts: Inter (prose), JetBrains Mono (code, ids).

Colour code, used everywhere: <one colour per core concept, for example level 1 purple, level 2 blue, level 3 cyan, level 4 green>. Hidden or omitted: muted grey, dashed outline. Errors and "forbidden": pink. Data from outside the system being explained: amber.

Code frames: at most 14 lines, real line numbers, the discussed lines on a band. A muted source label under each frame.

Hypothetical or invented elements carry an amber `what_if` tag ("what if", "invented", "hypothetical") on first appearance.

Motion: ease-out cubic. Slide-in = 40 px rise plus fade over 0.5 s. Keyframes are named by the phrase they follow, in brackets, quoting its first words.

Never on screen: <secrets, real tokens or encoded ids, internal names the user excluded>.

---

## Part A: <title>

### A00-title

- Target: 20 s. Medium: music-anim. Audio: `music/jingle.wav`. No narration.
- Visual: title card over the jingle, everything on the beat grid.

### A01-example

- Target: 20 s. Medium: svg-anim.
- Visual: <what is on screen, with each change keyed to a phrase>.
  - ["Here is the file"]: code card rises in.
  - ["this line"]: band on line 2; a "what if" tag beside it.
- Source: `<path>:<lines>` for every claim the scene makes.
- Voice: presenter
- Narration: Here is the file, and this line is the one that matters.

---

## Part B: <title>

### B00-bumper

- Target: 8 s. Medium: music-anim. Audio: `music/bumper-B.wav`. No narration.
- Transition: wipeleft
- Visual: part card, four bars.

---

### Z99-outro

- Target: 16 s. Medium: music-anim. Audio: `music/outro.wav`. No narration.
- Transition: fadeblack
- Visual: closing card; pieces leave one per beat; title fades last.
