{
  lib,
  runCommand,
  makeWrapper,
  python3,
  nodejs,
  curl,
  ffmpeg-headless,
  gpac,
  d2,
  resvg,
  vega-lite,
  asciinema-agg,
  marp-cli,
  inter,
  jetbrains-mono,
  narrated-video-skill,
  stt-transcribe-skill,
}:

# Long-form narrated presentation skill. One `present` CLI (kit/present.py) runs the kit's tools
# with the same renderers and fonts as narrated-video, plus numpy for the prosody check. The video
# tool is the kit's own fork; it still reads pele.mjs and the Marp theme from narrated-video.
# SKILL.md names the wrapper as @present@.
let
  python = python3.withPackages (ps: [
    ps.pillow
    ps.numpy
  ]);
  tools = [
    nodejs
    curl
    ffmpeg-headless
    gpac
    d2
    resvg
    vega-lite
    asciinema-agg
    marp-cli
  ];
in
runCommand "narrated-presentation-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/narrated-presentation} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md --replace-fail '@present@' "$out/bin/present"
  makeWrapper ${python}/bin/python3 $out/bin/present \
    --prefix PATH : ${lib.makeBinPath tools} \
    --set-default TTS_API https://llama.home.jeffutter.com/v1 \
    --set NARRATED_VIDEO_DIR ${narrated-video-skill}/scripts \
    --set PELE_JS ${narrated-video-skill}/vendor/pele/dist/pele.js \
    --set STT_TOOL ${stt-transcribe-skill}/scripts/stt \
    --set VIDEO_FONT_DIRS ${inter}/share/fonts:${jetbrains-mono}/share/fonts \
    --set VIDEO_MONO_FONT ${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf \
    --add-flags "-I $out/kit/present.py"
''
