{
  pkgs,
  inputs,
  config,
  ...
}:

let
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stop-slop = inputs.stop-slop;
  claude-plugins-official = inputs.claude-plugins-official;
  superpowers = inputs.superpowers;
  the-elements-of-style = inputs.the-elements-of-style;

  ticket = pkgs.callPackage ../../../pkgs/ticket { inherit inputs; };

  claude-tail = inputs.claude-tail.packages.${pkgs.stdenv.hostPlatform.system}.default;

  claude-skills = pkgs.runCommand "claude-skills" { } ''
    mkdir -p $out
    ln -s ${./ai/skills/acli} $out/acli
    ln -s ${./ai/skills/voice-dna} $out/voice-dna
    ln -s ${./ai/skills/voice-dna-creator} $out/voice-dna-creator
    ln -s ${./ai/skills/brainstorming} $out/brainstorming
    ln -s ${./ai/skills/elixir} $out/elixir
    ln -s ${./ai/skills/tk-planner} $out/tk-planner
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
    claude-tail
    fabric
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    ollama
    shell-gpt
    ticket
  ];

  home.file.".claude/plugins/marketplaces/claude-plugins-official".source = claude-plugins-official;
  home.file.".claude/plugins/marketplaces/superpowers".source = superpowers;

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
      superpowers = {
        source = {
          source = "github";
          repo = "obra/superpowers";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/superpowers";
        lastUpdated = timestamp;
      };
    };

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code-bin;
    settings = {
      alwaysThinkingEnabled = true;
      includeCoAuthoredBy = false;
      attribution = {
        commit = "";
        pr = "";
      };
      installMethod = "manual";
      skipInstallOnStartup = true;
      disableSymlinks = true;
      disableShellIntegration = true;
      env = {
        DISABLE_AUTOUPDATER = 1;
        DISABLE_INSTALLATION_CHECKS = 1;
      };
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(biome check:*)"
          "Bash(biome format:*)"
          "Bash(biome lint:*)"
          "Bash(cargo bench:*)"
          "Bash(cargo build:*)"
          "Bash(cargo check:*)"
          "Bash(cargo clippy:*)"
          "Bash(cargo doc:*)"
          "Bash(cargo fmt:*)"
          "Bash(cargo nextest:*)"
          "Bash(cargo run:*)"
          "Bash(cargo test:*)"
          "Bash(cargo tree:*)"
          "Bash(lefthook:*)"
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
          "Bash(tk:*)"
          "Read(~/.claude/skills/**)"
          "WebFetch(domain:docs.rs)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:hexdocs.pm)"
          "WebFetch(domain:raw.githubusercontent.com)"
          "WebSearch"
        ];
      };
      theme = "dark";
      enabledPlugins = {
        "context7@claude-plugins-official" = true;
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "superpowers@superpowers" = true;
      };
      disabledMcpjsonServers = [ "context7:context7" ];
      hooks = {
        SessionStart = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "${ticket}/bin/tk prime";
              }
            ];
          }
        ];
        PreCompact = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "${ticket}/bin/tk prime";
              }
            ];
          }
        ];
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
      tk-plan-all = readAiDoc "commands/tk-plan-all.md";

      tk-execute = readAiDoc "commands/tk-execute.md";

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
