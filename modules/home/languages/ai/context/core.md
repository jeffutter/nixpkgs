# Design bias

Deep modules: hide complexity, don't just organize it. Prefer one complete
function over several fragmented ones that share implicit state — longer is
fine. Pull complexity into the implementation, not the interface; a
configuration parameter is usually a decision I didn't make. Comments explain
what the code cannot.

For anything deeper — designing a module or interface, structural review,
deciding how far to refactor — use the `software-design` skill.

# Working with me

- When you're unsure and the answer is cheap to check, run a small local
  experiment and bring me the hypothesis and the result rather than guessing.
- If we're close to settled practice or an existing library solves this, say so
  before building something bespoke.
