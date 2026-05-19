{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

let
  agent-browser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  backlog-md = inputs.backlog-md.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stop-slop = inputs.stop-slop;
  superpowers = inputs.superpowers;
  kami = inputs.kami;
  mkKamiSkill =
    brandFile:
    pkgs.runCommand "kami-skill" { } ''
      cp -r ${kami} $out
      chmod -R u+w $out
      cp ${brandFile} $out/references/brand.md
    '';
  apollo_skills = inputs.apollo_skills;
  ast-grep-skill = inputs.ast-grep-skill;
  the-elements-of-style = inputs.the-elements-of-style;
  todoist-cli-pkg = pkgs.callPackage ../../../pkgs/todoist-cli { src = inputs.todoist-cli-src; };

  ticket = pkgs.callPackage ../../../pkgs/ticket { inherit inputs; };

  claude-tail = inputs.claude-tail.packages.${pkgs.stdenv.hostPlatform.system}.default;
  rtk = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;
  basePi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  # Patch the hardcoded 30s RPC send timeout in pi-coding-agent to 5 minutes,
  # since local LLM prompt processing can take 1-2 minutes on this hardware.
  patchedPi = pkgs.runCommand "pi-patched" { } ''
    cp -r ${basePi} $out
    chmod -R u+w $out
    sed -i 's/}, 30000);$/}, 300000);/' \
      $out/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/rpc/rpc-client.js
  '';
  pi = pkgs.symlinkJoin {
    name = "pi";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ patchedPi ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_latest ]}
    '';
  };

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
  options.jeff.kamiSkillBrand = lib.mkOption {
    type = lib.types.path;
    default = ./ai/kami/brand.md;
  };

  config = {
    home.packages = with pkgs; [
      agent-browser
      backlog-md
      claude-tail
      pi
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

    home.file.".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "llama-home";
      defaultModel = "chat-mtp:thinking-coding";
      quietStartup = true;
      enabledModels = [
        "chat-mtp"
        "chat-mtp:instruct"
        "chat-mtp:thinking-coding"
        "qwen3.6-mtp:instruct-reasoning"
        "chat-27b:thinking-coding"
      ];
    };

    home.file.".pi/agent/models.json".text = builtins.toJSON {
      providers = {
        "llama-home" = {
          baseUrl = "https://llama.home.jeffutter.com/v1";
          api = "openai-completions";
          apiKey = "local";
          compat = {
            supportsDeveloperRole = false;
            supportsReasoningEffort = false;
          };
          models = [
            {
              id = "chat";
              contextWindow = 65536;
            }
            {
              id = "chat-mtp:instruct";
              reasoning = false;
              contextWindow = 65536;
            }
            {
              id = "chat:thinking-coding";
              reasoning = true;
              contextWindow = 65536;
            }
            {
              id = "chat-mtp:thinking-coding";
              reasoning = true;
              contextWindow = 65536;
            }
            {
              id = "qwen3.6-mtp:instruct-reasoning";
              reasoning = false;
              contextWindow = 65536;
            }
            {
              id = "chat-27b:thinking-coding";
              reasoning = true;
              contextWindow = 65536;
            }
          ];
        };
      };
    };

    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
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
        sandbox = {
          excludedCommands = [
            "acli jira *"
            "acli confluence *"
            "rtk gh *"
            "rtk git *"
          ];
          network = {
            allowedDomains = [
              "localhost"
              "127.0.0.1"
              "[::1]"
            ];
            allowLocalBinding = true;
          };
        };
        permissions = {
          defaultMode = "acceptEdits";
          allow = [
            "Bash(biome check:*)"
            "Bash(biome format:*)"
            "Bash(biome lint:*)"
            "Bash(acli confluence *)"
            "Bash(acli jira *)"
            "Bash(confluence-search.sh *)"
            "Bash(cargo bench:*)"
            "Bash(cargo build:*)"
            "Bash(cargo check:*)"
            "Bash(cargo clippy:*)"
            "Bash(cargo doc:*)"
            "Bash(cargo fmt:*)"
            "Bash(cargo nextest:*)"
            "Bash(cargo run:*)"
            "Bash(cargo test:*)"
            "Bash(cargo tree *)"
            "Bash(echo \"exit=$?\")"
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
            "Bash(nix eval *)"
            "Bash(nix flake check *)"
            "Bash(nix flake metadata *)"
            "Bash(rover supergraph compose *)"
            "Bash(rtk curl *)"
            "Bash(rtk find:*)"
            "Bash(rtk git:*)"
            "Bash(rtk gh:*)"
            "Bash(rtk grep:*)"
            "Bash(rtk ls:*)"
            "Bash(rtk ps *)"
            "Bash(rtk read:*)"
            "Bash(rtk wc *)"
            "Read(/private/tmp/claude-*/**)"
            "Read(/tmp/claude-*/**)"
            "Read(~/.claude/skills/**)"
            "Skill(update-config)"
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
        actual-cli = ./ai/skills/actual-cli;
        voice-dna = ./ai/skills/voice-dna;
        voice-dna-creator = ./ai/skills/voice-dna-creator;
        brainstorming = ./ai/skills/brainstorming;
        elixir = ./ai/skills/elixir;
        backlog-planner = ./ai/skills/backlog-planner;
        backlog-execute = ./ai/skills/backlog-execute;
        stop-slop = "${stop-slop}";
        writing-clearly-and-concisely = "${the-elements-of-style}/skills/writing-clearly-and-concisely";
        todoist-cli = "${todoist-cli-pkg}/share/todoist-cli/skill";
        kami = "${mkKamiSkill config.jeff.kamiSkillBrand}";
        ast-grep = "${ast-grep-skill}/ast-grep/skills/ast-grep";
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
  }; # end config
}
