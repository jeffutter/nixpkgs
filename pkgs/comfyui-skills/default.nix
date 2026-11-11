{
  lib,
  runCommand,
  makeWrapper,
  python3,
  curl,
}:

# ComfyUI image generation on the GPU host (named comfyui-remote because Hermes
# ships its own built-in `comfyui` skill, which would shadow ours): one shared `comfy` CLI plus one skill
# per model (MOSS-Image, Z-Image, Krea-2, Klein), each carrying its workflow
# template. Built as a single derivation because every model skill calls the same
# script; each skill is a subdirectory of $out.
#
# The CLI is stdlib-only Python. It reads IMAGE_API from the environment
# (jeff.endpoints.imageApi, exported by home.sessionVariables in ai.nix), adds
# llama-swap's /upstream/comfyui itself, and exits if it is unset; `--host`
# overrides it.
#
# The SKILL.md files refer to the tool and templates as @skills@/<skill>/..., filled
# in with this derivation's own store path, so the sources name no agent's skill
# directory and the same build works for every consumer (Claude Code, Pi, Hermes).
runCommand "comfyui-skills" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir $out
  for s in comfyui-remote comfy-moss-image comfy-z-image comfy-krea-2 comfy-flux2-klein; do
    cp -r ${../../modules/home/languages/ai/skills}/$s $out/$s
  done
  chmod -R u+w $out
  for s in $out/*/SKILL.md; do
    substituteInPlace $s --replace-fail '@skills@/' "$out/"
  done
  makeWrapper ${python3}/bin/python3 $out/comfyui-remote/scripts/comfy \
    --prefix PATH : ${lib.makeBinPath [ curl ]} \
    --add-flags $out/comfyui-remote/scripts/comfy.py
''
