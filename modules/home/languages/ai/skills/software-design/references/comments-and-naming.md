# Comments, Naming, and Consistency

## Writing Comments

**Comments describe what isn't obvious from the code.**

There are two valid directions:

1. **Lower-level (precision):** Units, boundary conditions, null meanings,
   invariants
2. **Higher-level (intuition):** Why this approach, what the code is trying to
   accomplish, how pieces fit together

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

**Interface comments** describe what a function/class does, its parameters,
return values, side effects, and preconditions — everything needed to use it
without reading the implementation.

**Implementation comments** describe *what* blocks of code accomplish (not
*how*), and *why* tricky decisions were made.

**Write comments before code.** If you can't describe what a function does
simply, the design isn't clean yet.

## Naming

**Names create mental images.** Choose words that convey the most information
about the entity's purpose:

```
Vague: data, result, value, info, temp, x
Better: connection_pool, retry_count, user_permissions, cursor_position
```

**Be consistent.** Use the same name for the same concept everywhere. Never use
the same name for different concepts.

**Be precise.** If `block` could mean "disk block" or "file block," use
`disk_block` and `file_block`.

## Consistency

**Similar things should look similar. Different things should look different.**

Consistency creates cognitive leverage — once you learn a pattern, you can apply
that knowledge everywhere it appears.

This applies to:

- Naming conventions
- Parameter ordering
- Error handling patterns
- Code organization within modules

**Don't change existing conventions** unless you have significant new
information *and* you're willing to update all existing uses. A "better"
approach isn't worth the inconsistency.
