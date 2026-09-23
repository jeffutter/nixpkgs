# Interfaces

## General-purpose interfaces

Design interfaces around fundamental operations, not specific use cases. Somewhat general modules are deeper than specialized ones.

```
Specialized:
  backspace()           // deletes char before cursor
  delete_key()          // deletes char after cursor
  delete_selection()    // deletes highlighted text

General:
  delete(start, end)    // each call above becomes a trivial caller
```

Answer these for each interface:

- What is the simplest interface that covers every current need?
- How many situations will call this method? One situation means it is too specialized.
- Can you drop methods without adding complex parameters?

Keep core infrastructure general. Put application-specific behavior in the outer layers that call it.

## Pull complexity downward

Absorb unavoidable complexity in the implementation instead of the interface. A module has more users than implementers.

```
Pushed up:
  config = RetryConfig(attempts=3, backoff=exponential(base=2))
  result = fetch(url, timeout=30, retry_config=config, on_error=log_and_continue)

Pulled down:
  result = fetch(url)  // defaults are internal; rare overrides get separate methods
```

Before you expose a configuration parameter, ask whether callers know a better value than the module can compute. When they do not, compute it inside the module.

## Define errors out of existence

Reduce the number of places that handle exceptions:

- Redefine operations so edge cases become normal cases. Example: `unset(variable)` succeeds when the variable is already absent. Example: `substring(start, end)` clips to bounds and returns an empty string when there is no overlap.
- Mask an exception at a low level when higher levels cannot act on it.
- Catch many exceptions in one place instead of wrapping every call.
- Let the system crash on unrecoverable errors, such as out of memory or corrupted state.
