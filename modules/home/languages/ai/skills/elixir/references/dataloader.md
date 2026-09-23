# Absinthe Dataloader

Use Dataloader for any Absinthe field that loads data per parent object: Ecto associations, or per-item lookups against Redis or an external API. Resolve fields that read data already on the parent, or that only compute values, with a plain resolver.

1. Add `{:dataloader, "~> 2.0"}` to deps in mix.exs if it is missing.

2. Give each Phoenix context one source, built by a `data/1` function. Put all filtering and authorization for that context in `query/2`:

   ```elixir
   defmodule MyApp.Blog do
     import Ecto.Query

     def data(params \\ []) do
       Dataloader.Ecto.new(MyApp.Repo,
         query: &query/2,
         default_params: Map.new(params),
         repo_opts: [caller: self()]
       )
     end

     def query(Post, %{current_user: %{admin: true}}), do: Post

     def query(Post, %{current_user: user}) do
       from p in Post,
         where: is_nil(p.deleted_at) and (p.user_id == ^user.id or p.published == true)
     end

     def query(Post, _params), do: from(p in Post, where: is_nil(p.deleted_at) and p.published == true)

     def query(Comment, _params) do
       from c in Comment, where: c.spam == false, order_by: [desc: c.inserted_at], limit: 100
     end

     def query(queryable, _params), do: queryable
   end
   ```

   - Order `query/2` clauses from most specific params to least. A catch-all `_params` clause placed first makes every later clause for that schema unreachable.
   - The map passed as `default_params` becomes the second argument of `query/2`. Pass the current user and permission flags here, not through resolver args.
   - Keep `repo_opts: [caller: self()]` so the Ecto SQL sandbox works in tests.
   - Add a `limit` to `query/2` for any association that can grow without bound.
   - Leave `preload` out of `query/2`. Resolve each association as its own Dataloader field.

3. Register sources and the plugin in the Absinthe schema:

   ```elixir
   import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 2, dataloader: 3, on_load: 2]

   def context(ctx) do
     loader =
       Dataloader.new()
       |> Dataloader.add_source(Blog, Blog.data(current_user: ctx[:current_user]))
       |> Dataloader.add_source(Accounts, Accounts.data(current_user: ctx[:current_user]))

     Map.put(ctx, :loader, loader)
   end

   def plugins, do: [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
   ```

4. Resolve each association field.
   - Field name equals the Ecto association name: `field :author, :user, resolve: dataloader(Blog)`.
   - Field name differs: name the association, `field :writer, :user, resolve: dataloader(Blog, :author)`. `dataloader(Blog)` alone looks up an association named after the field.
   - Two fields load the same association with different filters: give each distinct args, such as `dataloader(Blog, :posts, args: %{scope: :recent})` and `args: %{scope: :popular}`. Dataloader caches by association plus args, so identical args return the same cached result.
   - Result needs trimming: pass `callback: fn posts, _parent, args -> {:ok, Enum.take(posts, args[:limit] || 10)} end` as an option to `dataloader/3`.

5. For a derived value (count, filtered subset), load then transform with `on_load/2`:

   ```elixir
   resolve fn user, _args, %{context: %{loader: loader}} ->
     loader
     |> Dataloader.load(Blog, :posts, user)
     |> on_load(fn loader ->
       {:ok, loader |> Dataloader.get(Blog, :posts, user) |> length()}
     end)
   end
   ```

6. For an aggregate that must run in SQL, add `run_batch: &run_batch/5` to `Dataloader.Ecto.new/2`. Return one result per input, in input order, and end with a fallback clause:

   ```elixir
   def run_batch(Post, query, :post_count, users, repo_opts) do
     user_ids = Enum.map(users, & &1.id)

     counts =
       query
       |> where([p], p.user_id in ^user_ids)
       |> group_by([p], p.user_id)
       |> select([p], {p.user_id, count("*")})
       |> MyApp.Repo.all(repo_opts)
       |> Map.new()

     for %{id: id} <- users, do: Map.get(counts, id, 0)
   end

   def run_batch(queryable, query, col, inputs, repo_opts) do
     Dataloader.Ecto.run_batch(MyApp.Repo, queryable, query, col, inputs, repo_opts)
   end
   ```

   Load it with `Dataloader.load(loader, Blog, {:one, Post}, post_count: user)`, then read it with the same key via `Dataloader.get/4` inside `on_load/2`.

7. For non-Ecto data, build a source with `Dataloader.KV.new(&fetch/2)`. `fetch(batch_key, args)` receives a set of args and returns a map from each arg to its result:

   ```elixir
   def fetch(:user_stats, args) do
     stats = fetch_stats_from_redis(Enum.map(args, & &1.user_id))
     Map.new(args, fn %{user_id: id} = arg -> {arg, Map.get(stats, id)} end)
   end

   def fetch(_batch_key, args), do: Map.new(args, &{&1, nil})
   ```

   Load with `Dataloader.load(loader, Cache, :user_stats, %{user_id: user.id})` and read with the same key.

8. Test the source.
   - Unit test each `query/2` clause: build the query, run `Repo.all/1`, and assert which rows it includes and excludes.
   - Integration test nested fields: post a GraphQL query with a list of 3 or more parents and one association. Assert every parent has the association loaded, and check the logged SQL shows one query per nesting level.
