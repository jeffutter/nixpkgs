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
  humanizer = inputs.humanizer;
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
  grill-me-skill = inputs.grill-me-skill;
  the-elements-of-style = inputs.the-elements-of-style;
  todoist-cli-pkg = pkgs.callPackage ../../../pkgs/todoist-cli { src = inputs.todoist-cli-src; };

  claude-tail = inputs.claude-tail.packages.${pkgs.stdenv.hostPlatform.system}.default;
  peon-ping = inputs.peon-ping.packages.${pkgs.stdenv.hostPlatform.system}.default;
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

  # Permission-prompt stats hook. capture.py and report.py are deployed together
  # to a single store path so capture.py can import report.py alongside it; the
  # scripts write their event/report data to ~/.claude/permission-stats at runtime.
  permissionStats = ./ai/permission-stats;
  permissionStatsCapture = {
    type = "command";
    command = "python3 ${permissionStats}/capture.py";
  };

  # peon-ping Claude Code hooks. We wire these declaratively instead of using the
  # module's `claudeCodeIntegration`, which mutates ~/.claude/settings.json via an
  # activation script -- incompatible here, since programs.claude-code owns that
  # file as a read-only Nix store symlink. Hooks reference the package's scripts
  # by store path, mirroring the module's own registrations.
  peonHook = "${peon-ping}/bin/peon";
  # One peon.sh hook entry. async=true matches the module for every event except
  # SessionStart; matcher is "" everywhere except PostToolUseFailure ("Bash").
  mkPeonEntry =
    {
      matcher ? "",
      async ? true,
    }:
    {
      inherit matcher;
      hooks = [
        (
          {
            type = "command";
            command = peonHook;
            timeout = 10;
          }
          // lib.optionalAttrs async { async = true; }
        )
      ];
    };
  # UserPromptSubmit also runs the /peon-ping-use and /peon-ping-rename helpers.
  peonUserPromptHelpers = {
    matcher = "";
    hooks = [
      {
        type = "command";
        command = "${peon-ping}/share/peon-ping/scripts/hook-handle-use.sh";
        timeout = 5;
      }
      {
        type = "command";
        command = "${peon-ping}/share/peon-ping/scripts/hook-handle-rename.sh";
        timeout = 5;
      }
    ];
  };
  peonSkill = name: "${peon-ping}/share/peon-ping/skills/${name}";

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
  imports = [ inputs.peon-ping.homeManagerModules.default ];

  options.jeff.kamiSkillBrand = lib.mkOption {
    type = lib.types.path;
    default = ./ai/kami/brand.md;
  };

  # rtk rewrites Bash commands via a PreToolUse hook. Disabled on hosts where
  # rtk's command rewriting is unwanted (e.g. the work machine).
  options.jeff.enableRtkHooks = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  # Claude Code voice mode. Enabled only on hosts with physical access (local
  # laptops/desktops); left off on remote/headless machines where audio is
  # unwanted.
  options.jeff.enableClaudeVoice = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = {
    home.packages = with pkgs; [
      agent-browser
      backlog-md
      claude-tail
      pi
      rtk
      peon-ping
      #fabric
      (llm.withPlugins {
        llm-cmd = true;
        llm-jq = true;
      })
      # shell-gpt
    ];

    home.file.".claude/plugins/marketplaces/superpowers".source = superpowers;

    home.file.".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "llama-home";
      defaultModel = "chat:thinking-coding";
      quietStartup = true;
      enabledModels = [
        "anthropic/claude-opus-4.8"
        "anthropic/claude-sonnet-4.6"
        "chat"
        "chat-27b:thinking"
        "chat-27b:thinking-coding"
        "chat:instruct"
        "chat:thinking-coding"
        "deepseek/deepseek-v4-flash"
        "deepseek/deepseek-v4-pro"
        "moonshotai/kimi-k2.6"
        "qwen/qwen3.7-max"
        "qwen3.6:instruct-reasoning"
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
              contextWindow = 131072;
            }
            {
              id = "chat:thinking-coding";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "qwen3.6:instruct-reasoning";
              reasoning = false;
              contextWindow = 131072;
            }
            {
              id = "chat-27b:thinking-coding";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "chat-27b:thinking";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "deepseek/deepseek-v4-flash";
              reasoning = true;
              contextWindow = 524288;
            }
            {
              id = "deepseek/deepseek-v4-pro";
              reasoning = true;
              contextWindow = 524288;
            }
            {
              id = "moonshotai/kimi-k2.6";
              reasoning = true;
              contextWindow = 262144;
            }
            {
              id = "qwen/qwen3.7-max";
              reasoning = true;
              contextWindow = 524288;
            }
            {
              id = "anthropic/claude-sonnet-4.6";
              reasoning = true;
              contextWindow = 524288;
            }
            {
              id = "anthropic/claude-opus-4.8";
              reasoning = true;
              contextWindow = 524288;
            }
          ];
        };
      };
    };

    # peon-ping: game-character voice lines / overlays on Claude Code events.
    # claudeCodeIntegration is left off so this module only manages ~/.openpeon
    # (config + packs); the Claude hooks themselves are declared in
    # programs.claude-code.settings.hooks below. Shell integration is off because
    # this repo uses fish (the package's fish completions load via home.packages).
    programs.peon-ping = {
      enable = true;
      package = peon-ping;
      claudeCodeIntegration = false;
      enableZshIntegration = false;
      enableBashIntegration = false;
      installPacks = [
        "peon"
        "clean_chimes"
        {
          name = "cute_ui";
          src = pkgs.fetchFromGitHub {
            owner = "TechPdM";
            repo = "openpeon-cute-minimal";
            rev = "v1.0.1";
            sha256 = "sha256-+ieyEOyPcPshOYxVJLhLm/L71Rjarqld7Gpx73MTG7M=";
          };
        }
      ];
      settings = {
        default_pack = "cute_ui";
        volume = 0.3;
        enabled = true;
        desktop_notifications = true;
        notification_style = "standard";
      };
    };

    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
      settings = {
        alwaysThinkingEnabled = true;
        attribution = {
          commit = "";
          pr = "";
        };
        disableShellIntegration = true;
        disableSymlinks = true;
        disableWorkflows = false;
        enableWorkflows = true;
        env = {
          DISABLE_AUTOUPDATER = 1;
          DISABLE_INSTALLATION_CHECKS = 1;
        };
        includeCoAuthoredBy = false;
        installMethod = "manual";
        skipInstallOnStartup = true;
        sandbox = {
          excludedCommands = [
            "acli confluence *"
            "acli jira *"
            "nix eval *"
            "rtk cargo *"
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
            "Bash(biome check *)"
            "Bash(biome format *)"
            "Bash(biome lint *)"
            "Bash(acli confluence *)"
            "Bash(acli jira *)"
            "Bash(confluence-search.sh *)"
            "Bash(cargo bench *)"
            "Bash(cargo build *)"
            "Bash(cargo check *)"
            "Bash(cargo clippy *)"
            "Bash(cargo doc *)"
            "Bash(cargo fmt *)"
            "Bash(cargo nextest *)"
            "Bash(cargo run *)"
            "Bash(cargo test *)"
            "Bash(cargo tree *)"
            "Bash(echo \"exit=$?\")"
            "Bash(lefthook *)"
            "Bash(mix compile *)"
            "Bash(mix credo *)"
            "Bash(mix deps.clean *)"
            "Bash(mix deps.compile *)"
            "Bash(mix deps.get *)"
            "Bash(mix dump_schema *)"
            "Bash(mix ecto.migrate *)"
            "Bash(mix format *)"
            "Bash(mix lint *)"
            "Bash(mix phx.server *)"
            "Bash(mix seed *)"
            "Bash(mix test *)"
            "Bash(nix eval *)"
            "Bash(nix flake check *)"
            "Bash(nix flake metadata *)"
            "Bash(nix fmt *)"
            "Bash(rover supergraph compose *)"
            "Bash(rtk curl *)"
            "Bash(rtk find *)"
            "Bash(rtk git *)"
            "Bash(rtk gh *)"
            "Bash(rtk grep *)"
            "Bash(rtk ls *)"
            "Bash(rtk ps *)"
            "Bash(rtk read *)"
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
          PreToolUse =
            (lib.optional config.jeff.enableRtkHooks {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "${rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
                }
              ];
            })
            ++ [
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
          PermissionRequest = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ];
          PermissionDenied = [ { hooks = [ permissionStatsCapture ]; } ];
          PostToolUse = [ { hooks = [ permissionStatsCapture ]; } ];
          PostToolUseFailure = [ (mkPeonEntry { matcher = "Bash"; }) ];
          UserPromptSubmit = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
            peonUserPromptHelpers
          ];
          Stop = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ];
          SessionStart = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { async = false; })
          ];
          SessionEnd = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ];
          SubagentStart = [ (mkPeonEntry { }) ];
          Notification = [ (mkPeonEntry { }) ];
          PreCompact = [ (mkPeonEntry { }) ];
        };
      }
      // lib.optionalAttrs config.jeff.enableClaudeVoice {
        voice = {
          enabled = true;
          mode = "hold";
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
        peon-ping-config = peonSkill "peon-ping-config";
        peon-ping-log = peonSkill "peon-ping-log";
        peon-ping-rename = peonSkill "peon-ping-rename";
        peon-ping-toggle = peonSkill "peon-ping-toggle";
        peon-ping-use = peonSkill "peon-ping-use";
        stop-slop = "${stop-slop}";
        humanizer = "${humanizer}";
        writing-clearly-and-concisely = "${the-elements-of-style}/skills/writing-clearly-and-concisely";
        todoist-cli = "${todoist-cli-pkg}/share/todoist-cli/skill";
        agent-browser = "${agent-browser}/share/agent-browser/skills/agent-browser";
        kami = "${mkKamiSkill config.jeff.kamiSkillBrand}";
        ast-grep = "${ast-grep-skill}/ast-grep/skills/ast-grep";
        grill-me = "${grill-me-skill}/skills/productivity/grill-me";
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
