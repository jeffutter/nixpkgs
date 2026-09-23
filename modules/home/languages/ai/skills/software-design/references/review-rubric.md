# Design Review Rubric

Use this rubric to judge an existing design, or your own change before you propose it.

1. Scan the code for these red flags. Each symptom points to a cause:
   - Shallow module: the interface is nearly as complex as the implementation.
   - Information leakage: the same knowledge lives in more than one module.
   - Pass-through method: the layer adds no abstraction.
   - Conjoined functions: one cannot be understood without the other.
   - Hard to name: the purpose is unclear or responsibilities are mixed.
   - Hard to describe: the interface is not clean.
   - Repetition: an abstraction is missing.
   - Many special cases: the normal case is not general enough.
2. Drop each red flag you cannot tie to a concrete cost.
3. For each remaining red flag, state the symptom, the design decision that caused it, and the strategic version.
4. Find the strategic version by asking what design you would build had you known this requirement from the start. The tactical question, what is the smallest change that works, accumulates complexity.
5. When you modify existing code:
   - The current design still fits: make the change and leave the code cleaner than you found it.
   - The current design no longer fits: refactor toward the design you would build from scratch. Budget about 10-20% extra time for it.
