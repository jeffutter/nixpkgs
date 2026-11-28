# visual-plan and visual-recap from BuilderIO/skills, changed in two ways:
#
# - Both default to publishing plan and diff content to the hosted
#   plan.agent-native.com. Each SKILL.md here says to stay local, for every
#   agent whatever its environment, and ai.nix exports the matching
#   AGENT_NATIVE_PLANS_MODE.
# - Upstream runs the CLI as `npx @agent-native/core@latest`. These call the
#   pinned `agent-native` from pkgs/agent-native.
#
# They stay side by side because visual-recap reads ../visual-plan/references.
{ src, runCommand }:

runCommand "builderio-visual-skills" { } ''
  mkdir -p $out
  cp -r ${src}/skills/visual-plan ${src}/skills/visual-recap $out/
  chmod -R u+w $out
  # Install instructions for people, all through npx.
  rm $out/*/README.md

  # Install and sign-in steps for the hosted service.
  grep -q '^## Setup & Authentication$' $out/visual-plan/SKILL.md
  awk '/^## / { skip = /^## Setup & Authentication$/ } !skip' \
    $out/visual-plan/SKILL.md > SKILL.md
  mv SKILL.md $out/visual-plan/SKILL.md

  find $out -name '*.md' -exec sed -i -E \
    's/npx (-y )?@agent-native\/core@latest/agent-native/g' {} +
  if grep -rn 'npx\|@latest' $out; then
    echo "a skill still runs unpinned code; update the patterns above" >&2
    exit 1
  fi

  localOnly() {
    substituteInPlace "$out/$1/SKILL.md" --replace-fail "$2" "$2

  **This install uses Local-Files Privacy Mode for every plan and recap.** Read
  \`references/local-files.md\` and follow it. Do not call hosted Plan tools or ask
  the user to connect the Plan MCP server, unless the user asks to publish.

  Nix puts a pinned \`agent-native\` on \`PATH\`. Never run the CLI through \`npx\`
  or install it, even where its own output suggests that."
  }
  localOnly visual-plan '# Agent-Native Plans'
  localOnly visual-recap '# Visual Recap'
''
