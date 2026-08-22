---
name: software-design
description: Jeff's software design principles, derived from Ousterhout's A Philosophy of Software Design. Use when designing a new module or interface, deciding how to decompose work into functions or files, reviewing code for structure rather than bugs, judging whether an abstraction is worth its cost, or when a change feels like it's fighting the existing design. Also use as a rubric when asked to review design quality.
---

# Software Design

Principles for structuring code. These are heuristics, not laws — apply them
with judgement, and prefer the surrounding codebase's conventions when they
conflict.

## Core premises

**Software design is fundamentally about managing complexity.**

Total complexity = Σ(essential complexity × interaction points)

Essential complexity is unavoidable — it's what makes an HTTP client an HTTP
client. The job is to minimize interaction points through encapsulation, not to
eliminate the essential work.

**All code has cost.** Every line, every abstraction, every module adds
cognitive load. The value of any code must significantly exceed its cost. If you
can't articulate what value a piece of code provides beyond "organization,"
question whether it should exist.

```
value >> cost   → keep it
value ≈ cost    → simplify or remove
value < cost    → remove it
```

## Summary heuristics

1. **Ask "value > cost?" for every abstraction.** If you can't articulate the
   value, remove the abstraction.
2. **Encapsulate complexity; don't just organize it.** A module that requires
   reading its implementation has failed.
3. **Complete functions over fragmented ones.** It's fine if they're longer.
4. **General interfaces, specialized callers.** Push application-specific
   behavior outward.
5. **Define errors out of existence** when possible; handle the rest in few
   places.
6. **Comments explain what code cannot.** Write them first.
7. **Consistency beats local optimality.** Follow existing patterns.
8. **Invest in design continuously.** Every change is an opportunity to improve
   structure.

## Going deeper

Read the reference that matches what you're doing — don't load all of them.

- `references/modules.md` — module depth, information hiding, complete
  functions, and when a layer is a false layer. Read when deciding how to split
  code up.
- `references/interfaces.md` — general-purpose interfaces, pulling complexity
  downward, and defining errors out of existence. Read when designing a
  signature or API surface.
- `references/comments-and-naming.md` — what comments should add, precise
  naming, consistency. Read when writing the code itself.
- `references/review-rubric.md` — red-flag table and the strategic-vs-tactical
  test. Use when reviewing a design or deciding how far to refactor.
