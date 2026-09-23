---
name: voice-dna-creator
description: Analyze writing samples to create a comprehensive voice DNA profile. Use when the user wants to capture their unique writing voice, needs to create a voice profile for AI content, or is setting up a new writing system.
---

# Voice DNA Creator

Use this skill when the user wants a voice profile built from their writing, or from a client's writing. The end state is a saved JSON voice profile that the user confirms sounds like them.

Profile path for the user's own voice: `~/.config/home-manager/modules/home/languages/ai/skills/voice-dna/references/voice-dna.json`. The `voice-dna` skill reads this file.

Profile path for another person's voice: `./voice-dna-<person-name>.json` in the current working directory.

## Steps

1. Ask the user for 3 to 10 writing samples of 500+ words each. Ask for a mix of casual pieces (social posts, emails) and formal pieces (articles, newsletters). Accept pasted text or file paths.
   - Fewer than 3 samples: tell the user the profile will be less reliable, then ask whether to proceed.
2. Read every sample. For each sample, record:
   - Personality: traits shown, energy level, how the writer relates to the reader.
   - Emotion: emotions expressed, their intensity, the dominant tone.
   - Communication style: formality, sentence length, paragraph structure, mix of questions, commands, and statements.
   - Language: repeated signature phrases, frequent strong words, transition phrases, opening and closing patterns.
   - Absences: words, phrases, tones, and approaches the writer never uses.
   - Formatting: emoji, lists, headers, bold and italic use.
3. Compare the per-sample notes. Sort each pattern into one group:
   - Consistent: appears in most samples.
   - Contextual: changes with content type, such as social posts versus articles.
   - Core: appears in every sample.
4. Write the JSON profile using the structure below. Set `last_updated` to today's date.
   - Describe tone and personality, beyond word frequency.
   - Fill `never_say` with the absences from step 2.
   - Record contextual variations in `communication_style` or `formatting_preferences`, keyed by content type.
   - Keep every trait at the strength the samples show. A profile that exaggerates traits produces parody.

   ```json
   {
     "voice_dna": {
       "version": "1.0",
       "last_updated": "YYYY-MM-DD",
       "core_essence": {
         "identity": "",
         "primary_role": "",
         "unique_angle": ""
       },
       "personality_traits": {
         "primary": [],
         "how_it_shows": {}
       },
       "emotional_palette": {
         "dominant_emotions": [],
         "emotional_range": {},
         "energy_level": ""
       },
       "communication_style": {
         "formality": "",
         "complexity": "",
         "sentence_structure": {},
         "paragraph_style": ""
       },
       "language_patterns": {
         "signature_phrases": [],
         "power_words": [],
         "words_to_avoid": [],
         "transitions": []
       },
       "never_say": {
         "phrases": [],
         "tones": [],
         "approaches": []
       },
       "formatting_preferences": {},
       "content_philosophy": {},
       "voice_examples": {
         "opening_lines": [],
         "closing_lines": [],
         "transitional_phrases": []
       }
     }
   }
   ```

5. Show the user a summary of the key findings from step 3.
6. Save the profile to the profile path that matches whose voice it is.
   - The write fails: show the full JSON in the response and tell the user the save failed.
7. Write one short paragraph on a topic unrelated to the samples, using only the profile as guidance. Show it to the user.
8. Ask the user: "Does this sound like you? What would you adjust?"
   - The user requests changes: update the profile, save it again, and repeat steps 7 and 8.
   - The user confirms: stop.
