# Comments, Naming, and Consistency

## Comments

Write a comment only for what the code does not show. Each comment goes in one of two directions:

- Precision (lower level): units, boundary conditions, what null means, invariants.
- Intuition (higher level): why this approach, what the code is for, how the pieces fit.

```
Useless (repeats code):
  count = count + 1  // increment count

Precision:
  // Timeout in milliseconds; 0 means no timeout
  timeout = 5000

Intuition:
  // Try to append to an existing RPC to the same server that hasn't been sent yet
  for rpc in pending_rpcs: ...
```

- Interface comments: state what the function or class does, its parameters, return values, side effects, and preconditions. A caller needs nothing else to use it.
- Implementation comments: state what a block accomplishes and why a tricky decision was made. Leave out how the block works.

Write the interface comment before the code. If you cannot describe the function simply, redesign it before you write it.

## Naming

Choose the name that tells the reader most about the entity's purpose.

```
Vague: data, result, value, info, temp, x
Better: connection_pool, retry_count, user_permissions, cursor_position
```

- Use one name for one concept across the codebase. Give different concepts different names.
- Qualify a name that has two readings: `block` becomes `disk_block` or `file_block`.

## Consistency

Make similar things look similar and different things look different. Apply this to:

- Naming conventions
- Parameter ordering
- Error handling patterns
- Code organization within modules

Follow the existing convention. Change it only when you have significant new information and you update every existing use in the same change.
