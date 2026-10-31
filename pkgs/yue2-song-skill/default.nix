{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
}:

# YuE2 song generation via audio.cpp on the dgx-spark. --set-default keeps the
# endpoints overridable from the environment if a model moves.
#
# SKILL.md names the wrapper by its ~/.claude/skills path; that path only exists
# for Claude Code, so it is rewritten to this derivation's own store path. That
# works for every consumer (Claude Code, Hermes) without caring where the skill
# directory is mounted.
let
  python = python3.withPackages (ps: [ ps.numpy ]);
in
runCommand "yue2-song-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/yue2-song} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '~/.claude/skills/yue2-song/scripts/yue2' "$out/scripts/yue2"
  makeWrapper ${python}/bin/python3 $out/scripts/yue2 \
    --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
    --set-default YUE2_API http://192.168.10.14:8000 \
    --set-default YUE2_MODEL audio-cpp/Yue2-3B-GGUF \
    --set-default STT_API http://192.168.10.4:8089 \
    --set-default STT_MODEL whisper-large-v3-turbo \
    --add-flags $out/scripts/yue2.py
''
