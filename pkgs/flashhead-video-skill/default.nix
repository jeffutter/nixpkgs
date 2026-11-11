{
  lib,
  endpoints,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
  openssh,
}:

# SoulX-FlashHead portrait video via audio.cpp on the media host. --set-default
# keeps the endpoints (jeff.endpoints.talkingHeadApi and .talkingHeadSsh) overridable from the
# environment if the host moves.
# openssh is needed because audio.cpp only reads server-local paths, so the
# script copies its inputs to the spark with scp.
#
# SKILL.md refers to the wrapper as @flashhead@, filled in with this
# derivation's own store path, so the source names no agent's skill directory.
runCommand "flashhead-video-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/flashhead-video} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@flashhead@' "$out/scripts/flashhead" \
    --replace-fail '@talkingHeadApi@' ${lib.escapeShellArg endpoints.talkingHeadApi} \
    --replace-fail '@talkingHeadSsh@' ${lib.escapeShellArg endpoints.talkingHeadSsh}
  makeWrapper ${python3}/bin/python3 $out/scripts/flashhead \
    --prefix PATH : ${
      lib.makeBinPath [
        ffmpeg-headless
        openssh
      ]
    } \
    --set-default TALKING_HEAD_API ${lib.escapeShellArg endpoints.talkingHeadApi} \
    --set-default TALKING_HEAD_SSH ${lib.escapeShellArg endpoints.talkingHeadSsh} \
    --add-flags $out/scripts/flashhead.py
''
