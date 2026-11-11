{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
  openssh,
}:

# SoulX-FlashHead portrait video via audio.cpp on the GPU host. TALKING_HEAD_API and
# TALKING_HEAD_SSH come from the environment (jeff.endpoints, exported by
# home.sessionVariables in ai.nix); the tool exits if either is unset.
# openssh is needed because audio.cpp only reads server-local paths, so the
# script copies its inputs to the GPU host with scp.
#
# SKILL.md refers to the wrapper as @flashhead@, filled in with this
# derivation's own store path, so the source names no agent's skill directory.
runCommand "flashhead-video-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/flashhead-video} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@flashhead@' "$out/scripts/flashhead"
  makeWrapper ${python3}/bin/python3 $out/scripts/flashhead \
    --prefix PATH : ${
      lib.makeBinPath [
        ffmpeg-headless
        openssh
      ]
    } \
    --add-flags $out/scripts/flashhead.py
''
