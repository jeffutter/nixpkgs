{
  lib,
  runCommand,
  makeWrapper,
  fetchurl,
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
}:

# Narrated walkthrough video skill. One `video` CLI (scripts/video.py) with every
# renderer pinned on its PATH, so it needs no browser and no `nix shell` at run time.
# Pele (Mermaid -> SVG, MIT, no dependencies) has no CLI or nixpkgs package, so its
# npm tarball is vendored here. SKILL.md names the wrapper as @video@.
let
  pele = fetchurl {
    url = "https://registry.npmjs.org/pele/-/pele-1.13.0.tgz";
    hash = "sha256-APh52Gxabs6JfvcOGP0iiplSu6M4oMsSk7NzkA10FL0=";
  };
  python = python3.withPackages (ps: [ ps.pillow ]);
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
runCommand "narrated-video-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/narrated-video} $out
  chmod -R u+w $out
  mkdir -p $out/vendor/pele
  tar -xzf ${pele} -C $out/vendor/pele --strip-components=1
  substituteInPlace $out/SKILL.md --replace-fail '@video@' "$out/scripts/video"
  makeWrapper ${python}/bin/python3 $out/scripts/video \
    --prefix PATH : ${lib.makeBinPath tools} \
    --set-default TTS_API https://llama.home.jeffutter.com/v1 \
    --set PELE_JS $out/vendor/pele/dist/pele.js \
    --set VIDEO_FONT_DIRS ${inter}/share/fonts:${jetbrains-mono}/share/fonts \
    --set VIDEO_MONO_FONT ${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf \
    --add-flags "-I $out/scripts/video.py"
''
