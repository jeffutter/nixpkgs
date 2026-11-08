# Two people in one image with two character LoRAs

Optional reference for `character-lora-training`. Read it only when the user asks for an image with two trained people. Everything here was tested with one pair (Jeff and Rebecca), one seed per image, and the user judged the best recipe "pretty weak": one person or the other ends up fairly far off. Say that when you hand results over, and do not promise a likeness.

## What was tried (in order) and what happened

1. Stack both LoRAs on the model at 1.0 each. One person's features bleed onto the other (his beard on her face). At 0.7 each the faces are clean but generic.
2. Both LoRAs light (0.5), then repaint each face with only that person's LoRA. Faces are better, bodies look generic. Repainting whole left and right halves changed almost nothing, because pose and proportions come from the base render.
3. Both at 0.9, then the same face pass. Fuller faces, but the stronger LoRA's body shape took over: she came out as wide as him and wore his watch.
4. Render each person alone, cut out with SAM, paste into one scene. Rejected by the user: they look "photoshopped" in and cannot touch.
5. Current recipe (below). The user preferred it: bodies and the scene look natural, people can touch. Quality is still uneven.

## Current recipe: neutral base, SAM masks, per-person repaint, per-person face pass

Saved workflow: "MOSS-Image + Two Character LoRAs + SAM Repaint" (generic, from `comfyui-workflows/moss-image-two-character-loras-sam.json`). One ComfyUI graph, about 8 minutes at 1024x1152, any size works (tested 1280x896).

1. Base render with no LoRA. The prompt describes each person's build, clothes and distinguishing features and says where they stand. This is where body shape comes from, so use real facts the user gives: height, weight, build.
   - Describing the person as "heavy, stocky, soft belly" produced a far heavier man than the user. Use "average height, average, slightly solid build" style wording and check the render against the user's numbers.
   - Describe hair from the photos, not from the LoRA's renders. "Long wavy brown hair past her shoulders" (copied from a LoRA render) gave glossy ombre hair and a pinched crown tuft. "Straight to loosely wavy, shoulder length, side-parted, a few loose strands around the face" looked right.
   - Say "bare wrists, no watch" for the person who does not wear one. Without it the stronger LoRA's accessories leaked onto the other person.
2. ComfyUI's built-in `SAM3_Detect` masks each person. Model: `sam3.1_multiplex_fp16.safetensors` (1.75 GB, https://huggingface.co/Comfy-Org/sam3.1, SAM License) in `models/checkpoints`, loaded with `CheckpointLoaderSimple`; its CLIP output feeds a `CLIPTextEncode` that goes into `SAM3_Detect.conditioning`. Takes 2-4 s.
   - Use two nodes with the prompts `man` and `woman` (or other nouns that tell them apart). A bare `person` returned only one of the two. `person:5` returned both, but the order is not stable, so do not rely on index 0 being the left person.
   - Grow each mask 12 px.
3. Repaint each person at denoise 0.75 with only their own LoRA at strength 1.0 and their own prompt (`TRIGGER, a man ...`), masked by their SAM mask (`SetLatentNoiseMask`, composite with a blurred mask). 0.6 kept more of the base and looked less like the LoRA.
4. 2x upscale (UltraSharp), then a face pass per person: MediaPipe face landmarks (`num_faces=2`), each face mask multiplied by that person's SAM mask so a face goes to the right person, grown 40 px, repainted with that person's LoRA at denoise 0.45 (first person) and 0.5 (second).

## Results (ArcFace per person, one seed each, noise about 0.05)

- Rebecca vs 3 held-out photos: 0.36 to 0.60 across 9 images. Jeff vs 4 of his own training photos (sanity check only, they were in training): 0.41 to 0.57.
- Control with both LoRA strengths at 0: 0.00 and 0.03. The LoRAs carry the likeness, not the prompt.
- Scenes tried: park standing close (several seeds), cafe seated, he stands behind her with his arms around her (the mask-overlap case, no visible seam), street walking apart, landscape size. Different seeds gave very different bodies.
- Not tried: three or more people, more than one seed per new scene, other denoise values after the prompt fix.

## Limits to state

- Weakest person varies by seed; the user saw one of the two "fairly far off" in most images.
- The scores measure faces, not bodies. Judge bodies by eye and say so.
- A LoRA trained on photos that contain both people is the stronger fix; it needs such photos and another training run (about an hour).
- If the pair share a trait folded into both triggers (both wear glasses), the repaint cannot remove it.
