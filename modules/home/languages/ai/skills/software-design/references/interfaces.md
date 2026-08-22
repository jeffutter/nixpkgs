# Interfaces

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
- How many situations will this method be used in? (If one, it's too
  specialized)
- Can I reduce the number of methods without adding complex parameters?

**Push specialization to the edges.** Core infrastructure should be general;
application-specific behavior belongs in the outer layers that call into it.

## Pull Complexity Downward

**It's better for a module's implementer to suffer than its users.**

When you encounter unavoidable complexity, absorb it in the implementation
rather than exposing it in the interface. Users of your module are more numerous
than you.

```
Pushing complexity up (bad):
  // Caller must understand retry policy, timeout configuration, error types
  config = RetryConfig(attempts=3, backoff=exponential(base=2))
  result = fetch(url, timeout=30, retry_config=config, on_error=log_and_continue)

Pulling complexity down (better):
  result = fetch(url)  // sensible defaults internal; rare overrides via separate methods
```

**Configuration parameters are often a failure to make decisions.** Before
exposing a parameter, ask: "Will users actually know better than I can compute
automatically?"

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
- Aggregate exception handling — catch many exceptions in one place rather than
  wrapping every call
- Let the system crash for truly unrecoverable errors (out of memory, corrupted
  state)
