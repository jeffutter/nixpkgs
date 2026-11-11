# Character LoRAs on other models (Z-Image Turbo, Krea 2, FLUX.2 Klein)

Optional reference for `character-lora-training`. Read it only when the user wants a LoRA on a model other than MOSS-Image. All numbers are from one pair of people (Jeff, 29 images; Rebecca, 47 images), one seed per image, on the GPU host, Fizgig v9.0.8 for the runs.

## Run any model headless

`fizgig_run.py` can start from a model's built-in preset when there is no earlier run to clone (the `--base-run` way still works):

```
fizgig tool fizgig_run.py --family zimage --list-presets
fizgig tool fizgig_run.py --family zimage --preset "<preset name>" --name NAME --folder /workspace/datasets/D --trigger WORD --masked [--epochs N] [--megapixels MP] [--plan]
```

If `fizgig` fails with a missing `~/fizgig/password`, the container was not started by `fizgig up`; run `fizgig up` once. Resolution comes from the preset unless you pass `--megapixels`; read what the plan prints before you start.

| Model | `--family` | Preset used | Epochs (we set) | Downloads | Time Jeff / Rebecca |
|---|---|---|---|---|---|
| MOSS-Image Base | moss_image | Standard (web UI) | 40 | already there | 65 / 110 min at 1.5 MP |
| Z-Image Turbo | zimage | "Z-Image Turbo Standard (rank 16, adaptive LR)" | 30 (preset) | about 21 GB, no account | 20 / 39 min, 1.4-1.65 s/step |
| Krea 2 | krea2 | "Krea 2 Standard (rank 32, full model)" | 40 (preset says 64) | about 32 GB (RAW 26 GB), no account | 31 / 51 min, about 1.6 s/step; Fizgig's auto plan chose 0.25 MP |
| FLUX.2 Klein 9B | klein | "Old Reliable (rank 16, full model, single subject)" | 40 (preset says 55) | about 35 GB, gated | 24 / 40 min, about 1.25 s/step |

Download with `python -m fizgig.scripts.fetch_models --family F --models-dir /workspace/models` inside the container (it also writes the paths into Fizgig's preferences). Klein needs `HF_TOKEN` and the FLUX.2 Klein licence accepted on that account; the GPU host has an `hf-token` sops secret at `~/.config/sops-nix/secrets/hf-token`, passed into the container as an env var without printing it. Z-Image and Krea 2 need no token.

Copy the final file to `~/comfyui/models/loras/NAME/NAME-final.safetensors` and load it with node `20` as in the `comfyui-remote` skill. The rewire node differs: `10.inputs.model` for Z-Image and Krea 2, `12.inputs.model` for Klein.

## Disk and memory traps

- Per-epoch saves add up: Krea 2 wrote 235 MB per epoch plus a state folder of about 13 GB per run; Z-Image and Klein state folders were 3 to 4 GB. A finished run's `-state` folders only allow resuming and can be deleted. The GPU host was at 97% full after four models; check `df -h ~` before each run.
- **Fizgig plans memory from free GPU memory, and file cache hides it.** After downloading model files and building an image, the page cache held about 79 GB and Fizgig saw 5 GB free, switched on heavy block swapping, and trained about 25% slower. Release cache without root with `posix_fadvise(DONTNEED)` on the big files (python `os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)` over `workspace/models`, `output_loras` and `~/comfyui/models`). Check `free -g` (the "free" column) before timing anything.
- Fizgig needs the whole GPU. `GET /unload` on llama-swap, check `/running` is empty, and tell the user their chat model is gone.

## Results (ArcFace to held-out photos; Jeff's reference set is 4 of his training photos, a sanity check only; noise about 0.05)

Same prompts, seeds and sizes (864x1152 full body, 1024x1024 otherwise), strength 1.0, on the user's GGUF files in ComfyUI. Rows are full body, cafe, portrait, painting (Jeff) and full body, cafe, candid, painting (Rebecca).

| | MOSS | Z-Image | Krea 2 | Klein (CFG 4, 8 steps) | Klein (CFG 1, 4 steps) |
|---|---|---|---|---|---|
| Jeff | .53 .61 .55 .38 | .35 .50 .51 .17 | .49 .04* .60 .20 | .44 .43 .40 .24 | .53 .59 .50 .33 |
| Rebecca | .34 .64 .51 .42 | .23 .46 .34 .09 | .41 .61 .58 .45 | .15 .43 .39 .31 | .41 .39 .42 .31 |

\* A second man in the foreground; the score is not reliable.

- MOSS-Image scored highest or close to it on most prompts. Krea 2 matched it on Rebecca and was close on Jeff, in about half the training time at a lower resolution. The user said Krea 2 "turned out pretty good".
- Z-Image Turbo was weakest, especially on paintings.
- The recipes differ (rank, resolution, epochs), so these compare recipes, not only models.
- Glasses (in most of the person's photos, not captioned) were missing in some Klein images; Rebecca's had none.
- FLUX.2 Klein: the user judged the Klein results bad ("they just don't look like the intended people"). Klein's distilled GGUF wants 4 steps and CFG 1 (Fizgig's own preview setting); the skill template's 8 steps and CFG 4 scored lower. If a Klein LoRA looks wrong, re-render at 4 steps and CFG 1 before blaming the training. Even so the user was not satisfied.

## Klein reference-photo editing instead of a LoRA

Tried once, no training: the `comfy-flux2-klein` edit template (`workflow-edit.json`) with a training photo as the reference image and the scene as the instruction ("the man in the reference image ..., keep his face, beard, glasses and hair"). Two references: add a second `LoadImage`, `ImageScaleToTotalPixels`, `VAEEncode`, and chain two more `ReferenceLatent` nodes onto the first pair for positive and negative conditioning. By eye the identity, glasses, beard and hair carried over in single-person edits and in three two-person seeds (pair standing close, arm around her). ArcFace per half 0.42 to 0.46 for Rebecca (held-out), 0.43 to 0.45 for Jeff (biased up: his reference photo was among the score photos). The user's overall verdict on Klein was negative, so do not present this as solved; it is an untested alternative that needs a reference photo of each person every time.

## Updating Fizgig itself

- The deployment config's `fizgig/Dockerfile` pins an upstream commit. v9.2.1 moved PyTorch to 2.15 on the `cu134` index, which has aarch64 wheels, so the old `cu128` to `cu130` rewrite is gone and the build now fails if the index line changes again. Python 3.12 and driver 580 are fine for it. The pin is now v9.2.1 (commit `4919525d`).
- Build with that Dockerfile on the GPU host, test on a spare port, then `docker tag ... fizgig:latest` and `fizgig up`. Measured on a 4-epoch Klein run with free memory: 2:55 on v9.2.1 against 3:27 on v9.0.8, about 15% faster including warm-up; a full-length run was not timed.
- The old image seemed unable to read the caches the new one wrote (loss 1.98 instead of 0.70). Unverified. Do not run two Fizgig versions against the same workspace.
- `docker ps -a` showed an old exited `fz-fetch` container holding the old image; remove it before `docker rmi`.
