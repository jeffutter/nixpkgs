
## Gotchas (local additions)

- **One metric query per call.** `pup metrics query --query "a{...},b{...}"` can return wrong
  values per series (observed: 48.6 for a series that reads 139 on its own) or `[]`. Chain
  separate calls with `;`, or use one query with `by {tag}` and pick series in `--jq`.
- **Drop null points before averaging.** Pointlists hold `null` for empty intervals, and jq's
  `add` treats them as 0 while `length` counts them:
  `(.pointlist | map(select(.[1] != null) | .[1])) as $v | $v | add / length`.
- **Grouped series:** the tag values are in `.scope` (`"tag_a:x,tag_b:y"`), not in a field per tag.
- **`trace.<span>.duration` / `trace.<span>.hits`** (both `.as_rate()`) is mean latency in
  seconds. The mean is easily skewed by a few hung requests; for a typical value use
  `pup traces aggregate --compute "median(@duration)"`. `p50:trace.*` returns nothing unless
  the metric has percentiles enabled.
- **`pup traces aggregate`:** buckets are objects with `.by.<facet>` and `.compute.c0`.
  `@duration` is in nanoseconds. Only about 10 groups come back and there is no limit flag, so
  narrow the `--query` (for example `@facet:*Name*`) instead of grouping over everything.
  Span facets for request bodies look like `@http.body_params.operation_name`; find the keys
  with `pup traces search ... --limit 1 --jq '[.. | objects | select(has("attributes")) | .attributes | paths(scalars) | map(tostring) | join(".")]'`.
- **Discovery:** `pup metrics list --filter <prefix>` lists metric names;
  `pup metrics tags list <metric>` (positional, no `--metric`) lists its tags. To reuse a
  dashboard or notebook's queries, `pup notebooks get <id> --jq '[.. | objects | select(has("q")) | .q]'`.
- **Kubernetes CPU:** `kubernetes.cpu.usage.total` is nanocores; divide by 1e9 for cores.
