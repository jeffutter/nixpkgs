# Software Design Philosophy

These principles guide how to write and structure code. Apply them thoughtfully—they are heuristics, not laws.

## Core Premises

**Premise 1: Software design is fundamentally about managing complexity.**

Total complexity = Σ(essential complexity × interaction points)

Essential complexity is unavoidable—it's what makes an HTTP client an HTTP client. Your job is to minimize interaction points through encapsulation, not to eliminate the essential work.

**Premise 2: All code has cost.**

Every line, every abstraction, every module adds cognitive load. The value of any code must significantly exceed its cost. If you can't articulate what value a piece of code provides beyond "organization," question whether it should exist.

```
value >> cost   → keep it
value ≈ cost    → simplify or remove
value < cost    → remove it
```

## Deep Modules

**Modules should hide complexity, not just organize code.**

A deep module has a simple interface but significant implementation behind it. A shallow module has an interface nearly as complex as its implementation—it provides little leverage against complexity.

```
Good:
  read(file, buffer, count)  // hides buffering, caching, disk blocks, error recovery

Bad:
  file_stream = open_file(path)
  buffered = add_buffering(file_stream)
  object_stream = add_serialization(buffered)
  // caller assembles the abstraction themselves
```

**Test for depth:** If understanding the implementation is necessary to use the interface correctly, the module is too shallow.

**Test for false layers:** If changing one layer requires changing another, they aren't truly separate—merge them or redesign the boundary.

## Information Hiding

**Each module should encapsulate design decisions.**

Hidden information typically includes:
- Data structure choices
- Algorithms and their parameters
- File/wire formats
- Policies (retry logic, caching strategies)
- Platform-specific details

**Information leakage is a critical red flag.** If the same knowledge appears in multiple modules, you have a dependency that will cause pain during changes.

```
Leaky:
  // Module A knows file format
  write_header(file, VERSION_2, CHECKSUM_CRC32)

  // Module B also knows file format
  if header.version == VERSION_2 and header.checksum_type == CHECKSUM_CRC32:
    ...

Better:
  // Single module owns format knowledge
  file_handler.write(data)  // format is internal
  file_handler.read()       // format is internal
```

## Complete Functions

**Each function should do one thing completely.**

Don't fragment a single responsibility across multiple functions that must be called in sequence or that share implicit state. A longer function that handles its full responsibility is better than several short functions that leak implementation details to each other.

```
Fragmented (bad):
  fuse = get_fuse(service)
  check_fuse_state(fuse)
  result = call_if_fuse_ok(fuse, request)
  update_cache_from_result(result)
  maybe_blow_fuse(fuse, result)

Complete (better):
  result = fetch_with_circuit_breaker(service, request)
  // All fuse logic, caching, and retry is internal
```

**Long functions are acceptable when:**
- They have a simple interface
- Their blocks are relatively independent (can be read sequentially)
- Breaking them up would create conjoined functions that can't be understood independently

## Different Layer, Different Abstraction

**If two layers have the same abstraction, one is probably unnecessary.**

Pass-through methods are a red flag—they add interface complexity without adding functionality:

```
Bad (pass-through):
  class Document:
    def get_cursor_offset(self):
      return self.text_area.get_cursor_offset()  // adds nothing

Better:
  // Expose text_area directly, or give Document a genuinely different abstraction
```

**Decorators and wrappers should be used sparingly.** Before creating one, ask:
- Can this functionality go directly in the base class?
- Can it merge with an existing decorator?
- Does it actually need to wrap, or can it be independent?

## Define Errors Out of Existence

**Reduce the number of places where exceptions must be handled.**

The best error handling is making errors impossible or irrelevant:

```
Error-prone:
  unset(variable)  // throws if variable doesn't exist

Error-free:
  ensure_absent(variable)  // succeeds whether or not variable exists
```

```
Error-prone:
  substring(start, end)  // throws if indices out of bounds

Error-free:
  substring(start, end)  // returns empty string if no overlap, clips to bounds
```

**Techniques:**
- Redefine operations so edge cases are normal cases
- Mask exceptions at low levels when higher levels can't do anything useful
- Aggregate exception handling—catch many exceptions in one place rather than wrapping every call
- Let the system crash for truly unrecoverable errors (out of memory, corrupted state)

## General-Purpose Interfaces

**Somewhat general-purpose modules are deeper than specialized ones.**

Design interfaces around fundamental operations, not specific use cases:

```
Too specialized:
  backspace()           // deletes char before cursor
  delete_key()          // deletes char after cursor
  delete_selection()    // deletes highlighted text

General-purpose:
  delete(start, end)    // deletes range; all above are trivial callers
```

**Questions to ask:**
- What's the simplest interface covering all current needs?
- How many situations will this method be used in? (If one, it's too specialized)
- Can I reduce the number of methods without adding complex parameters?

**Push specialization to the edges.** Core infrastructure should be general; application-specific behavior belongs in the outer layers that call into it.

## Pull Complexity Downward

**It's better for a module's implementer to suffer than its users.**

When you encounter unavoidable complexity, absorb it in the implementation rather than exposing it in the interface. Users of your module are more numerous than you.

```
Pushing complexity up (bad):
  // Caller must understand retry policy, timeout configuration, error types
  config = RetryConfig(attempts=3, backoff=exponential(base=2))
  result = fetch(url, timeout=30, retry_config=config, on_error=log_and_continue)

Pulling complexity down (better):
  result = fetch(url)  // sensible defaults internal; rare overrides via separate methods
```

**Configuration parameters are often a failure to make decisions.** Before exposing a parameter, ask: "Will users actually know better than I can compute automatically?"

## Writing Comments

**Comments describe what isn't obvious from the code.**

There are two valid directions:
1. **Lower-level (precision):** Units, boundary conditions, null meanings, invariants
2. **Higher-level (intuition):** Why this approach, what the code is trying to accomplish, how pieces fit together

```
Useless (repeats code):
  count = count + 1  // increment count

Useful (adds precision):
  // Timeout in milliseconds; 0 means no timeout
  timeout = 5000

Useful (adds intuition):
  // Try to append to an existing RPC to the same server that hasn't been sent yet
  for rpc in pending_rpcs:
    ...
```

**Interface comments** describe what a function/class does, its parameters, return values, side effects, and preconditions—everything needed to use it without reading the implementation.

**Implementation comments** describe *what* blocks of code accomplish (not *how*), and *why* tricky decisions were made.

**Write comments before code.** If you can't describe what a function does simply, the design isn't clean yet.

## Naming

**Names create mental images.** Choose words that convey the most information about the entity's purpose:

```
Vague: data, result, value, info, temp, x
Better: connection_pool, retry_count, user_permissions, cursor_position
```

**Be consistent.** Use the same name for the same concept everywhere. Never use the same name for different concepts.

**Be precise.** If `block` could mean "disk block" or "file block," use `disk_block` and `file_block`.

## Consistency

**Similar things should look similar. Different things should look different.**

Consistency creates cognitive leverage—once you learn a pattern, you can apply that knowledge everywhere it appears.

This applies to:
- Naming conventions
- Parameter ordering
- Error handling patterns
- Code organization within modules

**Don't change existing conventions** unless you have significant new information *and* you're willing to update all existing uses. A "better" approach isn't worth the inconsistency.

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
**Strategic:** "What design would I have built if I'd known about this requirement from the start?"

Tactical programming accumulates complexity. Strategic programming invests ~10-20% extra time in design to pay dividends forever.

When modifying existing code:
1. Don't just patch—consider whether the current design is still appropriate
2. If not, refactor toward the design you'd build from scratch
3. Leave the code cleaner than you found it

## Summary Heuristics

1. **Ask "value > cost?" for every abstraction.** If you can't articulate the value, remove the abstraction.
2. **Encapsulate complexity; don't just organize it.** A module that requires reading its implementation has failed.
3. **Complete functions over fragmented ones.** It's fine if they're longer.
4. **General interfaces, specialized callers.** Push application-specific behavior outward.
5. **Define errors out of existence** when possible; handle the rest in few places.
6. **Comments explain what code cannot.** Write them first.
7. **Consistency beats local optimality.** Follow existing patterns.
8. **Invest in design continuously.** Every change is an opportunity to improve structure.
