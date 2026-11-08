---
name: character-lora-training
description: Train and evaluate a character (person) LoRA for MOSS-Image with Fizgig on the dgx-spark, then render with it in ComfyUI. Use when the user wants a LoRA of a specific person, wants to retrain or compare LoRA runs, improve face likeness or body shape in full-body renders, or names Fizgig.
---

Use this skill to turn a folder of photos of one person into a LoRA that renders them in MOSS-Image. The end state is a `.safetensors` file in ComfyUI's LoRA folder, test renders that you looked at, and a likeness score, reported with what was and was not checked.

The photos show a real, usually private person. Keep them on the spark. Do not put them or renders in an Artifact, a git repo, or a shared page unless the user asks.

Fixed values:
- Everything runs on the dgx-spark: `ssh jeffutter@192.168.10.14`. The `fizgig` command there is the only entry point to the trainer: `fizgig up | down | status | password | tool SCRIPT.py ARGS | sh CMD`. Its source is `home/dgx-spark.nix` and `home/fizgig/` in the colmena repo.
- Workspace: `~/fizgig/workspace` on the spark (`/workspace` in the container): `datasets/NAME/`, `output_loras/NAME/`, `models/`, `user_data/runs.json`, `tools/`. Container-written files are root-owned: delete them with `fizgig sh rm -rf /workspace/...`.
- Web UI: `http://192.168.10.14:8081`, password from `fizgig password`.
- Tools (`fizgig tool X.py`, docs at the top of each file): `face_prep.py` (face crops), `sam_masks.py` (person masks), `fizgig_run.py` (start a run), `arcface_score.py` (likeness score).
- Model: MOSS-Image Base, Standard preset, rank 32, Muon. Measured: 2.65 s/step at 1 MP on 26 images; 3.6 s/step at 1.5 MP on 47 images (40 epochs, 1880 steps, 1 h 50 min). Measure before you estimate: a guess of 8 s/step was 3x too high.
- Render with the `comfyui-spark` and `comfy-moss-image` skills. ComfyUI runs MOSS-Image SFT NVFP4; Fizgig trains on Base. The LoRA transfers, strength 1.0.
- ComfyUI workflows (Workflows sidebar, key `w`): "MOSS-Image + Character LoRA" and "... + Face Detail". In each, set the LoRA in `LoraLoaderModelOnly` and start the prompt with the trigger word. The face-detail one upscales 2x, repaints only the face at denoise 0.4, and takes about 140 s.

Steps:

1. Pick and clean the photos. Look at every image (contact sheets of 12-16).
   - Drop: other people in frame (check siblings and look-alikes by comparing faces, not by guess), near-duplicates, heavy filters, sunglasses, tiny or blurry shots.
   - Keep variety in clothing, light, setting, and distance. Full-body and half-body shots matter most for body shape: a set of mostly close-ups gives a good face and a weak body.
   - Convert HEIC to PNG or JPG with ImageMagick (`magick in.HEIC[0] -auto-orient out.png`); Fizgig cannot read HEIC.
   - Export at or above the training size. Fizgig resizes to `DATASET_MEGAPIXELS` (I did not test what it does with smaller images), so export each photo at or above it: 1.5 MP is about 1225x1225.
   - Ask the user which photos are the person when it is ambiguous. Do not guess for a private individual.

2. Upload to `~/fizgig/workspace/datasets/NAME/` (`scp`), run `fizgig up`. `up` evicts every llama-swap model first (`GET /unload`, not POST) and refuses to start unless `/running` is empty. Tell the user the chat model is gone until `fizgig down` and the next request to it (a cold start takes 3-4 minutes).

3. Close-ups and masks.
   - Far-away full-body shots teach little face detail. Add face crops of those with `face_prep.py` so the face is seen at a useful size.
   - If any photo has other people or a busy background, run `sam_masks.py FOLDER FACE1.png FACE2.png ...` with 2-4 clear face crops of the person. It writes `NAME-masklabel.png` next to each image. Look at the masks before training. Start the run with masked training on (floor 0.1).

4. Captions: one `.txt` per image, same stem. Fizgig's docs say the trigger stands only for the person and anything left out of a caption is learned as part of them. So:
   - Invent a trigger that is not a word, for example a CamelCase full name. Start every caption with `TRIGGER, a woman` (or man, or person).
   - Describe what varies: clothing, pose, expression, setting, light, framing, camera distance. 55-100 words of plain sentences.
   - Leave out what is constant for the person: hair colour, eye colour, build, glasses. They fold into the trigger. Cost: a trait you leave out cannot be prompted away later. One run with glasses in most photos and no mention in the captions rendered glasses in every image, even with "no glasses" in the prompt. If the user wants it controllable, name the trait in captions of the photos where it is present and keep some photos without it.
   - Do not caption body shape. The trigger should learn it from the full-body photos. Writing it down is a decision to take to the user.
   - Check on the first caption that the trigger appears verbatim (Fizgig only joins trigger and class word in multi-subject isolation mode).
   - You are the captioner. Write them yourself from the images or use the description model, and read every caption once.

5. Train. First time ever: make one run in the web UI with the Standard preset so `runs.json` has a base. Then `fizgig tool fizgig_run.py --base-run PREV --name NAME --folder /workspace/datasets/NAME --trigger TRIGGER --epochs 40 --megapixels 1.5 --masked --plan` to check, then without `--plan`. Poll the log in `user_data/logs/` (a `tail -c 400 | tr '\r' '\n'` shows the progress bar). Report progress on the cadence the user asked for.
   - Likeness is learned early: a 26-image run had plateaued by epoch 22 (ArcFace, one image per epoch, so noisy). In the 47-image run the user judged the final file at least as good as epochs 30 and 36. Use the final file unless the user compares epochs. Keep the final only: delete the per-epoch files and `-state` folders when the user has picked (`fizgig sh rm -rf /workspace/output_loras/NAME/NAME-0000*`).
   - Copy the chosen file to `~/comfyui/models/loras/NAME/NAME-final.safetensors`.

6. Render a fixed test set: the same 5-7 prompts and seeds for every run you compare (a full-body, a portrait, a seated shot, a candid, an unusual style). Use the trigger first, then the same caption style as the training set. Write prompts for a new LoRA in the new caption style; do not feed a retrained LoRA the old run's prompts, or you compare prompts. Look at every image yourself.

7. Score. `fizgig tool arcface_score.py --train DATASET --refs REFS --samples DIR`.
   - REFS are photos of the person that are not in the training set. The tool drops any whose best similarity to a training image is 0.75 or more; with fewer than 3 survivors, ask the user for more photos.
   - ArcFace measures the face only, not the body. At one seed and 3 references, a gap under 0.05 is noise. A no-LoRA control scores about 0.02-0.14; a good LoRA scores 0.5-0.65 on close-ups; a same-person ceiling is about 0.7.
   - Never report a score as "looks more like her". Say what the number is and what you saw.

8. Face detail for full-body shots. Faces in full-length renders are small and score low (0.34-0.43 in one run). The face-detail workflow raised the mean of three from 0.38 to 0.47; a script that cropped the face, regenerated it at 1024 px, and pasted it back reached 0.52, within noise of it. Use the workflow; it needs no extra install.

9. Finish. Tell the user the LoRA path and which checks you did. Ask before `fizgig down` if the user may start another run soon. Restore a chat model only when the user says they are done: any request to it loads it.

Known limits:
- Single seed per prompt in every comparison so far. More seeds cost about 30 minutes for 21 renders.
- Full-body framing can drift farther from the camera after a retrain with many full-body captions; that shrinks the face and lowers the score without the face being worse. Compare crops, not whole-frame scores.
- Backflips and other unusual poses scored about 0 for every run.
