{
  runCommand,
  makeWrapper,
  python3,
}:

# Speech-to-text skill (Parakeet and friends behind llama-swap's
# /v1/audio/transcriptions). STT_API is --set-default so the environment or
# `--api` can point it at another machine.
#
# SKILL.md names the wrapper by its ~/.claude/skills path; that path only exists
# for Claude Code, so it is rewritten to this derivation's own store path.
runCommand "stt-transcribe-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/stt-transcribe} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '~/.claude/skills/stt-transcribe/scripts/stt' "$out/scripts/stt"
  makeWrapper ${python3}/bin/python3 $out/scripts/stt \
    --set-default STT_API https://llama.home.jeffutter.com/v1 \
    --add-flags $out/scripts/stt.py
''
