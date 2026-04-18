{
  pkgs,
  inputs,
  config,
  ...
}:

let
  backlog-md = inputs.backlog-md.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stop-slop = inputs.stop-slop;
  superpowers = inputs.superpowers;
  apollo_skills = inputs.apollo_skills;
  the-elements-of-style = inputs.the-elements-of-style;

  ticket = pkgs.callPackage ../../../pkgs/ticket { inherit inputs; };

  claude-tail = inputs.claude-tail.packages.${pkgs.stdenv.hostPlatform.system}.default;
  rtk = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;

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
    backlog-md
    claude-tail
    rtk
    #fabric
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    # shell-gpt
    ticket
  ];

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
          "Bash(rtk find:*)"
          "Bash(rtk grep:*)"
          "Bash(rtk git:*)"
          "Bash(rtk ls:*)"
          "Bash(rtk read:*)"
          "Read(~/.claude/skills/**)"
          "WebFetch(domain:docs.rs)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:hexdocs.pm)"
          "WebFetch(domain:home-manager-options.extananteous.xyz)"
          "WebFetch(domain:home-manager-options.extranix.com)"
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
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "${rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
              }
            ];
          }
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

    context = readAiDoc "context.md";

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

    # skillsDir = claude-skills;
    skills = {
      acli = ./ai/skills/acli;
      voice-dna = ./ai/skills/voice-dna;
      voice-dna-creator = ./ai/skills/voice-dna-creator;
      brainstorming = ./ai/skills/brainstorming;
      elixir = ./ai/skills/elixir;
      tk-planner = ./ai/skills/tk-planner;
      stop-slop = "${stop-slop}";
      writing-clearly-and-concisely = "${the-elements-of-style}/skills/writing-clearly-and-concisely";
    }
    // builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = apollo_skills + "/skills/${name}";
        })
        (
          builtins.filter (name: (builtins.readDir (apollo_skills + "/skills")).${name} == "directory") (
            builtins.attrNames (builtins.readDir (apollo_skills + "/skills"))
          )
        )
    );
  };
}
