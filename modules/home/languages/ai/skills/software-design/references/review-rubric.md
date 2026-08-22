# Design Review Rubric

Use this to judge an existing design, or your own change before proposing it.

## Red Flags

Watch for these symptoms:

| Red Flag | What It Suggests |
|----------|------------------|
| Shallow module | Interface nearly as complex as implementation |
| Information leakage | Same knowledge in multiple places |
| Pass-through method | Layer adds no abstraction |
| Conjoined functions | Can't understand one without the other |
| Hard to name | Unclear purpose or mixed responsibilities |
| Hard to describe | Interface isn't clean |
| Repetition | Missing abstraction |
| Many special cases | Normal case isn't general enough |

## Strategic vs Tactical

**Tactical:** "What's the smallest change to make this work?"

**Strategic:** "What design would I have built if I'd known about this
requirement from the start?"

Tactical programming accumulates complexity. Strategic programming invests
~10-20% extra time in design to pay dividends forever.

When modifying existing code:

1. Don't just patch — consider whether the current design is still appropriate
2. If not, refactor toward the design you'd build from scratch
3. Leave the code cleaner than you found it

## Applying the rubric

For each red flag you find, state the symptom, the design decision that caused
it, and what the strategic version would look like. Don't report a red flag you
can't tie to a concrete cost — the rubric is a lens, not a checklist to satisfy.
