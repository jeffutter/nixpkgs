{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg-headless,
  yue2-song-skill,
}:

# Cover-song pipeline on the dgx-spark: SheetSage2 transcription, lyric drafts,
# plan/reharmonization checks and take timing. Rendering is delegated to the
# yue2-song skill's tool. Endpoints are --set-default so the environment can
# point them at another machine.
#
# SKILL.md refers to the helper as @cover@ and to the renderer as @yue2@, filled
# in with store paths, so the source names no agent's skill directory and the same
# build works for every consumer (Claude Code, Pi, Hermes).
runCommand "song-cover-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/song-cover} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@cover@' "$out/scripts/cover" \
    --replace-fail '@yue2@' "${yue2-song-skill}/scripts/yue2"
  makeWrapper ${python3}/bin/python3 $out/scripts/cover \
    --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
    --set-default AUDIOCPP_API http://192.168.10.14:8000/upstream/audiocpp \
    --set-default SHEETSAGE_MODEL audio-cpp/SheetSage2-GGUF \
    --set-default WORDS_MODEL parakeet-tdt-0.6b-v3 \
    --set-default STT_API http://192.168.10.4:8089 \
    --set-default STT_MODEL whisper-1 \
    --add-flags $out/scripts/cover.py
''
