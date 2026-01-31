{
  pkgs,
  inputs,
  config,
  ...
}:

let
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
  beads = inputs.beads;
  beads_bin = beads.packages.${pkgs.system}.default;
  stop-slop = inputs.stop-slop;
  claude-plugins-official = inputs.claude-plugins-official;
  the-elements-of-style = inputs.the-elements-of-style;

  ticket = pkgs.stdenvNoCC.mkDerivation {
    pname = "ticket";
    version = "unstable";
    src = inputs.ticket;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      cp ticket $out/bin/ticket
      chmod +x $out/bin/ticket
      ln -s $out/bin/ticket $out/bin/tk
    '';
  };

  claude-skills = pkgs.runCommand "claude-skills" { } ''
    mkdir -p $out
    ln -s ${./ai/skills/acli} $out/acli
    ln -s ${./ai/skills/beads-planner} $out/beads-planner
    ln -s ${./ai/skills/brainstorming} $out/brainstorming
    ln -s ${./ai/skills/elixir} $out/elixir
    ln -s ${stop-slop} $out/stop-slop
    ln -s ${the-elements-of-style}/skills/writing-clearly-and-concisely $out/writing-clearly-and-concisely
  '';

  buildTime = pkgs.runCommand "build-time" { } ''
    date -u +"%Y-%m-%dT%H:%M:%S.000Z" > $out
  '';

  # Helper function to read markdown files from the ai directory
  readAiDoc = file: builtins.readFile (./ai + "/${file}");

  commitMsgCommon = {
    intro = readAiDoc "shared/commit-msg/commit-msg-intro.md";
    writingStyle = readAiDoc "shared/commit-msg/commit-msg-writing-style.md";
    technicalDepth = readAiDoc "shared/commit-msg/commit-msg-technical-depth.md";
    toneExamples = readAiDoc "shared/commit-msg/commit-msg-tone-examples.md";
    antiPatterns = readAiDoc "shared/commit-msg/commit-msg-anti-patterns.md";
    specifics = readAiDoc "shared/commit-msg/commit-msg-specifics.md";
    closing = readAiDoc "shared/commit-msg/commit-msg-closing.md";
  };
in

{
  home.packages = with pkgs; [
    beads_bin
    fabric
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    ollama
    shell-gpt
    ticket
  ];

  home.file.".claude/plugins/marketplaces/beads-marketplace".source = beads;
  home.file.".claude/plugins/marketplaces/claude-plugins-official".source = claude-plugins-official;

  home.file.".claude/plugins/known_marketplaces.json".text =
    let
      timestamp = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile buildTime);
    in
    builtins.toJSON {
      claude-plugins-official = {
        source = {
          source = "github";
          repo = "anthropics/claude-plugins-official";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/claude-plugins-official";
        lastUpdated = timestamp;
      };
      beads = {
        source = {
          source = "github";
          repo = "steveyegge/beads";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/beads-marketplace";
        lastUpdated = timestamp;
      };
    };

  programs.claude-code = {
    enable = true;
    settings = {
      alwaysThinkingEnabled = true;
      includeCoAuthoredBy = false;
      attribution = {
        commit = "";
        pr = "";
      };
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(bd --help:*)"
          "Bash(bd blocked)"
          "Bash(bd close:*)"
          "Bash(bd comments:*)"
          "Bash(bd create:*)"
          "Bash(bd dep add:*)"
          "Bash(bd dep tree:*)"
          "Bash(bd help:*)"
          "Bash(bd init:*)"
          "Bash(bd label add:*)"
          "Bash(bd list:*)"
          "Bash(bd ready:*)"
          "Bash(bd show:*)"
          "Bash(bd sync:*)"
          "Bash(bd update:*)"
          "Bash(biome check:*)"
          "Bash(biome format:*)"
          "Bash(biome lint:*)"
          "Bash(cargo build:*)"
          "Bash(cargo check:*)"
          "Bash(cargo clippy:*)"
          "Bash(cargo doc:*)"
          "Bash(cargo run:*)"
          "Bash(cargo test:*)"
          "Bash(cargo tree:*)"
          "Bash(mix compile:*)"
          "Bash(mix credo:*)"
          "Bash(mix deps.clean:*)"
          "Bash(mix deps.compile:*)"
          "Bash(mix deps.get:*)"
          "Bash(mix dump_schema:*)"
          "Bash(mix ecto.migrate:*)"
          "Bash(mix format:*)"
          "Bash(mix lint:*)"
          "Bash(mix phx.server:*)"
          "Bash(mix seed:*)"
          "Bash(mix test:*)"
          "Skill(beads:create)"
          "Skill(beads:init)"
          "Skill(beads:list)"
          "Skill(beads:show)"
          "WebFetch(domain:docs.rs)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:hexdocs.pm)"
          "WebFetch(domain:raw.githubusercontent.com)"
          "WebSearch"
        ];
      };
      theme = "dark";
      enabledPlugins = {
        "beads@beads" = true;
        "context7@claude-plugins-official" = true;
        "rust-analyzer-lsp@claude-plugins-official" = true;
      };
      disabledMcpjsonServers = [ "context7:context7" ];
      hooks = {
        PreToolUse = [
          {
            matcher = "Bash(git commit *)";
            hooks = [
              {
                type = "command";
                command = "cat ${./ai/shared/git-commit-guidelines.md}";
              }
            ];
          }
        ];
      };
    };

    memory.text = readAiDoc "memory.md";

    agents = {
    };

    rules = {
      elixir = ''
        ---
        paths:
          - "**/*.ex"
          - "**/*.exs"
        ---

        Invoke the /elixir skill and follow it exactly as presented to you
      '';
    };

    commands = {
      bd-plan-all = readAiDoc "commands/bd-plan-all.md";

      bd-execute = readAiDoc "commands/bd-execute.md";

      bd-execute-all = readAiDoc "commands/bd-execute-all.md";

      fix-pr-comments = readAiDoc "commands/fix-pr-comments.md";

      commit-msg-short = ''
        ---
        description: Write a short commit message based on context and changes to the project
        ---

        ${commitMsgCommon.intro}

        ${commitMsgCommon.writingStyle}
        ${readAiDoc "shared/commit-msg/commit-msg-short-structure.md"}

        ${commitMsgCommon.technicalDepth}
        ${commitMsgCommon.toneExamples}
        ${commitMsgCommon.antiPatterns}
        ${commitMsgCommon.specifics}
        ${commitMsgCommon.closing}
      '';

      commit-msg-detailed = ''
        ---
        description: Write a detailed commit message based on context and changes to the project
        ---

        ${commitMsgCommon.intro}

        ${commitMsgCommon.writingStyle}
        ${readAiDoc "shared/commit-msg/commit-msg-detailed-structure.md"}

        ${commitMsgCommon.technicalDepth}
        ${commitMsgCommon.toneExamples}
        ${commitMsgCommon.antiPatterns}
        ${commitMsgCommon.specifics}
        ${commitMsgCommon.closing}
      '';
    };

    skillsDir = claude-skills;
  };
}
