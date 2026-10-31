---
name: comfy-z-image
description: Generate images with Z-Image Turbo (Q8_0 GGUF, 4 steps) on the dgx-spark ComfyUI. Use for fast drafts, many variations, or when the user names Z-Image or ZIT. Load the comfyui skill first.
---

Use this skill for Z-Image Turbo text-to-image. Read the `comfyui-spark` skill first for the CLI, the steps, and how to adapt a workflow.

Fixed values:
- Template: `~/colmena/.claude/skills/comfy-z-image/workflow.json`. Defaults: 1024x1024, 4 steps, CFG 1, `res_2s`, `bong_tangent`, shift 7. These match the user's saved workflow `Comfy.json`.
- Run: `comfy gen ~/colmena/.claude/skills/comfy-z-image/workflow.json --prompt "..." --seed 1 --out x.png`.
- A 1 MP image takes about 10s once loaded, about 16s after a model switch. This is the fastest model. An identical repeat (same seed, prompt and settings) returns instantly from ComfyUI's cache.
- Text encoder: Qwen3-4B (CLIP type `lumina2`). VAE: `ae.safetensors`.
- CFG is 1, so the negative prompt has no effect. Do not write one.
- `shift` is a template param: `--param shift=5`. `res_2s` and `bong_tangent` come from the RES4LYF node pack. `euler` with `simple` is the plain fallback.
- The user's own `Comfy.json` workflow also runs a second refine sampler (`res_multistep`, `linear_quadratic`, denoise 0.3). This template omits it. Add it to a copy of the template when the user wants that look.

Prompting:
- Write natural-language sentences describing the finished picture: subject, action, setting, light, framing, medium. One to three short paragraphs.
- Keep text in the image short and quoted. Check the spelling in the PNG.
- Not tested for long prompts. When a prompt over about 150 words loses details, shorten it before changing settings.
- LoRAs for this model live in `loras/z-image-turbo/` (see `comfy models`). Node `20`, see the `comfyui-spark` skill. Ask the user before choosing one.
