"""Decide whether a change gets the light or the full maintainer review.

Usage: python3 -I triage.py <WORK> <numstat file>
Reads the numstat file (from `git diff --numstat`), WORK/context-file.md and
WORK/src/.gitattributes. Writes WORK/triage.md and prints it.

The light review runs when the change is small and touches nothing that runs on
checkout, install, build or CI, and no dependency. Every doubt picks full.
"""

import fnmatch
import re
import sys
from pathlib import Path

DEFAULT_LIGHT_MAX_LINES = 80

LOCKFILES = {
    "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "Cargo.lock", "go.sum",
    "mix.lock", "Gemfile.lock", "poetry.lock", "uv.lock", "flake.lock", "bun.lock",
    "bun.lockb", "composer.lock", "Podfile.lock", "Package.resolved",
}
GENERATED_MARKERS = ("@generated", "DO NOT EDIT", "Code generated", "auto-generated")

# Paths whose change can run code on a maintainer's machine or in CI, or changes dependencies.
RISKY = [
    (r"(^|/)\.github/", "CI or repository config"),
    (r"(^|/)\.gitlab-ci|(^|/)\.circleci/|(^|/)\.buildkite/|(^|/)Jenkinsfile$", "CI config"),
    (r"(^|/)(package\.json|build\.rs|setup\.py|setup\.cfg|pyproject\.toml|conftest\.py)$",
     "runs on install, build or test"),
    (r"(^|/)(Makefile|GNUmakefile|[^/]+\.mk|Justfile|Taskfile\.ya?ml)$", "build script"),
    (r"(^|/)(flake\.nix|shell\.nix|\.envrc|Dockerfile[^/]*|docker-compose[^/]*)$",
     "dev or build environment"),
    (r"(^|/)(\.devcontainer|\.vscode|\.idea|\.husky|\.githooks)/", "editor or git hook config"),
    (r"(^|/)(lefthook[^/]*\.ya?ml|\.pre-commit-config\.yaml|\.gitattributes|\.gitmodules)$",
     "git hook or repo config"),
    (r"(^|/)(Cargo\.toml|go\.mod|Gemfile|[^/]+\.gemspec|mix\.exs|requirements[^/]*\.txt"
     r"|build\.gradle(\.kts)?|settings\.gradle(\.kts)?|pom\.xml|Package\.swift|Podfile"
     r"|composer\.json)$", "dependency manifest"),
]


def new_path(raw):
    if " => " not in raw:
        return raw
    if "{" in raw:
        return re.sub(r"\{[^{}]* => ([^{}]*)\}", r"\1", raw).replace("//", "/")
    return raw.split(" => ", 1)[1]


def context_settings(text):
    settings = {"generated": [], "always_full": [], "light_max_lines": None}
    current = None
    for line in text.splitlines():
        key = re.match(r"^\s*(generated|always_full):\s*$", line)
        if key:
            current = key.group(1)
            continue
        item = re.match(r"^\s+-\s+(\S+)", line)
        if current and item:
            settings[current].append(item.group(1).strip("`\"'"))
            continue
        current = None
        limit = re.match(r"^\s*light_max_lines:\s*(\d+)", line)
        if limit:
            settings["light_max_lines"] = int(limit.group(1))
    return settings


def gitattributes_globs(src):
    path = src / ".gitattributes"
    globs = []
    if not path.exists():
        return globs
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if len(parts) < 2 or parts[0].startswith("#"):
            continue
        attrs = parts[1:]
        if any(a in ("linguist-generated", "linguist-generated=true", "linguist-vendored",
                     "linguist-vendored=true", "-diff") for a in attrs):
            globs.append(parts[0])
    return globs


def matches(path, glob):
    # Approximates gitignore-style globs: a pattern with no slash matches the basename anywhere.
    glob = glob.lstrip("/")
    if glob.endswith("/"):
        glob += "**"
    if "/" not in glob:
        return fnmatch.fnmatch(Path(path).name, glob)
    return fnmatch.fnmatch(path, glob) or fnmatch.fnmatch(path, glob.replace("**/", ""))


def generated_reason(path, src, attr_globs, context_globs):
    if Path(path).name in LOCKFILES:
        return "lockfile"
    for glob in attr_globs:
        if matches(path, glob):
            return f".gitattributes `{glob}`"
    for glob in context_globs:
        if matches(path, glob):
            return f"context file `{glob}`"
    file = src / path
    if file.is_file():
        try:
            head = "".join(file.open(errors="replace").readlines()[:10])
        except OSError:
            head = ""
        for marker in GENERATED_MARKERS:
            if marker in head:
                return f"header `{marker}`"
    return None


def main():
    work = Path(sys.argv[1])
    numstat = Path(sys.argv[2])
    src = work / "src"
    context = work / "context-file.md"
    settings = context_settings(context.read_text(errors="replace") if context.exists() else "")
    attr_globs = gitattributes_globs(src)
    limit = settings["light_max_lines"] or DEFAULT_LIGHT_MAX_LINES
    limit_source = "context file" if settings["light_max_lines"] else "default"

    hand_lines = hand_files = gen_lines = 0
    generated, full_reasons = [], []
    for line in numstat.read_text(errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        added, deleted, path = parts[0], parts[1], new_path(parts[2])
        reason = generated_reason(path, src, attr_globs, settings["generated"])
        if added == "-" and not reason:
            full_reasons.append(f"`{path}`: binary file")
            continue
        count = 0 if added == "-" else int(added) + int(deleted)
        for pattern, why in RISKY:
            if re.search(pattern, path):
                full_reasons.append(f"`{path}`: {why}")
                break
        for glob in settings["always_full"]:
            if matches(path, glob):
                full_reasons.append(f"`{path}`: context file always_full `{glob}`")
                break
        if reason:
            generated.append(f"- `{path}` - {reason}")
            gen_lines += count
            if reason == "lockfile":
                full_reasons.append(f"`{path}`: lockfile changed")
        else:
            hand_lines += count
            hand_files += 1

    if hand_lines > limit:
        full_reasons.append(f"{hand_lines} hand-written lines changed, over the light limit of {limit}")

    mode = "full" if full_reasons else "light"
    out = [
        f"mode: {mode}",
        f"hand_written_lines: {hand_lines} in {hand_files} files",
        f"generated_lines: {gen_lines}",
        f"light_max_lines: {limit} ({limit_source})",
        "",
        "## Reasons for full",
        *(f"- {r}" for r in full_reasons or ["none"]),
        "",
        "## Generated files (approximate; the full review's context agent classifies them again)",
        *(generated or ["none"]),
    ]
    text = "\n".join(out) + "\n"
    (work / "triage.md").write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
