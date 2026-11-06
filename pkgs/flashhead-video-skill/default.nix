{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
  openssh,
}:

# SoulX-FlashHead portrait video via audio.cpp on the dgx-spark. --set-default
# keeps the endpoints overridable from the environment if the host moves.
# openssh is needed because audio.cpp only reads server-local paths, so the
# script copies its inputs to the spark with scp.
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
    --set-default FLASHHEAD_API http://192.168.10.14:8000 \
    --set-default FLASHHEAD_SSH jeffutter@192.168.10.14 \
    --add-flags $out/scripts/flashhead.py
''
