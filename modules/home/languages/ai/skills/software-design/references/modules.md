# Modules and Decomposition

## Deep Modules

**Modules should hide complexity, not just organize code.**

A deep module has a simple interface but significant implementation behind it. A
shallow module has an interface nearly as complex as its implementation — it
provides little leverage against complexity.

```
Good:
  read(file, buffer, count)  // hides buffering, caching, disk blocks, error recovery

Bad:
  file_stream = open_file(path)
  buffered = add_buffering(file_stream)
  object_stream = add_serialization(buffered)
  // caller assembles the abstraction themselves
```

**Test for depth:** If understanding the implementation is necessary to use the
interface correctly, the module is too shallow.

**Test for false layers:** If changing one layer requires changing another, they
aren't truly separate — merge them or redesign the boundary.

## Information Hiding

**Each module should encapsulate design decisions.**

Hidden information typically includes:

- Data structure choices
- Algorithms and their parameters
- File/wire formats
- Policies (retry logic, caching strategies)
- Platform-specific details

**Information leakage is a critical red flag.** If the same knowledge appears in
multiple modules, you have a dependency that will cause pain during changes.

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

Don't fragment a single responsibility across multiple functions that must be
called in sequence or that share implicit state. A longer function that handles
its full responsibility is better than several short functions that leak
implementation details to each other.

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
- Breaking them up would create conjoined functions that can't be understood
  independently

## Different Layer, Different Abstraction

**If two layers have the same abstraction, one is probably unnecessary.**

Pass-through methods are a red flag — they add interface complexity without
adding functionality:

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
