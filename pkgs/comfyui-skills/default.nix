{
  lib,
  runCommand,
  makeWrapper,
  python3,
}:

# ComfyUI image generation on the dgx-spark (named comfyui-spark because Hermes
# ships its own built-in `comfyui` skill, which would shadow ours): one shared `comfy` CLI plus one skill
# per model (MOSS-Image, Z-Image, Krea-2, Klein), each carrying its workflow
# template. Built as a single derivation because every model skill calls the same
# script; each skill is a subdirectory of $out.
#
# The CLI is stdlib-only Python. COMFY_HOST is --set-default so `--host` or the
# environment can point it at another machine.
#
# The SKILL.md files refer to the tool and templates as @skills@/<skill>/..., filled
# in with this derivation's own store path, so the sources name no agent's skill
# directory and the same build works for every consumer (Claude Code, Pi, Hermes).
runCommand "comfyui-skills" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir $out
  for s in comfyui-spark comfy-moss-image comfy-z-image comfy-krea-2 comfy-flux2-klein; do
    cp -r ${../../modules/home/languages/ai/skills}/$s $out/$s
  done
  chmod -R u+w $out
  for s in $out/*/SKILL.md; do
    substituteInPlace $s --replace-fail '@skills@/' "$out/"
  done
  makeWrapper ${python3}/bin/python3 $out/comfyui-spark/scripts/comfy \
    --set-default COMFY_HOST http://192.168.10.14:8000/upstream/comfyui \
    --add-flags $out/comfyui-spark/scripts/comfy.py
''
