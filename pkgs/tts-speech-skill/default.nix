{
  lib,
  runCommand,
  makeWrapper,
  python3,
  curl,
}:

# Text-to-speech skill (Kokoro, Breeze, Higgs behind llama-swap's
# /v1/audio/speech). The tool reads TTS_API from the environment
# (jeff.endpoints.ttsApi, exported by home.sessionVariables in ai.nix) and exits
# if it is unset; `--api` overrides it.
#
# SKILL.md refers to the wrapper as @tts@, filled in with this derivation's own
# store path, so the source names no agent's skill directory and the same
# build works for every consumer (Claude Code, Pi, Hermes).
runCommand "tts-speech-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/tts-speech} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@tts@' "$out/scripts/tts"
  makeWrapper ${python3}/bin/python3 $out/scripts/tts \
    --prefix PATH : ${lib.makeBinPath [ curl ]} \
    --add-flags $out/scripts/tts.py
''
