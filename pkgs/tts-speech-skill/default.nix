{
  runCommand,
  makeWrapper,
  python3,
}:

# Text-to-speech skill (Kokoro, Breeze, Higgs behind llama-swap's
# /v1/audio/speech). TTS_API is --set-default so the environment or `--api`
# can point it at another machine.
#
# SKILL.md names the wrapper by its ~/.claude/skills path; that path only exists
# for Claude Code, so it is rewritten to this derivation's own store path.
runCommand "tts-speech-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/tts-speech} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '~/.claude/skills/tts-speech/scripts/tts' "$out/scripts/tts"
  makeWrapper ${python3}/bin/python3 $out/scripts/tts \
    --set-default TTS_API https://llama.home.jeffutter.com/v1 \
    --add-flags $out/scripts/tts.py
''
