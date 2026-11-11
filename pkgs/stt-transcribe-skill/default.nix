{
  runCommand,
  makeWrapper,
  python3,
}:

# Speech-to-text skill (Parakeet and friends behind llama-swap's
# /v1/audio/transcriptions). The tool reads STT_API from the environment
# (jeff.endpoints.sttApi, exported by home.sessionVariables in ai.nix) and exits
# if it is unset; `--api` overrides it.
#
# SKILL.md refers to the wrapper as @stt@, filled in with this derivation's own
# store path, so the source names no agent's skill directory and the same
# build works for every consumer (Claude Code, Pi, Hermes).
runCommand "stt-transcribe-skill" { nativeBuildInputs = [ makeWrapper ]; } ''
  cp -r ${../../modules/home/languages/ai/skills/stt-transcribe} $out
  chmod -R u+w $out
  substituteInPlace $out/SKILL.md \
    --replace-fail '@stt@' "$out/scripts/stt"
  makeWrapper ${python3}/bin/python3 $out/scripts/stt \
    --add-flags $out/scripts/stt.py
''
