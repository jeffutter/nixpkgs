---
name: comfyui
description: Shared instructions for generating or editing images with the dgx-spark ComfyUI through the `comfy` CLI. Load this with any model skill (comfy-moss-image, comfy-z-image, comfy-krea-2, comfy-flux2-klein), or alone when the user wants a custom ComfyUI graph, a LoRA, img2img, or a model comparison.
---

Use this skill whenever an image is generated on the dgx-spark. The end state is PNG files in the directory the user named (default: the current directory), checked by you and reported with the seed and settings.

Fixed values:
- Tool: `~/colmena/.claude/skills/comfyui/scripts/comfy`. Make every ComfyUI call through it. `comfy` in the commands below means this path. Default host: the dgx-spark, `http://192.168.10.14:8000/upstream/comfyui` (llama-swap).
- Host: `comfy --host HOST gen ...` or the `COMFY_HOST` environment variable. `--host` goes before the subcommand. HOST is a bare host (`gx10.local`), `host:8000`, or a full URL. Those on port 8000 or with no port are reached through llama-swap's `/upstream/comfyui`. Any other explicit port (`192.168.10.14:8014`) is treated as ComfyUI itself. Use `--host` only when the user names another machine.
- `comfy gen TEMPLATE --prompt P [--negative N] [--seed S] [--width W] [--height H] [--steps N] [--cfg C] [--sampler X] [--scheduler X] [--batch N] [--param NAME=VALUE]... [--set NODE.inputs.FIELD=VALUE]... [--out F.png] [--dry-run]` generates and downloads. It prints the file path, then `seed=` and `time=` on stderr. A random seed is used unless `--seed` is given.
- `comfy models` lists the diffusion, text encoder, VAE and LoRA files ComfyUI sees, plus CLIP types, samplers and schedulers. Run it before naming any file.
- `comfy upload IMG` uploads an input image and prints the name to use in `--param image=NAME`.
- `comfy info X.png` prints the API graph embedded in a ComfyUI PNG.
- TEMPLATE is the `workflow.json` in a model skill's directory. It holds named params (`prompt`, `seed`, `width`, ...) mapped onto graph nodes. A param the template does not have is an error that lists the ones it does have.
- Models run one at a time. llama-swap starts the ComfyUI container on the first request (20-40s) and evicts any LLM that conflicts with it. Switching between image models inside ComfyUI costs another 10-25s. Never stop containers yourself.
- Look at each PNG before you report it. Use your image viewing tool. If you have none, say so and give the user the path to judge.

Steps:

1. Pick the model skill that fits and read it. Use its template and prompt style.
   - Text rendering, layouts, long detailed prompts: comfy-moss-image.
   - Fast drafts and variations: comfy-z-image, comfy-krea-2.
   - Editing an existing image: comfy-flux2-klein, with `workflow-edit.json`.
   - Comparing models: same prompt, same seed, same size on each. Each model keeps its own sampler settings.

2. Write the prompt in that model's style. Do not pad it with quality words ("masterpiece", "8k").

3. Generate. Run one `comfy gen` at a time. Name files `<subject>-<model>-<seed>.png`.
   - For a quick look at several seeds, run `--batch 4` on one model, not four calls.
   - For a model comparison, run the models one after another. Each switch reloads weights.

4. Look at each PNG. Check it against the prompt: count of people, hands, any quoted text spelled correctly, framing, and whatever else the user asked for. Report the seed and what is wrong, not just that it generated.

5. Iterate on one variable per round. Keep the seed when changing the prompt wording. Change the seed when you want a different composition of the same prompt.
   - To redo an earlier image with small changes, pass its PNG as the template: `comfy gen old.png --seed N --set <prompt node>.inputs.text="..."`. Find the prompt node with `comfy info`. Seeds are found automatically.

Adapting the workflow:

- Any input of any node can be changed with `--set NODE.inputs.FIELD=VALUE`. VALUE is read as JSON when it parses, so numbers, `true` and links like `'["20",0]'` work. Quote links in the shell.
- Templates carry optional nodes that are wired but not connected. ComfyUI only runs nodes that reach an output, so connecting one turns it on.
  - LoRA (node `20` in every template). Run `comfy models`, pick a file, then `--set 20.inputs.lora_name=<dir/file.safetensors> --set 20.inputs.strength_model=0.8` and point the sampler's model input at it: `--set '7.inputs.model=["20",0]'` (Z-Image and Krea-2: `--set '10.inputs.model=["20",0]'`; Klein: `--set '12.inputs.model=["20",0]'`). Use a LoRA made for that model only. Ask the user before choosing one.
  - Other optional nodes are listed in each model skill.
- To add nodes that a template lacks (upscaling, a second refine pass, inpainting), copy the template, add the nodes in API format, and pass your copy as TEMPLATE. Keep the node ids. Run `--dry-run` first to see the final graph.
- To check a graph without generating, use `--dry-run`. A 400 from ComfyUI names the bad node and field.
- A ComfyUI UI workflow file (`~/comfyui/user/default/workflows/*.json` on the Spark) is not API format and cannot be posted. Rebuild its core nodes as an API graph.

When something fails:
- HTTP 500 on the first call after a ComfyUI restart: rerun it. The command already retries three times.
- Timeout or a stuck first call: the user's chat model and ComfyUI evict each other. Ask the user whether they are chatting, then rerun.
- `generation failed` with an out-of-memory message: lower `--width`/`--height` (multiples of 16) or `--batch 1`.
- `Value not in list`: the file or option name is wrong. Run `comfy models`.
