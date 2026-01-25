# Elixir Typespecs

Comprehensive guide to using typespecs effectively for documentation and Dialyzer analysis.

## Overview

Typespecs provide documentation and enable static analysis tools like Dialyzer to find type inconsistencies. They are never used by the compiler for optimization.

**Key attributes:**
- `@type` - Public type definition
- `@typep` - Private type definition
- `@opaque` - Public type with hidden internal structure
- `@spec` - Function specification
- `@callback` - Behaviour callback specification
- `@typedoc` - Documentation for custom types

## Core Principle: Be Specific

**Never use `any()` unless truly necessary.** Specific types enable better Dialyzer analysis and serve as documentation.

```elixir
# Avoid - too generic
@spec process(any()) :: any()

# Prefer - specific types
@spec process(String.t() | integer()) :: {:ok, result()} | {:error, atom()}
```

## Basic Type Usage

### Simple function specs

```elixir
@spec add(integer(), integer()) :: integer()
def add(x, y), do: x + y

@spec format_name(String.t()) :: String.t()
def format_name(name), do: String.upcase(name)
```

### Named arguments for clarity

Use named arguments to differentiate multiple parameters of the same type:

```elixir
@spec days_since_epoch(year :: integer(), month :: integer(), day :: integer()) :: integer()
def days_since_epoch(year, month, day) do
  # ...
end

@type color :: {red :: integer(), green :: integer(), blue :: integer()}
```

## User-Defined Types

### Basic type definitions

```elixir
@typedoc "A user ID from the database"
@type user_id :: pos_integer()

@typedoc "A word from the dictionary"
@type word :: String.t()

@spec long_word?(word()) :: boolean()
def long_word?(word) when is_binary(word) do
  String.length(word) > 8
end
```

### Parameterized types

```elixir
@type result(success, failure) :: {:ok, success} | {:error, failure}
@type dict(key, value) :: [{key, value}]

@spec fetch_user(user_id()) :: result(User.t(), :not_found | :db_error)
```

### Sum types (unions)

```elixir
@type status :: :pending | :active | :suspended | :deleted
@type payment_method :: :credit_card | :debit_card | :paypal | :bitcoin

@spec update_status(User.t(), status()) :: {:ok, User.t()} | {:error, term()}
```

## Common Patterns

### Result tuples

Be specific about error reasons:

```elixir
# Avoid - generic error
@spec fetch_post(integer()) :: {:ok, Post.t()} | {:error, term()}

# Prefer - specific error cases
@spec fetch_post(post_id :: integer()) ::
  {:ok, Post.t()} |
  {:error, :not_found | :db_error | :unauthorized}
```

### Keyword lists with specific keys

```elixir
# Define allowed options explicitly
@type option ::
  {:name, String.t()} |
  {:max, pos_integer()} |
  {:min, pos_integer()}

@type options :: [option()]

# Or use map notation for required/optional keys
@spec start_server(opts :: %{
  required(:port) => pos_integer(),
  required(:host) => String.t(),
  optional(:timeout) => timeout(),
  optional(:pool_size) => pos_integer()
}) :: {:ok, pid()} | {:error, term()}
```

### Maps with specific keys

```elixir
# Empty map
@type empty_map :: %{}

# Map with required atom key
@type user :: %{name: String.t(), age: integer()}

# Map with mixed required/optional keys
@type config :: %{
  required(:api_key) => String.t(),
  optional(:timeout) => pos_integer(),
  optional(:retry_count) => non_neg_integer()
}

# Struct types
@type user :: %User{
  id: user_id(),
  email: String.t(),
  status: status()
}
```

### Lists

```elixir
# List of specific type
@type user_list :: [User.t()]

# Non-empty list
@type nonempty_string_list :: [String.t(), ...]

# Keyword list with specific keys
@type db_options :: [
  host: String.t(),
  port: pos_integer(),
  username: String.t(),
  password: String.t()
]
```

## Advanced Patterns

### Guards in specs

Constrain type variables with guards:

```elixir
@spec serialize(data) :: binary() when data: term()
@spec identity(val) :: val when val: var

# Multiple constraints
@spec combine(left, right) :: {left, right}
  when left: atom(), right: integer()
```

### Overloaded specs

Define multiple specs for different argument patterns:

```elixir
@spec parse(String.t()) :: {:ok, term()} | {:error, atom()}
@spec parse(String.t(), keyword()) :: {:ok, term()} | {:error, atom()}

def parse(input, opts \\ []) do
  # ...
end
```

### Opaque types

Hide implementation details while keeping the type public:

```elixir
defmodule Cache do
  @opaque t :: %{data: map(), ttl: pos_integer()}

  @spec new(pos_integer()) :: t()
  def new(ttl), do: %{data: %{}, ttl: ttl}

  @spec put(t(), term(), term()) :: t()
  def put(cache, key, value) do
    %{cache | data: Map.put(cache.data, key, value)}
  end
end

# Callers can use Cache.t() but cannot access internals
```

### Recursive types

```elixir
@type json_value ::
  nil |
  boolean() |
  number() |
  String.t() |
  [json_value()] |
  %{optional(String.t()) => json_value()}

@type tree(value) ::
  {value, [tree(value)]} |
  {value, []}
```

## Built-in Types Reference

### Prefer specific types over generic ones

```elixir
# Instead of any()
integer() | float() | String.t() | atom()

# Instead of list()
[User.t()] | [Post.t()] | nonempty_list(String.t())

# Instead of map()
%{required(atom()) => String.t()} | %User{} | %{name: String.t()}
```

### Common specific types

```elixir
# Strings
String.t()           # UTF-8 encoded binary
binary()             # Any binary
nonempty_binary()    # At least one byte

# Numbers
pos_integer()        # 1, 2, 3, ...
non_neg_integer()    # 0, 1, 2, ...
neg_integer()        # ..., -3, -2, -1
integer()            # All integers
float()              # Floating point
number()             # integer() | float()

# Atoms
atom()               # Any atom
:ok | :error         # Specific atoms
boolean()            # true | false
module()             # Module name atom

# Collections
[User.t()]           # List of users
keyword()            # General keyword list
keyword(String.t())  # Keyword list with string values

# Time
timeout()            # :infinity | non_neg_integer()

# Functions
(integer() -> String.t())              # Single-arity function
(... -> any())                         # Any arity
(() -> String.t())                     # Zero-arity
```

## Behaviours

Define callbacks for behaviour modules:

```elixir
defmodule Parser do
  @doc "Parses a string into structured data"
  @callback parse(String.t()) :: {:ok, term()} | {:error, atom()}

  @doc "Returns supported file extensions"
  @callback extensions() :: [String.t()]

  @doc "Optional callback for validation"
  @callback validate(term()) :: boolean()
  @optional_callbacks validate: 1
end

# Implementation
defmodule JSONParser do
  @behaviour Parser

  @impl Parser
  @spec parse(String.t()) :: {:ok, term()} | {:error, :invalid_json}
  def parse(str) do
    # ...
  end

  @impl Parser
  @spec extensions() :: [String.t()]
  def extensions, do: [".json"]
end
```

## Common Pitfalls

### Don't use string()

`string()` refers to Erlang charlists, not Elixir strings:

```elixir
# Avoid - confusing
@spec process(string()) :: string()

# Use instead
@spec process(String.t()) :: String.t()     # Elixir string
@spec process(charlist()) :: charlist()     # Charlist
@spec process(binary()) :: binary()         # Any binary
```

### Don't use no_return() for side-effect functions

```elixir
# Avoid - IO.puts returns :ok
@spec log_message(String.t()) :: no_return()

# Prefer
@spec log_message(String.t()) :: :ok

# Only use no_return() for functions that never return
@spec loop_forever() :: no_return()
def loop_forever do
  receive do
    msg -> handle(msg)
  end
  loop_forever()
end
```

### Avoid overly broad types

```elixir
# Avoid - loses information
@spec transform(term()) :: term()

# Prefer - specific contracts
@spec transform(User.t()) :: UserDTO.t()
@spec transform(Post.t()) :: PostDTO.t()
```

## Dialyzer Tips

### Enable Dialyzer in your project

```elixir
# mix.exs
def project do
  [
    # ...
    dialyzer: [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  ]
end
```

### Start with loose specs, tighten over time

Begin with general types and make them more specific as you understand the domain:

```elixir
# Initial version
@spec process(map()) :: map()

# After understanding the domain
@spec process(input :: %{id: integer(), name: String.t()}) ::
  %{id: integer(), normalized_name: String.t(), processed_at: DateTime.t()}
```

### Use success typing mindset

Dialyzer uses success typing - it proves what can succeed, not what will fail. Write specs that accurately describe what your function accepts and returns on success.

## Documentation Benefits

Good typespecs serve as executable documentation:

```elixir
@typedoc "Configuration for database connection"
@type db_config :: %{
  required(:host) => String.t(),
  required(:port) => pos_integer(),
  required(:database) => String.t(),
  optional(:username) => String.t(),
  optional(:password) => String.t(),
  optional(:pool_size) => pos_integer(),
  optional(:timeout) => timeout()
}

@doc """
Establishes a connection to the database.

Returns `{:ok, pid}` on success or `{:error, reason}` if connection fails.
"""
@spec connect(db_config()) :: {:ok, pid()} | {:error, :invalid_config | :connection_failed}
def connect(config) do
  # ...
end
```

This creates clear, maintainable documentation that tools like ExDoc render beautifully.
