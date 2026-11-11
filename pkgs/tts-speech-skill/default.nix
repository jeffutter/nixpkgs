{
  lib,
  endpoints,
  runCommand,
  makeWrapper,
  python3,
  curl,
}:

# Text-to-speech skill (Kokoro, Breeze, Higgs behind llama-swap's
# /v1/audio/speech). TTS_API is --set-default from jeff.endpoints.ttsApi, so
# the environment or `--api` can point it at another machine. The skill source
# holds no address.
#
# SKILL.md refers to the wrapper as @tts@, filled in with this derivation's own
# store path, so the source names no agent's skill directory and the same
# build works for every consumer (Claude Code, Pi, Hermes).
runCommand "tts-speech-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/tts-speech} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@tts@' "$out/scripts/tts" \
    --replace-fail '@ttsApi@' ${lib.escapeShellArg endpoints.ttsApi}
  makeWrapper ${python3}/bin/python3 $out/scripts/tts \
    --prefix PATH : ${lib.makeBinPath [ curl ]} \
    --set-default TTS_API ${lib.escapeShellArg endpoints.ttsApi} \
    --add-flags $out/scripts/tts.py
''
