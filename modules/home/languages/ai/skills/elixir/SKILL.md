---
name: elixir
description: Guidelines and best practices when writing Elixir. Use this skill any time you are modifying Elixir files (.ex or .exs) or Reviewing/evaluating Elixir code.
---

# Elixir Expert

Expert guidance for writing idiomatic, type-safe Elixir code.

## Topics

This skill covers multiple areas of Elixir expertise. Reference the appropriate guide based on the task:

### Best Practices
See [best-practices.md](references/best-practices.md) for:
- Data access patterns (Access behaviour vs Map.get)
- Error handling and control flow (with, case, error tuples)
- Higher-order functions and composition
- Guards and function expectations
- Testing patterns

Use this when writing or reviewing general Elixir code, handling errors, or working with collections.

### Typespecs
See [typespecs.md](references/typespecs.md) for:
- Writing effective type specifications
- Being specific with types (avoiding `any()`)
- User-defined types and parameterized types
- Behaviours and callbacks
- Dialyzer integration
- Common typespec patterns and pitfalls

Use this when adding type annotations, defining behaviours, preparing code for Dialyzer analysis, or documenting function contracts.

### Absinthe Dataloader
See [dataloader.md](references/dataloader.md) for:
- Solving N+1 query problems in GraphQL
- Setting up Dataloader with Absinthe
- Basic and advanced usage patterns
- Custom batch functions and query customization
- Authorization and context patterns
- KV source for non-Ecto data
- Common gotchas and testing strategies

Use this when building GraphQL APIs with Absinthe, optimizing resolver performance, implementing authorization rules, or working with nested GraphQL queries.

## Quick Reference

Common patterns to apply immediately:

**Data Access:**
```elixir
# Use bracket syntax for flexibility
opts[:key]  # instead of Map.get(opts, :key)
```

**Error Handling:**
```elixir
# Use with for sequential operations
with {:ok, data} <- fetch(),
     {:ok, result} <- process(data) do
  result
end

# Use case for critical error handling
case call_service(id) do
  {:ok, result} -> result
  {:error, error} -> handle_error(error)
end
```

**Type Specifications:**
```elixir
# Be specific, avoid any()
@spec process(String.t(), keyword()) :: {:ok, result()} | {:error, atom()}

# Document custom types
@typedoc "User configuration options"
@type options :: [timeout: pos_integer(), retry: boolean()]
```

# Elixir Best Practices

Core patterns for idiomatic Elixir code.

## Data Access

Use bracket access syntax instead of `Map.get/2` or `Keyword.get/2`:

```elixir
# Avoid - locks you into specific data structure
opts = %{foo: :bar}
Map.get(opts, :foo)

# Prefer - works with maps, keywords, and Access behaviour
opts[:foo]
```

## Error Handling and Control Flow

### Never pipe side-effecting function results

Side-effecting functions return `{:ok, term()} | {:error, term()}`. Use `with` or `case` to handle results explicitly:

```elixir
# Avoid - spreads error handling across functions
def main do
  data
  |> call_service()
  |> parse_response()
  |> handle_result()
end

defp parse_response({:ok, result}), do: Jason.decode(result)
defp parse_response(error), do: error

# Prefer - caller controls error handling
def main do
  with {:ok, response} <- call_service(data),
       {:ok, decoded} <- Jason.decode(response) do
    decoded
  end
end
```

**Rationale:** Each function shouldn't need to know how it's called or what order it's composed in. The caller has enough context to decide error handling strategy.

### Keep critical error handling in the calling function

When errors are vital to control flow (circuit breakers, fallbacks, caching), use explicit `case` statements:

```elixir
def main(id) do
  case :fuse.check(:service) do
    :ok ->
      case call_service(id) do
        {:ok, result} ->
          :ok = Cache.put(id, result)
          {:ok, result}

        {:error, error} ->
          :fuse.melt(:service)
          {:error, error}
      end

    :blown ->
      case Cache.get(id) do
        nil -> {:error, :service_unavailable}
        cached -> {:ok, cached}
      end
  end
end
```

This increases function size but makes every control path explicit and readable.

### Don't pipe into case statements

Assign intermediate values to variables instead:

```elixir
# Avoid
build_post(attrs)
|> store_post()
|> case do
  {:ok, post} -> # ...
  {:error, _} -> # ...
end

# Prefer
changeset = build_post(attrs)

case store_post(changeset) do
  {:ok, post} -> # ...
  {:error, _} -> # ...
end
```

### Avoid else in with blocks

Use `else` only for truly generic error handling. If you need to handle specific errors differently, use `case` instead:

```elixir
# Avoid - tagging just to differentiate errors
with {:service, {:ok, resp}} <- {:service, call_service(data)},
     {:decode, {:ok, decoded}} <- {:decode, Jason.decode(resp)} do
  :ok
else
  {:service, {:error, error}} -> # ...
  {:decode, {:error, error}} -> # ...
end

# Prefer - use case when errors matter
case call_service(data) do
  {:ok, resp} ->
    case Jason.decode(resp) do
      {:ok, decoded} -> decoded
      {:error, error} -> # handle decode error
    end

  {:error, error} -> # handle service error
end
```

**Alternative:** Create a unified error type for consistent error handling across your app:

```elixir
defmodule MyApp.Error do
  defexception [:code, :msg, :meta]

  def not_found(msg, meta \\ %{}), do: %__MODULE__{code: :not_found, msg: msg, meta: meta}
  def internal(msg, meta \\ %{}), do: %__MODULE__{code: :internal, msg: msg, meta: meta}
end

# Wrap external errors in your unified type
defp decode(resp) do
  case Jason.decode(resp) do
    {:ok, decoded} -> {:ok, decoded}
    {:error, _} -> {:error, Error.internal("could not decode: #{inspect(resp)}")}
  end
end
```

## Higher-Order Functions

Expose single-item operations and use `Enum`/`Stream` at call sites:

```elixir
# Avoid - hides higher-order functions
def main do
  collection
  |> parse_items()
  |> add_items()
end

def parse_items(list), do: Enum.map(list, &String.to_integer/1)
def add_items(list), do: Enum.reduce(list, 0, & &1 + &2)

# Prefer - makes functions reusable
def main do
  collection
  |> Enum.map(&parse_item/1)
  |> Enum.sum()
end

defp parse_item(item), do: String.to_integer(item)
```

**Benefits:** Functions become reusable with `Enum`, `Stream`, `Task`. Better solutions often emerge (like using `Enum.sum/1` instead of manual reduce).

## Guards and Expectations

### State what you want, not what you don't

```elixir
# Avoid
def call_service(%{req: req}) when not is_nil(req) do
  # ...
end

# Prefer - be explicit about requirements
def call_service(%{req: req}) when is_binary(req) do
  # ...
end
```

### Only return error tuples when caller can act on them

If the caller can't do anything about an error, raise or throw instead:

```elixir
# Avoid - forces caller to handle unrecoverable errors
def get(table \\ __MODULE__, id) do
  try do
    :ets.lookup(table, id)
  catch
    _, _ -> {:error, "Table is not available"}
  end
end

# Prefer - let it fail if table doesn't exist
def get(table \\ __MODULE__, id) do
  :ets.lookup(table, id)
end
```

### Raise on invalid data from external sources

Use bang functions (`!`) when downstream services should always return expected formats:

```elixir
# Avoid - unnecessary error handling for impossible cases
def main do
  {:ok, resp} = call_service(id)
  case Jason.decode(resp) do
    {:ok, decoded} -> decoded
    {:error, e} -> # What can we even do here?
  end
end

# Prefer - let it crash and restart
def main do
  {:ok, resp} = call_service(id)
  Jason.decode!(resp)
end
```

## Testing

Use `for` comprehensions in assertions to get better failure messages:

```elixir
# Avoid - generic failure message
assert Enum.all?(posts, fn post -> %Post{} = post end)

# Prefer - shows which specific post failed
for post <- posts, do: assert %Post{} = post
```
