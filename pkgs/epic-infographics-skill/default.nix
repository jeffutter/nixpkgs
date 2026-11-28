# OrRon/EpicInfographics. Upstream sets itself up with `npm install` plus
# `playwright install chromium` inside the skill directory, which is read-only
# here. Instead, link nixpkgs' Playwright and its version-matched Chromium, and
# wrap each script so the agent calls it by path from any working directory.
{
  src,
  runCommand,
  makeWrapper,
  nodejs,
  playwright-test,
  playwright-driver,
  ffmpeg,
}:

runCommand "epic-infographics-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${src}/skills/epic-infographics $out
  chmod -R u+w $out
  rm $out/package-lock.json
  # The scripts are ES modules, which resolve imports from an ancestor
  # node_modules and ignore NODE_PATH.
  ln -s ${playwright-test}/lib/node_modules $out/node_modules

  for name in check render animate; do
    makeWrapper ${nodejs}/bin/node $out/scripts/$name \
      --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
      --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS 1 \
      --set-default FFMPEG ${ffmpeg}/bin/ffmpeg \
      --add-flags $out/scripts/$name.mjs
  done

  dir='~/.claude/skills/epic-infographics'
  substituteInPlace $out/SKILL.md \
    --replace-fail 'node scripts/check.mjs' "$dir/scripts/check" \
    --replace-fail 'node scripts/render.mjs' "$dir/scripts/render" \
    --replace-fail 'node scripts/animate.mjs' "$dir/scripts/animate" \
    --replace-fail \
      'First-time setup (once per machine): `npm install && npx playwright install chromium`
  (run from the skill directory). The script waits for fonts, so text always renders.' \
      'No setup: Nix provides Node, Playwright, Chromium and ffmpeg. The script waits
  for fonts, so text always renders.' \
    --replace-fail \
      'Requires ffmpeg on PATH (`brew install ffmpeg` / `apt install ffmpeg`).
  The preflight' \
      'The preflight'
  substituteInPlace $out/references/motion.md \
    --replace-fail 'node scripts/animate.mjs' "$dir/scripts/animate"
''
