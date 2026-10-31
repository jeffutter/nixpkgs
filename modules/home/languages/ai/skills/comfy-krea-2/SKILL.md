---
name: comfy-krea-2
description: Generate images with Krea-2-Turbo (Q6_K GGUF, 4 steps) on the dgx-spark ComfyUI. Use for fast drafts and variations when the user names Krea or Krea-2. Load the comfyui skill first.
---

Use this skill for Krea-2-Turbo text-to-image. Read the `comfyui` skill first for the CLI, the steps, and how to adapt a workflow.

Fixed values:
- Template: `~/colmena/.claude/skills/comfy-krea-2/workflow.json`. Defaults: 1024x1024, 4 steps, CFG 1, `euler`, `simple`, shift 3. These match the user's saved workflow `Comfy (Krea).json`.
- Run: `comfy gen ~/colmena/.claude/skills/comfy-krea-2/workflow.json --prompt "..." --seed 1 --out x.png`.
- A 1 MP image takes about 20s including the model switch.
- Text encoder: Qwen3-VL 4B (CLIP type `krea2`). VAE: `qwen_image_vae.safetensors`.
- The GGUF loader for this model is the RealRebelAI fork of ComfyUI-GGUF, which the user accepted on trust grounds. Do not reinstall or replace it.
- CFG is 1, so the negative prompt has no effect. Do not write one.
- `shift` is a template param: `--param shift=2`.
- The user's own workflow also runs a second refine sampler (`res_multistep`, `linear_quadratic`, denoise 0.3). This template omits it.

Prompting:
- Write natural-language sentences describing the finished picture: subject, action, setting, light, framing, medium. One to three short paragraphs.
- Keep text in the image short and quoted. Check the spelling in the PNG.
- Not tested for long prompts or for how it differs in style from the other models. Compare with the same seed on the other models before claiming a strength.
- LoRAs for this model live in `loras/krea2-turbo/` (see `comfy models`). Node `20`, see the `comfyui` skill. Ask the user before choosing one.
