#!/usr/bin/env python3
"""List the @requires a subgraph declares in a supergraph.

usage: requires_list.py SUPERGRAPH.graphql GRAPH [--match REGEX]

GRAPH is the join__Graph enum value (for example REVIEWS), as it appears in
`@join__field(graph: REVIEWS, requires: "...")`. --match keeps only fields whose requires
selection mentions a field name matching REGEX. Prints Type.field, the approximate number of
required fields, and the top-level required fields.
"""
import argparse
import re

ap = argparse.ArgumentParser()
ap.add_argument("supergraph")
ap.add_argument("graph")
ap.add_argument("--match")
opts = ap.parse_args()

text = open(opts.supergraph).read()
types = [(m.start(), m.group(1)) for m in re.finditer(r"^(?:type|interface) (\w+)", text, re.M)]
field_re = re.compile(
    r'^\s+(\w+)(?:\([^)]*\))?: [^\n]*?@join__field\(graph: ' + re.escape(opts.graph)
    + r', requires: "((?:[^"\\]|\\.)*)"', re.M)

for m in field_re.finditer(text):
    owner = max((t for t in types if t[0] < m.start()), default=(0, "?"))[1]
    requires = m.group(2).encode().decode("unicode_escape")
    names = re.findall(r"[A-Za-z_]\w*", requires)
    if opts.match and not any(re.fullmatch(opts.match, n) for n in names):
        continue
    depth, top = 0, []
    for tok in re.findall(r"[A-Za-z_]\w*|[{}()]|\.\.\.", requires):
        if tok in "{(":
            depth += 1
        elif tok in "})":
            depth -= 1
        elif depth == 0 and tok not in ("...", "on"):
            top.append(tok)
    count = len(re.findall(r"^\s*[A-Za-z_]\w*(?:\([^)]*\))?\s*(?:\{|$)", requires, re.M))
    print(f"{owner}.{m.group(1)}: ~{count} fields; top level: {', '.join(dict.fromkeys(top))[:200]}")
