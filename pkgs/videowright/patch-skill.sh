# Rewrite the upstream skill for the Nix install. Every substitution must match,
# so an upstream rewording fails the build.
set -euo pipefail
cd "$1"

replace() {
  local file=$1
  shift
  substituteInPlace "$file" "$@"
}

# Voiceover, transcription and music use the local models instead of paid APIs.
# ElevenLabs remains only for sound effects.
patch --fuzz=0 -p1 <"$voicePatch"
cp "$voiceTake" scripts/local-take.mjs
replace scripts/local-take.mjs --replace-fail '@tts@' "$tts" --replace-fail '@stt@' "$stt"
replace references/audio/voiceover/providers/manual.md --replace-fail '@stt@' "$stt"
replace references/audio/music/providers/local.md --replace-fail '@yue2@' "$yue2"
if grep -rnE 'openrouter|OpenRouter|OPENROUTER|Gemini|gemini\.md' references ||
  grep -rni elevenlabs references/audio/music; then
  echo "the skill still sends voice or music work to a paid service; update skill-local-audio.patch" >&2
  exit 1
fi

# The npm installer: package installs, browser downloads, per-project symlinks.
rm -r install

# Replace the lines from the heading $2 up to the next heading of that level.
section() {
  local file=$1 heading=$2 body=$3
  grep -qxF "$heading" "$file"
  HEADING=$heading BODY=$body awk '
    BEGIN { level = index(ENVIRON["HEADING"], " ") }
    $0 == ENVIRON["HEADING"] { print; print ""; print ENVIRON["BODY"]; print ""; skip = 1; next }
    skip && /^#+ / && index($0, " ") <= level { skip = 0 }
    !skip
  ' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

section references/setup.md '## Preconditions: Verify install' \
  'Videowright is installed by Nix. Never install it, or its tools, with `npm`, `pnpm` or `npx`. In the folder that will hold the video project, run:

```bash
videowright init
```

It is safe to rerun. It links the packaged modules into `node_modules/` and writes `package.json`, `tsconfig.json` and `env.d.ts` if they are missing. The folder must not belong to another project; if it does, ask the user for a sub-folder such as `videos/`.

Rerun it whenever `node_modules/videowright` is missing, for example on a fresh clone or after `npm install <library>`.'

replace references/setup.md \
  --replace-fail '| `videowright` not in `package.json` | Stop with install instructions. Do not proceed. |' \
  '| `node_modules/videowright` missing | Run `videowright init`. |'

section references/export.md '### ffmpeg' \
  '`render` uses the ffmpeg that Nix provides. There is nothing to install.'
section references/export.md '### Playwright / Chromium' \
  '`render` uses the Playwright and Chromium that Nix provides. Never run `playwright install`.'
replace references/export.md \
  --replace-fail '| ffmpeg not found | Install ffmpeg and ensure it is on your PATH. |
| Chromium not installed | Run `npx playwright install chromium`. |
' ''

find . \( -name '*.md' -o -path './assets/install/package.json' \) -exec sed -i -E \
  -e 's/npx videowright/videowright/g' \
  -e 's#npx (tsc|vitest|playwright)#node_modules/.bin/\1#g' {} +

# The sample slides show an unrelated `npx apogee` command as on-screen text.
if grep -rnE 'npx (videowright|tsc|vitest|playwright)|(npm|pnpm) install videowright' .; then
  echo "the skill still installs or downloads tools; update patch-skill.sh" >&2
  exit 1
fi
