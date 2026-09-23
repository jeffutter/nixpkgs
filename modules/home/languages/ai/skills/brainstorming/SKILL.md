---
name: brainstorming
description: "Use before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements, and design before implementation."
---

# Brainstorming Ideas Into Designs

Use this skill before implementing a feature, component, or behavior change. The end state is a design the user approved, written to a file and committed. Write no implementation code during this skill.

1. Read the project state: README and docs, the files the idea touches, and `git log -n 10`.
2. Ask the user one question per message with the AskUserQuestion tool.
   - Offer multiple-choice answers when the options are enumerable. Otherwise ask an open question.
   - Split a topic that needs more detail into several questions.
   - Ask until you know the purpose, the constraints, and the success criteria.
3. Propose 2 or 3 approaches.
   - Put your recommended approach first, with the reason you recommend it.
   - State the trade-offs of each approach.
   - Ask the user to pick one.
4. Remove every feature from the chosen approach that the stated purpose and success criteria do not require.
5. Present the design in sections of 200 to 300 words.
   - Cover architecture, components, data flow, error handling, and testing.
   - After each section, ask whether it looks right so far.
   - The user objects or is confused: ask a clarifying question, revise the section, and present it again.
6. Write the approved design to `docs/plans/YYYY-MM-DD-<topic>-design.md` at the repository root. Use today's date and a short hyphenated topic.
   - The writing-clearly-and-concisely skill is available: invoke it before writing.
7. Commit the design file with git.
