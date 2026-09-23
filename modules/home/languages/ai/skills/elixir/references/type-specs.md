# Elixir Typespecs

Apply these rules to every @spec, @type, and @callback you write or review.

1. Write the most specific type that is true.
   - Replace `any()` and `term()` with the concrete types the function accepts and returns.
   - Replace `list()` with `[User.t()]` or `nonempty_list(String.t())`.
   - Replace `map()` with a struct type or a map with named keys.
   - List error reasons as atoms: `{:error, :not_found | :db_error | :unauthorized}`, not `{:error, term()}`.
   - Write one spec per argument shape when the output type depends on the input type:

     ```elixir
     @spec transform(User.t()) :: UserDTO.t()
     @spec transform(Post.t()) :: PostDTO.t()
     ```

2. Name arguments when two or more share a type: `@spec days_since_epoch(year :: integer(), month :: integer(), day :: integer()) :: integer()`.

3. Define a named type for any shape used in two or more specs. Add `@typedoc` to each public type.
   - Use `@typep` for types private to the module.
   - Use `@opaque` when callers pass the value around but never read its fields.
   - Use a parameterized type for reusable shapes: `@type result(ok, err) :: {:ok, ok} | {:error, err}`.

4. Spell out option keys.
   - Keyword options: `@type option :: {:name, String.t()} | {:max, pos_integer()}`, then `@type options :: [option()]`.
   - Maps: use `required(:key) => type` and `optional(:key) => type`.

5. Pick the right primitive.
   - Elixir strings are `String.t()`. `string()` is an Erlang charlist; write `charlist()` if you mean that.
   - Use `no_return()` only for functions that never return, such as an infinite receive loop or one that always raises. A function that returns `:ok` after a side effect gets `:: :ok`.
   - Use `pos_integer()`, `non_neg_integer()`, and `timeout()` when they describe the value.

6. For a behaviour, declare each callback with `@callback` and list optional ones in `@optional_callbacks`. In each implementation, mark callbacks with `@impl ModuleName`.

7. Specs describe what succeeds, because Dialyzer uses success typing. Write the inputs and outputs of the success path, plus the error tuples the function actually returns.

8. When the project has no Dialyzer setup and the task asks for one, add `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}` to deps and this to `project/0` in mix.exs:

   ```elixir
   dialyzer: [
     plt_add_apps: [:mix, :ex_unit],
     plt_core_path: "priv/plts",
     plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
   ]
   ```
