---
name: comfy-moss-image
description: Generate images with MOSS-Image SFT (5B, NVFP4) on the dgx-spark ComfyUI. Use for long detailed prompts, accurate English or Chinese text in the image, posters, signs, or layouts, or when the user names MOSS. Load the comfyui skill first.
---

Use this skill for MOSS-Image SFT text-to-image. Read the `comfyui-spark` skill first for the CLI, the steps, and how to adapt a workflow.

Fixed values:
- Template: `~/colmena/.claude/skills/comfy-moss-image/workflow.json`. Defaults: 1024x1024, 25 steps, CFG 2.5, `er_sde`, `simple`.
- Run: `comfy gen ~/colmena/.claude/skills/comfy-moss-image/workflow.json --prompt "..." --seed 1 --out x.png`.
- A 1 MP image takes about 3s once loaded, about 30s after a model switch.
- Resolution: 1, 1.5 or 2 megapixels. Width and height must be multiples of 16. The model extrapolates from 0.25 MP to 4 MP.
- It does use the negative prompt (CFG 2.5). The default is `nsfw, worst quality, bad anatomy, watermark, jpeg artifact`. Add to it, do not replace it.
- It takes prompts up to about 4000 tokens. English is the best-trained language. Chinese text renders well.
- The model has no reference-image input.

The prompt is the main lever. ComfyUI's official template runs a prompt enhancer that rewrites a short prompt into a long caption. This template does not. You are the enhancer: write the long caption yourself.
- Open with the medium and the subject: "Studio photograph of ...", "Anime-style digital illustration of ...". Never open with a verb.
- Write 220-320 words for one subject, 320-500 for posters, cards, several subjects or lots of text. Two to four paragraphs of flowing prose, ordered by space or by where the eye goes.
- Cover these when the scene has content for them: subject (appearance, garments, materials), action (pose, hands, gaze, expression), space (foreground, midground, background), setting, framing (shot size, camera height, angle), light (direction, hardness, color, practical sources), tone (palette, grain, medium), text.
- Describe the finished picture only. No edit verbs, no "similar to", no size or aspect ratio in the prompt.
- Text in the image: put the exact string in double quotes, once. For each block give the carrier (sign, poster, mug), position, size, typeface style, color and legibility. Use `\n` for line breaks. Write the user's own words verbatim.
- Never invent real brands, people's names or specifications.
- No tag soup and no "masterpiece, 8k".
- For a candid look, say so in the caption and put the polished look in the negative prompt: `--negative "nsfw, worst quality, bad anatomy, watermark, jpeg artifact, professional photography, studio lighting, bokeh, retouched, cinematic, HDR, stock photo"`.

Options:
- Closer to the official quality: `--steps 50 --cfg 3 --sampler euler`.
- Short prompt and a flat result: raise `--cfg` to 3-6.
- Skip-layer guidance (node `15`, layer 22), off by default. Turn it on with `--set '7.inputs.model=["15",0]'`. It adds detail and can overblow anime styles. Layers 24 and 26 also work: `--set 15.inputs.single_layers=24`.
- LoRA: node `20`, see the `comfyui-spark` skill. MOSS-Image Base is the checkpoint made for community LoRAs. This install has only the SFT file.
- The model's native seeds do not reproduce the OpenMOSS pipeline's images, only this ComfyUI's own.
