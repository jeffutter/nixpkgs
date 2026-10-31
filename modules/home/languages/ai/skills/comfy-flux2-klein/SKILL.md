---
name: comfy-flux2-klein
description: Generate or edit images with FLUX.2 Klein-9B (Q8_0 GGUF) on the dgx-spark ComfyUI. Use to edit or restyle an existing image from a reference, to change one thing and keep the rest, or when the user names Klein or Flux.2. Load the comfyui skill first.
---

Use this skill for FLUX.2 Klein-9B text-to-image and for editing a reference image. Read the `comfyui` skill first for the CLI, the steps, and how to adapt a workflow.

Fixed values:
- Text-to-image template: `~/colmena/.claude/skills/comfy-flux2-klein/workflow.json`.
- Edit template: `~/colmena/.claude/skills/comfy-flux2-klein/workflow-edit.json`. It adds `--param image=NAME` and `--param megapixels=1`.
- Defaults for both: 1024x1024, 8 steps, CFG 4, `euler`. These match the user's saved workflow `Klein.json` (it was an edit graph).
- A 1 MP image takes about 20-40s including the model switch.
- The negative prompt is used (CFG 4). The user's saved one is `different face, different person, different build, distorted face, deformed hands, extra limbs, different lighting, harsh contrast, dramatic hard shadows, duplicate face, extra face, floating head`. Use it for edits of people. Leave it empty for plain text-to-image unless a problem shows up.
- Text encoder: Qwen3-8B fp8 mixed (CLIP type `flux2`). VAE: `flux2-vae.safetensors`.

Editing:
1. Upload the source image: `comfy upload photo.jpg` prints a name such as `photo.jpg`.
2. Run: `comfy gen ~/colmena/.claude/skills/comfy-flux2-klein/workflow-edit.json --prompt "<instruction>" --param image=<name> --width W --height H --out x.png`.
3. Set `--width` and `--height` to the source's aspect ratio, as multiples of 16 around 1 MP (for example 896x1152 for a 3:4 portrait). They set the output size. The source is rescaled to `megapixels` only for conditioning.
4. Write the prompt as an instruction about the change: "Make it a sunny afternoon with no rain, keep the same people and helmet". Name what must stay the same.
5. Read the result next to the source. Check identity, clothing, and everything you did not ask to change. Tested once on a two-person photo: the identities held and the lighting changed as asked.

Notes:
- To use no reference image, use `workflow.json`. It is the same graph without the reference nodes.
- LoRAs for this model live in `loras/flux-2-klein/` (see `comfy models`). Node `20`, see the `comfyui` skill; the model input to rewire is node `12`. Ask the user before choosing one.
- Not tested: Klein's text-to-image quality against the other models, or two reference images.
