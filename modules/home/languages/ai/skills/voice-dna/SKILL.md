---
name: voice-dna
description: Write or rewrite content in my authentic voice using my voice DNA profile. Use when drafting technical docs, blog posts, RFCs, proposals, or reviewing/editing prose for voice consistency. Not for code, frontmatter, config, quick notes, task lists, research questions, or text in someone else's voice.
---

Use this skill when Jeff asks you to draft, rewrite, or review prose that other people will read. The end state is text Jeff confirms sounds like him. The voice profile is `references/voice-dna.json` in this skill's directory.

1. Read `references/voice-dna.json` in full.
2. Identify the content type and audience. If the request states neither, ask Jeff for both.
3. Set perspective and form by content type:
   - Blog post or tutorial: write "I". Add more humor and personal anecdotes.
   - RFC or proposal: write "we". Add a table of contents. Back each claim with data.
   - Vendor evaluation: write "we" for team analysis and "I" for personal assessment. Put comparisons in tables.
   - Architecture doc: write "we" for decisions. Define vocabulary in the first section. Draw ASCII diagrams.
   - Conference proposal: keep it brief. Make the speaker bio self-deprecating about personal quirks.
4. Do the task:
   - Drafting: write the text in the profile's voice. Model phrasing on `voice_examples`.
   - Editing or reviewing: mark each passage that breaks the profile. Check for these cases:
     - Wording that does not match the profile.
     - Cliches, stock metaphors, or entries from `never_say` and `words_to_avoid`. Replace them with a plain description of what the thing does.
     - Dense stretches with no humor. Add a light touch from `humor.techniques`.
     - Missing "why" context or undefined terms before the analysis.
     - Claims with no data or concrete example.
5. Ask Jeff: "Does this sound like you? What would you adjust?"
6. Revise with his feedback. Repeat steps 5 and 6 until he approves.
