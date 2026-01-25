---
name: elixir-expert
description: Elixir coding best practices, typespecs, and idiomatic patterns. Use when writing Elixir code, adding type specifications, reviewing Elixir implementations, refactoring Elixir projects, or providing guidance on Elixir development patterns, error handling, API design, and type safety.
---
# Absinthe Dataloader

Comprehensive guide to using Dataloader with Absinthe GraphQL to solve N+1 query problems and efficiently batch database queries.

## Overview

Dataloader is a utility that batches and caches data requests in GraphQL, preventing N+1 query problems. It's inspired by Facebook's DataLoader but adapted for Elixir/Ecto patterns.

**The N+1 Problem:**
```elixir
# Without Dataloader: 1 + 10 queries
query {
  posts {           # 1 query for posts
    author {        # 10 separate queries for authors
      name
    }
  }
}

# With Dataloader: 2 queries total
# 1 query for posts, 1 batched query for all authors
```

## When to Use Dataloader

**Use Dataloader when:**
- Loading associations between Ecto schemas (posts → authors, users → posts)
- Resolving fields that depend on data from parent objects
- You have nested GraphQL queries that could cause N+1 problems
- You want to enforce data access rules within Phoenix contexts
- You need to apply filtering, pagination, or authorization consistently

**Don't use Dataloader when:**
- The field doesn't require database queries
- You're doing simple transformations or calculations
- The data is already available in the parent object

## Setup

### 1. Add Dependency

```elixir
# mix.exs
def deps do
  [
    {:dataloader, "~> 1.0"},
    {:absinthe, "~> 1.7"}
  ]
end
```

### 2. Configure Context Module

Create a `data/0` function in each Phoenix context:

```elixir
# lib/my_app/blog.ex
defmodule MyApp.Blog do
  def data() do
    Dataloader.Ecto.new(MyApp.Repo, query: &query/2)
  end

  # Base query function - customize per schema
  def query(queryable, _params) do
    queryable
  end
end
```

### 3. Configure Absinthe Schema

```elixir
# lib/my_app_web/schema.ex
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  # Add dataloader to context
  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Blog, Blog.data())
      |> Dataloader.add_source(Accounts, Accounts.data())

    Map.put(ctx, :loader, loader)
  end

  # Register the Dataloader plugin
  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
```

## Basic Usage Patterns

### Simple Association Loading

When field name matches the Ecto association:

```elixir
object :post do
  field :id, :id
  field :title, :string

  # Automatically resolves the :author association
  field :author, :user, resolve: dataloader(Blog)
end

object :user do
  field :id, :id
  field :name, :string

  # Automatically resolves the :posts association
  field :posts, list_of(:post), resolve: dataloader(Accounts)
end
```

### Explicit Association Name

When field name differs from association:

```elixir
object :post do
  field :id, :id
  field :title, :string

  # Field is "writer" but association is "author"
  field :writer, :user, resolve: dataloader(Blog, :author)
end
```

### With Field Arguments

```elixir
object :user do
  field :id, :id
  field :name, :string

  field :posts, list_of(:post) do
    arg :limit, :integer
    arg :status, :string

    resolve dataloader(Blog, :posts, args: %{
      scope: :published,
      order: :desc
    })
  end
end
```

## Advanced Query Customization

### Pattern Match on Schema and Params

Use the `query/2` function to customize queries based on schema type and context:

```elixir
defmodule MyApp.Blog do
  def data() do
    Dataloader.Ecto.new(MyApp.Repo, query: &query/2)
  end

  # Filter deleted posts
  def query(Post, _params) do
    from p in Post, where: is_nil(p.deleted_at)
  end

  # Apply authorization based on context
  def query(Post, %{current_user: %{admin: true}}) do
    Post  # Admins see all posts
  end

  def query(Post, %{current_user: user}) do
    from p in Post,
      where: p.user_id == ^user.id or p.published == true
  end

  def query(Post, _params) do
    from p in Post, where: p.published == true
  end

  # Apply pagination and ordering
  def query(Comment, %{limit: limit}) do
    from c in Comment,
      where: c.spam == false,
      order_by: [desc: c.inserted_at],
      limit: ^limit
  end

  # Default - no modifications
  def query(queryable, _params) do
    queryable
  end
end
```

### Passing Context to query/2

Make authorization data available in queries:

```elixir
# In schema context/1
def context(ctx) do
  # Extract current_user from ctx (e.g., from Plug.Conn)
  current_user = get_current_user(ctx)

  loader =
    Dataloader.new()
    |> Dataloader.add_source(
      Blog,
      Blog.data(current_user: current_user)
    )

  Map.put(ctx, :loader, loader)
end

# In context module
def data(opts \\ []) do
  Dataloader.Ecto.new(MyApp.Repo, query: &query/2, default_params: opts)
end

def query(Post, %{current_user: user}) do
  from p in Post,
    left_join: m in assoc(p, :memberships),
    where: m.user_id == ^user.id or p.published == true
end
```

## Manual Dataloader Usage

### Using on_load for Post-Processing

When you need to transform or aggregate loaded data:

```elixir
field :post_count, :integer do
  resolve fn user, _args, %{context: %{loader: loader}} ->
    loader
    |> Dataloader.load(Blog, :posts, user)
    |> on_load(fn loader ->
      posts = Dataloader.get(loader, Blog, :posts, user)
      {:ok, length(posts)}
    end)
  end
end

field :published_posts, list_of(:post) do
  resolve fn user, args, %{context: %{loader: loader}} ->
    loader
    |> Dataloader.load(Blog, :posts, user)
    |> on_load(fn loader ->
      posts = Dataloader.get(loader, Blog, :posts, user)
      published = Enum.filter(posts, & &1.published)
      {:ok, published}
    end)
  end
end
```

### Custom Batch Functions

For aggregations and complex queries not supported by default Ecto batching:

```elixir
defmodule MyApp.Blog do
  def data() do
    Dataloader.Ecto.new(
      MyApp.Repo,
      query: &query/2,
      run_batch: &run_batch/5
    )
  end

  # Custom batch for counting posts per user
  def run_batch(Post, query, :post_count, users, repo_opts) do
    user_ids = Enum.map(users, & &1.id)

    counts =
      query
      |> where([p], p.user_id in ^user_ids)
      |> group_by([p], p.user_id)
      |> select([p], {p.user_id, count("*")})
      |> MyApp.Repo.all(repo_opts)
      |> Map.new()

    # Return counts in same order as input users
    for %{id: id} <- users do
      Map.get(counts, id, 0)
    end
  end

  # Fallback to default Ecto behavior
  def run_batch(queryable, query, col, inputs, repo_opts) do
    Dataloader.Ecto.run_batch(
      MyApp.Repo,
      queryable,
      query,
      col,
      inputs,
      repo_opts
    )
  end
end

# Usage in schema
field :post_count, :integer do
  resolve fn user, _args, %{context: %{loader: loader}} ->
    loader
    |> Dataloader.load(Blog, Post, :post_count, user)
    |> on_load(fn loader ->
      count = Dataloader.get(loader, Blog, Post, :post_count, user)
      {:ok, count}
    end)
  end
end
```

### Callbacks for Data Transformation

Transform loaded data before returning:

```elixir
field :recent_posts, list_of(:post) do
  arg :limit, :integer

  resolve dataloader(
    Blog,
    :posts,
    callback: fn posts, _user, args ->
      filtered = Enum.take(posts, args[:limit] || 10)
      {:ok, filtered}
    end
  )
end
```

## Key Patterns and Best Practices

### 1. One Source Per Context

Maintain proper boundaries by creating one Dataloader source per Phoenix context:

```elixir
def context(ctx) do
  loader =
    Dataloader.new()
    |> Dataloader.add_source(Blog, Blog.data())
    |> Dataloader.add_source(Accounts, Accounts.data())
    |> Dataloader.add_source(Products, Products.data())

  Map.put(ctx, :loader, loader)
end
```

### 2. Use Context for Authorization

Pass authorization info through the Dataloader context:

```elixir
# In schema
def context(ctx) do
  current_user = get_current_user(ctx)

  loader =
    Dataloader.new()
    |> Dataloader.add_source(
      Blog,
      Blog.data(current_user: current_user, has_admin_rights: is_admin?(current_user))
    )

  Map.put(ctx, :loader, loader)
end

# In context module
def query(Post, %{has_admin_rights: true}) do
  Post  # Admins see everything
end

def query(Post, %{current_user: user}) do
  from p in Post,
    left_join: m in assoc(p, :memberships),
    where: m.user_id == ^user.id or p.published == true
end
```

### 3. Prevent Over-Fetching

Apply sensible defaults in `query/2`:

```elixir
def query(Comment, _params) do
  from c in Comment,
    where: c.spam == false,
    order_by: [desc: c.inserted_at],
    limit: 100  # Prevent loading thousands of comments
end
```

### 4. SQL Sandbox Configuration for Tests

When using Ecto's SQL sandbox in tests, ensure proper PID handling:

```elixir
def data(opts \\ []) do
  Dataloader.Ecto.new(
    MyApp.Repo,
    query: &query/2,
    default_params: opts,
    repo_opts: [caller: self()]  # Critical for test isolation
  )
end
```

### 5. Consistent Error Handling

Handle missing associations gracefully:

```elixir
# In context module
def query(Post, _params) do
  from p in Post,
    where: is_nil(p.deleted_at),
    preload: [:author]  # Ensure author is loaded
end

# In schema
object :post do
  field :author, :user do
    resolve fn post, _args, _ctx ->
      case post.author do
        %Ecto.Association.NotLoaded{} -> {:error, "Author not loaded"}
        nil -> {:ok, nil}
        author -> {:ok, author}
      end
    end
  end
end
```

## Alternative: KV Source for Non-Ecto Data

For data not backed by Ecto (Redis, external APIs, etc.):

```elixir
defmodule MyApp.Cache do
  def data() do
    Dataloader.KV.new(&fetch/2)
  end

  # Batch key identifies which data to fetch
  def fetch(:user_stats, args) do
    # args is a list of arguments from field resolution
    # Must return a map keyed by the args
    user_ids = Enum.map(args, & &1.user_id)

    stats = fetch_stats_from_redis(user_ids)

    # Map results back to args
    Enum.reduce(args, %{}, fn %{user_id: id} = arg, acc ->
      Map.put(acc, arg, Map.get(stats, id))
    end)
  end

  def fetch(:api_data, args) do
    ids = Enum.map(args, & &1.id)

    responses = external_api_batch_fetch(ids)

    Enum.reduce(args, %{}, fn %{id: id} = arg, acc ->
      Map.put(acc, arg, Map.get(responses, id))
    end)
  end

  # Default - return nil for unknown batches
  def fetch(_batch, args) do
    Enum.reduce(args, %{}, fn arg, acc ->
      Map.put(acc, arg, nil)
    end)
  end
end

# Usage in schema
field :stats, :user_stats do
  resolve fn user, _args, %{context: %{loader: loader}} ->
    loader
    |> Dataloader.load(Cache, :user_stats, %{user_id: user.id})
    |> on_load(fn loader ->
      stats = Dataloader.get(loader, Cache, :user_stats, %{user_id: user.id})
      {:ok, stats}
    end)
  end
end
```

## Common Gotchas

### 1. Pagination and Argument Caching

When using the same pagination args for multiple queries in one GraphQL request, Dataloader may cache and reuse results incorrectly:

```elixir
# Problem: Both fields share the same batch key
field :recent_posts, list_of(:post) do
  arg :limit, :integer
  resolve dataloader(Blog, :posts)  # Uses default batching
end

field :popular_posts, list_of(:post) do
  arg :limit, :integer
  resolve dataloader(Blog, :posts)  # Same batch key!
end

# Solution: Use unique batch keys or custom batch functions
field :recent_posts, list_of(:post) do
  arg :limit, :integer
  resolve dataloader(Blog, :posts, args: %{scope: :recent})
end

field :popular_posts, list_of(:post) do
  arg :limit, :integer
  resolve dataloader(Blog, :posts, args: %{scope: :popular})
end
```

### 2. Deeply Nested Queries

Dataloader runs in passes - it makes multiple batched queries for deeply nested structures rather than one single query:

```graphql
# This makes 3 passes of batched queries
query {
  posts {              # Pass 1
    author {           # Pass 2
      organization {   # Pass 3
        name
      }
    }
  }
}
```

This is generally efficient but understand it's not a single JOIN query.

### 3. Association Name Mismatches

The `dataloader/1` helper uses the field name to determine the association:

```elixir
# This won't work - looks for :writer association
field :writer, :user, resolve: dataloader(Blog)

# Must explicitly specify association name
field :writer, :user, resolve: dataloader(Blog, :author)
```

### 4. Context Data Availability

The params passed to `query/2` come from Dataloader's default_params:

```elixir
# Correct - pass context when creating source
def context(ctx) do
  loader =
    Dataloader.new()
    |> Dataloader.add_source(
      Blog,
      Blog.data(current_user: ctx.current_user)
    )

  Map.put(ctx, :loader, loader)
end

# In context module
def data(opts \\ []) do
  Dataloader.Ecto.new(
    MyApp.Repo,
    query: &query/2,
    default_params: opts  # These become params in query/2
  )
end
```

### 5. Preloading Associations

Don't mix Ecto.Query preload with Dataloader - let Dataloader handle the batching:

```elixir
# Avoid - defeats the purpose of Dataloader
def query(Post, _params) do
  from p in Post, preload: [:author, :comments]
end

# Prefer - let Dataloader batch these
def query(Post, _params) do
  Post
end

# Define author and comments as Dataloader fields in schema
field :author, :user, resolve: dataloader(Blog)
field :comments, list_of(:comment), resolve: dataloader(Blog)
```

## Testing Dataloader

### Unit Testing Context Queries

```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase

  alias MyApp.Blog

  test "query/2 filters deleted posts" do
    post = insert(:post, deleted_at: nil)
    deleted_post = insert(:post, deleted_at: DateTime.utc_now())

    query = Blog.query(Post, %{})
    results = Repo.all(query)

    assert post in results
    refute deleted_post in results
  end

  test "query/2 respects authorization" do
    user = insert(:user)
    published = insert(:post, published: true)
    draft = insert(:post, published: false, user_id: user.id)
    other_draft = insert(:post, published: false)

    query = Blog.query(Post, %{current_user: user})
    results = Repo.all(query)

    assert published in results
    assert draft in results
    refute other_draft in results
  end
end
```

### Integration Testing with Absinthe

```elixir
defmodule MyAppWeb.Schema.PostsTest do
  use MyAppWeb.ConnCase

  test "loads authors efficiently", %{conn: conn} do
    posts = insert_list(3, :post)

    query = """
    {
      posts {
        id
        title
        author {
          id
          name
        }
      }
    }
    """

    # Enable query logging to verify batching
    result = conn
             |> post("/api/graphql", %{query: query})
             |> json_response(200)

    # Verify results
    assert length(result["data"]["posts"]) == 3
    assert Enum.all?(result["data"]["posts"], & &1["author"])

    # In test output, verify only 2 queries:
    # 1. SELECT posts
    # 2. SELECT users WHERE id IN (...)
  end
end
```

This comprehensive guide covers the essential patterns for using Dataloader effectively with Absinthe GraphQL in Elixir.
