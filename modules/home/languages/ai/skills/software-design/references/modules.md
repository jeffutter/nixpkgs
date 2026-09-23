# Modules and Decomposition

## Deep modules

Give each module a simple interface over a substantial implementation. A module whose interface is nearly as complex as its implementation is shallow; merge or redesign it.

```
Deep:
  read(file, buffer, count)  // hides buffering, caching, disk blocks, error recovery

Shallow:
  file_stream = open_file(path)
  buffered = add_buffering(file_stream)
  object_stream = add_serialization(buffered)
  // caller assembles the abstraction
```

- Depth test: a caller must understand the implementation to use the interface correctly. The module is too shallow.
- False-layer test: changing one layer forces a change in another. Merge the layers or redesign the boundary.

## Information hiding

Make each module own its design decisions:

- Data structure choices
- Algorithms and their parameters
- File and wire formats
- Policies, such as retry logic and caching strategies
- Platform-specific details

When the same knowledge appears in two modules, move it into one module.

```
Leaky:
  // Module A knows the file format
  write_header(file, VERSION_2, CHECKSUM_CRC32)
  // Module B also knows the file format
  if header.version == VERSION_2 and header.checksum_type == CHECKSUM_CRC32: ...

Hidden:
  file_handler.write(data)  // format is internal
  file_handler.read()
```

## Complete functions

Give each responsibility one function that does it completely. Merge functions that callers must invoke in sequence or that share implicit state.

```
Fragmented:
  fuse = get_fuse(service)
  check_fuse_state(fuse)
  result = call_if_fuse_ok(fuse, request)
  update_cache_from_result(result)
  maybe_blow_fuse(fuse, result)

Complete:
  result = fetch_with_circuit_breaker(service, request)
  // fuse logic, caching, and retry are internal
```

Keep a long function whole when all three hold:

- Its interface is simple.
- Its blocks read in sequence without depending on each other.
- Splitting it would create functions that cannot be understood alone.

## Different layer, different abstraction

Give each layer an abstraction different from the layer below it. Two layers with the same abstraction mean one is unnecessary.

Remove pass-through methods. Expose the inner object directly, or give the outer class a different abstraction.

```
Pass-through:
  class Document:
    def get_cursor_offset(self):
      return self.text_area.get_cursor_offset()
```

Before you create a decorator or wrapper, check each option in order and take the first that works:

1. Put the functionality directly in the base class.
2. Merge it into an existing decorator.
3. Make it independent instead of wrapping.
