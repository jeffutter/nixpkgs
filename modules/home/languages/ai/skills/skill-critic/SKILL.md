---
name: skill-critic
description: Critique and rewrite a Claude skill, slash command, agent definition, workflow prompt, or CLAUDE.md so it is short, literal, and executable by an agent that follows it word for word. Use when asked to critique, tighten, review, edit, or improve a skill or workflow file.
argument-hint: "skill name, directory, or path to SKILL.md"
---

Rewrite one skill file so an executing agent with no prior context can follow it sentence by sentence. Then report the cut.

1. Resolve the target.
   - A bare name maps to `~/.claude/skills/<name>/SKILL.md` or `.claude/skills/<name>/SKILL.md`.
   - A directory maps to its SKILL.md.
   - Both locations match, or no argument given: list the candidates and ask which one.
   - Work on that file and every file it references.
   - Keep frontmatter keys. Edit only their values.

2. Measure. Record the word count of each file with `wc -w`.

3. Cut. Delete every sentence that matches one of these:
   - History: why a rule exists, what went wrong before, who decided, when.
   - Audit trail: changelogs, freshness dates, version notes.
   - Citations, and links the executing agent never has to open.
   - Preamble, motivation, encouragement, praise, summaries of what follows.
   - A rule already stated elsewhere in the same file.
   - Content the executing agent already has from the harness, the system prompt, or CLAUDE.md.
   - An example that shows the same case as the instruction beside it.

   Keep a sentence only if deleting it changes what the executing agent does. Keep pitfalls. Delete the story behind them.

4. Restructure. Lay the file out in this order:
   - Frontmatter.
   - One paragraph stating the trigger and the end state.
   - Fixed values (IDs, URLs, paths, names) that two or more steps use.
   - A numbered list of steps in execution order. One action per step. A step that branches lists its cases as sub-bullets.
   - A fact used by one step sits inside that step.
   - Tables become plain text, headings, or lists. Bold, italics, and blockquotes become plain text.

5. Compress. Rewrite each paragraph as the fewest sentences that give the same instruction.
   - One instruction per sentence. Imperative mood. Present tense. Active voice.
   - Under 20 words per sentence.
   - One term per thing, used everywhere in the file. One meaning per term.
   - Replace a vague word with the concrete value it stands for: "recent" becomes "last 7 days".
   - Replace jargon, idiom, and shorthand with the plain action or the concrete artifact: "spin up" becomes "create".
   - Replace a paragraph that enumerates cases with a bullet list of cases.
   - Delete hedges: consider, try to, generally, where possible, as appropriate.
   - Delete intensifiers: always, critical, important, must, ensure. Leave never for step 6.

6. Turn negatives positive. For each sentence built on do not, never, avoid, or don't, write the action the executing agent takes instead: "Do not commit to main" becomes "Create a branch, then commit."
   - Keep a negative only when no positive action replaces it and a frontier model would act wrongly without it.
   - Write a kept negative as one sentence naming the exact trigger.

7. Dumb robot pass. Read the file top to bottom as the executing agent. Execute each sentence literally, in order, with the tools it names. At each sentence answer:
   - Which action, or constraint on an action, does this sentence produce? None: delete it.
   - Which value does it need that no earlier sentence supplied? Add the step that finds the value.
   - Can a literal reader take two readings? Rewrite until one remains.
   - What happens when the step returns nothing or fails? Add a one-sentence fallback if the file cannot finish without it.

   Repeat the pass until it makes no edits.

8. Deliver. Overwrite each file at its path with the Write tool. Report to the user as an ELI18 TLDR: short plain sentences, one point per bullet, under 200 words.
   - Word count before and after per file, and total percent cut.
   - Each ambiguity found in step 7 and the sentence that replaced it.
   - Each negative removed in step 6 that could regress behavior: the old sentence, the positive that replaced it, and the wrong action a model might now take.
   - Each step the file still cannot complete because it needs a value only the author knows.
