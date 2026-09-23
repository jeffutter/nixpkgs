---
name: elixir
description: Guidelines and best practices when writing Elixir code. Claude should use this skill whenever asked to modify, evaluate or review Elixir files (.ex or .exs).
---

Use this skill when you write, modify, or review a .ex or .exs file. The end state is code that follows every rule in step 2.

1. Read the reference file that matches the task before you write code.
   - Adding or reviewing @spec, @type, @callback, or Dialyzer config: read references/type-specs.md.
   - Writing Absinthe resolvers or Dataloader sources: read references/dataloader.md.
   - Neither applies: go to step 2.

2. Apply each rule below to every function you write or review. In a review, report each violation with the rule it breaks.

   - Read keys with bracket access, `opts[:key]`, instead of `Map.get/2` or `Keyword.get/2`.

   - Handle a `{:ok, _} | {:error, _}` result with `with` or `case` in the caller. Pipe only functions that cannot fail. Write this:

     ```elixir
     with {:ok, response} <- call_service(data),
          {:ok, decoded} <- Jason.decode(response) do
       decoded
     end
     ```

     Instead of piping into helpers that pattern match `{:error, _}` and pass it through.

   - When an error drives control flow (circuit breaker, fallback, cache), write a nested `case` in the calling function so every path is visible.

   - Assign the value to a variable, then `case` on it. Never write `|> case do`.

   - Write a `with ... else` only when every error gets the same handling. When errors need different handling, write nested `case`. Never tag steps like `{:service, call_service(data)}` to tell errors apart in `else`.

   - To unify errors across an app, wrap external errors in one exception struct:

     ```elixir
     defmodule MyApp.Error do
       defexception [:code, :msg, :meta]

       def not_found(msg, meta \\ %{}), do: %__MODULE__{code: :not_found, msg: msg, meta: meta}
       def internal(msg, meta \\ %{}), do: %__MODULE__{code: :internal, msg: msg, meta: meta}
     end
     ```

   - Write functions that act on one item. Call `Enum` or `Stream` at the call site: `Enum.map(collection, &parse_item/1)`, not `parse_items(collection)`.

   - Write guards that name the required type, such as `when is_binary(req)`, instead of `when not is_nil(req)`.

   - Return an error tuple only when the caller can act on it. Otherwise let the function raise.
     - Remove `try/catch` that converts a crash into `{:error, _}`.
     - Use bang functions like `Jason.decode!/1` on data from a service that always returns that format.

   - In tests, assert per element with a comprehension: `for post <- posts, do: assert %Post{} = post`. Replace `assert Enum.all?(...)`.
