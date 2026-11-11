{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
}:

# YuE2 song generation via audio.cpp on the GPU host. MUSIC_API and STT_API come from the
# environment (jeff.endpoints, exported by home.sessionVariables in ai.nix); the
# tool exits if either is unset. The model ids below are not endpoints and stay here.
#
# SKILL.md refers to the wrapper as @yue2@, filled in with this derivation's own
# store path, so the source names no agent's skill directory and the same build
# works for every consumer (Claude Code, Pi, Hermes).
let
  python = python3.withPackages (ps: [ ps.numpy ]);
in
runCommand "yue2-song-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/yue2-song} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@yue2@' "$out/scripts/yue2"
  makeWrapper ${python}/bin/python3 $out/scripts/yue2 \
    --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
    --set-default YUE2_MODEL audio-cpp/Yue2-3B-GGUF \
    --set-default STT_MODEL whisper-1 \
    --add-flags $out/scripts/yue2.py
''
