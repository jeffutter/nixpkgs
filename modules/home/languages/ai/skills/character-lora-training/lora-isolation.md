# Fizgig LoRA Isolation: one LoRA for two or more people (plan, not yet tried)

Optional reference for `character-lora-training`. Nothing here has been run for our two people. It is read from Fizgig's own docs (`docs/LORA_ISOLATION.md` and `docs/MULTI_PERSON.md` inside the container, `/opt/fizgig/docs/`) and written down so we can try it later.

## Why it matters

Our two-person recipe (`two-person.md`) combines two separate LoRAs after the fact and stays uneven: one person is usually fairly far off. LoRA Isolation is Fizgig's way to train several people into one LoRA so they can stand in one picture and each keep their own face, and strangers in the picture do not pick up anyone's likeness. It is built on DOP (Differential Output Preservation, from Ostris's AI-Toolkit) plus extra parts.

## What it does (summary of the docs)

- Each person has their own folder and their own trigger word. Captions start `trigger, a man` / `trigger, a woman`. Fizgig reads that as one fused word (`gweltman`) when training, without editing the files.
- Each training photo is also trained with the trigger removed, held to the base model's own output, so the LoRA changes nothing when the trigger is absent.
- Fizgig adds 16 side-by-side pictures per person (their photo next to one of 32 fixed generated strangers) at 2x learning rate, so the LoRA learns "this face is the subject, that one stays a stranger" in one frame. The strangers come with any model's download in Preferences (about 21 MB).
- Training takes about 1.5x a normal LoRA.
- Fizgig's own test (on Krea 2, one subject plus a friend): strangers that read as the subject, 48 of 50 images with a normal LoRA vs 0 of 50 with Isolation. Likeness stayed the same (0.77 vs 0.78 ArcFace). That is the vendor's measurement of leakage to strangers, not a measurement of our case, which is two trained people together.
- Up to 4 subjects train well; 2 or 3 can share a picture. Two same-class subjects need about 1.6x the epochs; a man and a woman pair was right at epoch 10 in their test.

## Tested where

Only on Krea 2 per the docs. The method is available on every Fizgig model except ACE-Step. We have not seen it on MOSS-Image.

## Setup for our pair

Set on the Training tab, **Subjects** card: 2 subjects, subject 1 is the training folder, subject 2 has its own folder, mode **Fizgig LoRA Isolation**, **Balance the subjects** on.

Datasets: `datasets/jeff` (29 images, masks) and `datasets/rebecca` (47 images, masks). Captions already start `Trigger, a man/woman`, so most work is done, but:
- Triggers need changing. The docs want made-up words that share no first letter or piece with each other and end in a consonant, for example `dlor`, `gwelt`, `jeskv`, `knurv`, `vorlk`, `thrisk`, `zwxem`. `JeffUtter` and `RebeccaBumgarner` are CamelCase name-like words, and they would also read as `JeffUtterman` and `RebeccaBumgarnerwoman`. Pick two new words and check them with **Check a trigger word** at the bottom of the Subjects card (it uses the model's own tokenizer). Then replace the old trigger at the start of every caption (`sed`), and keep a copy of the old captions.
- Photos with both people in them: use both triggers in the caption, put the photo in either folder. Our masks remove the other person from the training signal, and captions omit masked people, so check which photos have both before retraining.
- Never put another subject's trigger in a folder where that person is not in the photo.

Training (starting point from the docs): rank 16 to 32, adaptive LR or the Standard preset for the model, seed 42, keep the in-between epochs (save every 2) and pick one. Our MOSS run used rank 32, Muon, 1.5 MP, masked training floor 0.1. How MASKED_TRAINING combines with Isolation was not checked.

Prompting afterwards: use the joined word (`gweltman`, `zwxemwoman`), name any other people first and describe them, and describe your own subjects too (hair). Without a trigger you get the model's own people.

## How to judge it

1. Two-person render with both triggers in one prompt. ArcFace of each half against each person's held-out photos (Rebecca has 3 in `score-two/refR`; Jeff has none, so his score is a sanity check only).
2. Compare with the SAM-repaint results in `two-person.md` (Rebecca 0.36 to 0.60, Jeff 0.41 to 0.57 across 9 images, one seed each, noise about 0.05) on the same prompts and seeds.
3. Look at every image, bodies included. ArcFace measures faces only.
4. Leak check: a prompt with a stranger next to one of them, with and without triggers.

## Cost (estimates, not measured)

- Combined set is 76 images. Our measured MOSS speeds were 2.65 s/step at 1 MP and 3.6 s/step at 1.5 MP, so 40 epochs would be roughly 3000 steps. With the 1.5x Isolation overhead that is on the order of 4 to 5 hours at 1.5 MP. Measure a few steps before committing.
- Isolation was tested at 0.25 MP on Krea 2; lowering the resolution on MOSS would cut the time, with an unknown effect on likeness.
- `fizgig_run.py` clones a previous run's settings and has no Subjects options yet. The first Isolation run is easiest from the web UI (`@loraUi@`, password from `fizgig password`).
