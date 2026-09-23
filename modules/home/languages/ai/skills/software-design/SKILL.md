---
name: software-design
description: Jeff's software design principles, derived from Ousterhout's A Philosophy of Software Design. Use when designing a new module or interface, deciding how to decompose work into functions or files, reviewing code for structure rather than bugs, judging whether an abstraction is worth its cost, or when a change feels like it's fighting the existing design. Also use as a rubric when asked to review design quality.
---

# Software Design

Use this skill when you design, split, or review the structure of code. The end state is a design where each module hides its complexity behind a simple interface. When a rule here conflicts with the surrounding codebase's conventions, follow the codebase.

Complexity grows with the number of interaction points between modules. Reduce interaction points through encapsulation; keep the essential work.

1. Read the one reference that matches your task:
   - Splitting code into modules, functions, or layers: `references/modules.md`.
   - Designing a signature, API surface, or error behavior: `references/interfaces.md`.
   - Writing comments and choosing names: `references/comments-and-naming.md`.
   - Reviewing a design or deciding how far to refactor: `references/review-rubric.md`.
2. Apply these rules to each design decision:
   - Name the value each abstraction adds beyond organization. Value clearly above cost: keep it. Value near cost: simplify it. Value below cost, or no value you can name: remove it.
   - Hide complexity inside the module. A caller who must read the implementation to use it signals a failed module.
   - Write one complete function per responsibility, even when it grows long.
   - Make core interfaces general. Put application-specific behavior in the callers.
   - Redefine operations so errors cannot occur. Handle the remaining errors in few places.
   - Write comments for what the code cannot say. Write them before the code.
   - Follow existing patterns over a locally better one.
   - Improve the structure you touch in every change.
