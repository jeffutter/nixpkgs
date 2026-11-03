#!/usr/bin/env python3
"""List the fetches an Apollo Router query plan runs for one set of boolean variables.

usage: plan_fetches.py PLAN.json [name=true|false ...] [--ops]

PLAN.json is `graphql-document-utils query plan --json` output for the query in variable form.
Condition nodes on variables not given count as false. Prints one line per fetch (sequential
level, subgraph, entity type, operation size, response path), the number of sequential levels,
fetches per subgraph, and the conditions that defaulted to false. --ops also prints each
subgraph operation, cut to 400 characters with long opaque runs masked.
"""
import collections
import json
import re
import sys

args = [a for a in sys.argv[2:] if not a.startswith("--")]
show_ops = "--ops" in sys.argv
variables = {k: v == "true" for k, v in (a.split("=", 1) for a in args)}
seen_conditions = set()


def walk(node, path, level, out):
    if not node:
        return level
    kind = node.get("kind")
    if kind == "Fetch":
        requires = node.get("requires") or []
        entity = ",".join(sorted({r.get("typeCondition", "") for r in requires})) or "-"
        out.append((level, node["serviceName"], path or "<root>", entity, node.get("operation", "")))
        return level + 1
    if kind == "Flatten":
        return walk(node.get("node"), ".".join(str(x) for x in node.get("path", [])), level, out)
    if kind == "Sequence":
        for child in node.get("nodes", []):
            level = walk(child, path, level, out)
        return level
    if kind == "Parallel":
        return max([walk(child, path, level, out) for child in node.get("nodes", [])] or [level])
    if kind == "Condition":
        seen_conditions.add(node["condition"])
        branch = "ifClause" if variables.get(node["condition"], False) else "elseClause"
        return walk(node.get(branch), path, level, out)
    if kind == "Defer":
        level = walk(node.get("primary", {}).get("node"), path, level, out)
        for deferred in node.get("deferred", []):
            walk(deferred.get("node"), path, level, out)
        return level
    if kind == "Subscription":
        level = walk(node.get("primary"), path, level, out)
        return walk(node.get("rest"), path, level, out)
    raise SystemExit(f"unhandled plan node kind: {kind}")


plan = json.load(open(sys.argv[1]))
fetches = []
depth = walk(plan.get("node"), "", 0, fetches)
for level, service, path, entity, op in fetches:
    print(f"L{level} {service:24} {entity:32} {len(op):7}B {path}")
    if show_ops:
        print("    " + re.sub(r"[A-Za-z0-9+/=_-]{40,}", "<ID>", re.sub(r"\s+", " ", op))[:400])
print("sequential levels:", depth)
print("fetches by subgraph:", dict(collections.Counter(f[1] for f in fetches)))
print("conditions defaulted to false:", sorted(seen_conditions - set(variables)) or "none")
