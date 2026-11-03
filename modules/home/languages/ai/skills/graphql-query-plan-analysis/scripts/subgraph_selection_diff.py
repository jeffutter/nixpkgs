#!/usr/bin/env python3
"""Compare what one subgraph is asked to resolve under two sets of variables.

usage: subgraph_selection_diff.py PLAN.json SUBGRAPH A.json B.json [--entities] [--depth N] [--top N]

PLAN.json is `graphql-document-utils query plan --json` output for the query in variable form.
A.json and B.json are variable objects; booleans not given count as false. For each fetch to
SUBGRAPH (root fetches only, unless --entities), the script evaluates @include/@skip inside the
subgraph operation, expands named fragments, and counts selected field paths. It prints the totals
for A and B, the paths whose counts differ most (grouped to --depth levels), and the paths only B
selects. Counts are static selections in the operation, not runtime work: a list field counts once.
"""
import argparse
import collections
import json
import re

TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|\.\.\.|[A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z_][A-Za-z0-9_]*|-?\d+(?:\.\d+)?|[{}()\[\]:,@=!|&]')


class Parser:
    def __init__(self, text):
        self.tokens = TOKEN.findall(text)
        self.i = 0

    def peek(self):
        return self.tokens[self.i] if self.i < len(self.tokens) else None

    def take(self):
        tok = self.tokens[self.i]
        self.i += 1
        return tok

    def skip_group(self, open_, close):
        depth = 0
        while True:
            tok = self.take()
            depth += tok == open_
            depth -= tok == close
            if depth == 0:
                return

    def directives(self):
        out = []
        while self.peek() == "@":
            self.take()
            name = self.take()
            cond = None
            if self.peek() == "(":
                start = self.i
                self.skip_group("(", ")")
                body = self.tokens[start:self.i]
                if "if" in body:
                    cond = body[body.index("if") + 2]
            out.append((name, cond))
        return out

    def selection_set(self):
        selections = []
        self.take()  # {
        while self.peek() != "}":
            if self.peek() == "...":
                self.take()
                if self.peek() in ("on", "{", "@"):
                    type_name = None
                    if self.peek() == "on":
                        self.take()
                        type_name = self.take()
                    dirs = self.directives()
                    selections.append(("inline", type_name, dirs, self.selection_set()))
                else:
                    name = self.take()
                    selections.append(("spread", name, self.directives(), None))
                continue
            name = self.take()
            if self.peek() == ":":
                self.take()
                name = self.take()
            if self.peek() == "(":
                self.skip_group("(", ")")
            dirs = self.directives()
            sub = self.selection_set() if self.peek() == "{" else None
            selections.append(("field", name, dirs, sub))
        self.take()  # }
        return selections

    def document(self):
        operations, fragments = [], {}
        while self.peek() is not None:
            tok = self.take()
            if tok in ("query", "mutation", "subscription"):
                while self.peek() != "{":
                    if self.peek() == "(":
                        self.skip_group("(", ")")
                    else:
                        self.take()
                operations.append(self.selection_set())
            elif tok == "fragment":
                name = self.take()
                self.take()  # on
                self.take()  # type condition
                self.directives()
                fragments[name] = self.selection_set()
            elif tok == "{":
                self.i -= 1
                operations.append(self.selection_set())
        return operations, fragments


def included(dirs, variables):
    for name, cond in dirs:
        value = variables.get(cond[1:], False) if cond and cond.startswith("$") else cond == "true"
        if name == "include" and not value:
            return False
        if name == "skip" and value:
            return False
    return True


def expand(selections, fragments, variables, path, out, depth=0):
    if depth > 60:
        return
    for kind, name, dirs, sub in selections:
        if not included(dirs, variables):
            continue
        if kind == "field":
            field_path = f"{path}.{name}" if path else name
            out[field_path] += 1
            if sub:
                expand(sub, fragments, variables, field_path, out, depth + 1)
        elif kind == "inline":
            expand(sub, fragments, variables, path, out, depth + 1)
        elif kind == "spread":
            expand(fragments.get(name, []), fragments, variables, path, out, depth + 1)


def fetches(node, path=""):
    if not node:
        return
    kind = node.get("kind")
    if kind == "Fetch":
        yield path, node
    elif kind == "Flatten":
        yield from fetches(node.get("node"), ".".join(str(x) for x in node.get("path", [])))
    elif kind in ("Sequence", "Parallel"):
        for child in node.get("nodes", []):
            yield from fetches(child, path)
    elif kind == "Condition":
        yield from fetches(node.get("ifClause"), path)
        yield from fetches(node.get("elseClause"), path)
    elif kind == "Defer":
        yield from fetches(node.get("primary", {}).get("node"), path)
        for deferred in node.get("deferred", []):
            yield from fetches(deferred.get("node"), path)
    elif kind == "Subscription":
        yield from fetches(node.get("primary"), path)
        yield from fetches(node.get("rest"), path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plan")
    ap.add_argument("subgraph")
    ap.add_argument("vars_a")
    ap.add_argument("vars_b")
    ap.add_argument("--entities", action="store_true", help="also compare _entities fetches")
    ap.add_argument("--depth", type=int, default=6)
    ap.add_argument("--top", type=int, default=25)
    opts = ap.parse_args()
    plan = json.load(open(opts.plan))
    vars_a, vars_b = json.load(open(opts.vars_a)), json.load(open(opts.vars_b))

    def group(path):
        return ".".join(path.split(".")[:opts.depth])

    for index, (path, fetch) in enumerate(fetches(plan.get("node"))):
        if fetch["serviceName"] != opts.subgraph or (fetch.get("requires") and not opts.entities):
            continue
        operations, fragments = Parser(fetch["operation"]).document()
        a, b = collections.Counter(), collections.Counter()
        for selections in operations:
            expand(selections, fragments, vars_a, "", a)
            expand(selections, fragments, vars_b, "", b)
        print(f"fetch #{index} at {path or '<root>'}: selected field paths A={sum(a.values())} B={sum(b.values())}")
        ga, gb = collections.Counter(), collections.Counter()
        for p, n in a.items():
            ga[group(p)] += n
        for p, n in b.items():
            gb[group(p)] += n
        changed = sorted((k for k in set(ga) | set(gb) if ga[k] != gb[k]), key=lambda k: -abs(gb[k] - ga[k]))
        print("  largest differences (A -> B):")
        for k in changed[:opts.top]:
            print(f"    {ga[k]:6} -> {gb[k]:6}  {k}")
        only_b = collections.Counter()
        for p, n in b.items():
            if p not in a:
                only_b[group(p)] += n
        print("  selected only under B:")
        for k, n in only_b.most_common(opts.top):
            print(f"    {n:6}  {k}")


if __name__ == "__main__":
    main()
