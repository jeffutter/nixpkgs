{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

let
  agent-browser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  backlog-md =
    (inputs.backlog-md.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs
      (old: {
        # The upstream flake overlays `bun` on x86_64-linux with a prebuilt
        # "baseline" (SSE4.2) release to support older CPUs without AVX2. That
        # baseline build's `bun build --compile` output is corrupt: the
        # resulting binary segfaults inside glibc's dynamic linker (dl_main)
        # before any of backlog's code runs, regardless of buildPhase. Our
        # CPUs have AVX2, so build with nixpkgs' regular bun instead.
        nativeBuildInputs = map (
          drv: if (drv.pname or null) == "bun" then pkgs.bun else drv
        ) old.nativeBuildInputs;
      });
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
  excalidraw-diagram-skill = inputs.excalidraw-diagram-skill;
  # The upstream skill renders diagrams to PNG (for visual self-validation) via a
  # `uv sync` + `playwright install chromium` flow that needs network access and a
  # first-time setup step. Replace it with a Nix-provided renderer: Python with the
  # Playwright package plus a version-matched Chromium, wrapped so the agent just
  # calls `references/render <file.excalidraw>` with no setup.
  excalidraw-python = pkgs.python3.withPackages (ps: [ ps.playwright ]);
  excalidraw-diagram-skill-wrapped =
    pkgs.runCommand "excalidraw-diagram-skill" { nativeBuildInputs = [ pkgs.makeWrapper ]; }
      ''
              cp -r ${excalidraw-diagram-skill} $out
              chmod -R u+w $out

              makeWrapper ${excalidraw-python}/bin/python3 $out/references/render \
                --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers} \
                --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS 1 \
                --add-flags $out/references/render_excalidraw.py

              # Pin the Excalidraw library the render template loads from esm.sh. The
              # unpinned "latest" resolves to a build that externalizes a transitive dep
              # (@braintree/sanitize-url) to a URL that 404s, breaking every render; a
              # pinned version bundles it inline.
              substituteInPlace $out/references/render_template.html \
                --replace-fail \
                  '@excalidraw/excalidraw?bundle' \
                  '@excalidraw/excalidraw@0.18.0?bundle'

              substituteInPlace $out/SKILL.md \
                --replace-fail \
                  'cd .claude/skills/excalidraw-diagram/references && uv run python render_excalidraw.py <path-to-file.excalidraw>' \
                  '~/.claude/skills/excalidraw-diagram/references/render <path-to-file.excalidraw>'

              substituteInPlace $out/SKILL.md \
                --replace-fail \
                  'cd .claude/skills/excalidraw-diagram/references
        uv sync
        uv run playwright install chromium' \
                  '# Preinstalled via Nix (home-manager) — no setup required.
        # references/render bundles Python, Playwright, and a matching Chromium.'
      '';
  the-elements-of-style = inputs.the-elements-of-style;
  # nixpkgs' todoist-cli ships only the `td` binary, not a static skill file;
  # v1.75.2+ generates SKILL.md on demand from bundled content. Call the
  # generator directly rather than `td skill install`: the full CLI entrypoint
  # makes a startup network call that hangs under the Nix build sandbox.
  todoist-cli-skill = pkgs.runCommand "todoist-cli-skill" { } ''
    mkdir -p $out
    ${pkgs.nodejs}/bin/node --input-type=module -e '
      import { generateSkillFile } from "${pkgs.todoist-cli}/lib/node_modules/@doist/todoist-cli/dist/lib/skills/create-installer.js";
      import { writeFileSync } from "node:fs";
      writeFileSync(process.env.out + "/SKILL.md", generateSkillFile());
    '
  '';

  claude-tail = inputs.claude-tail.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdrConfig = {
    onboarding = false;
    theme = {
      name = "tokyo-night";
      auto_switch = false;
    };
    ui = {
      agent_panel_sort = "spaces";
      show_agent_labels_on_pane_borders = true;
      toast.delivery = "herdr";
    };
    keys = {
      prefix = "ctrl+a";
      open_worktree = "prefix+shift+o";
      remove_worktree = "prefix+alt+d";
      focus_agent = "prefix+alt+1..9";
      command = [
        {
          # open in a split beside your work
          key = "prefix+f";
          type = "shell";
          command = "herdr plugin action invoke open-file-viewer --plugin herdr-file-viewer";
        }
        {
          # ...or in its own tab
          key = "prefix+shift+f";
          type = "shell";
          command = "herdr plugin action invoke open-file-viewer-tab --plugin herdr-file-viewer";
        }
        {
          # <plugin_id>.<action_id> -- note the id, not the name
          key = "cmd+r";
          type = "plugin_action";
          command = "persiyanov.reviewr.toggle";
        }
      ];
    };
  };
  moshi-hook = pkgs.callPackage ../../../pkgs/moshi-hook { };
  # herdr ships its agent skill as a single SKILL.md at the repo root rather
  # than a dedicated skill package; lift just that file into its own skill
  # derivation so it tracks whatever version the herdr flake input is pinned to.
  herdr-skill = pkgs.runCommand "herdr-skill" { } ''
    mkdir -p $out
    cp ${inputs.herdr}/SKILL.md $out/SKILL.md
  '';
  peon-ping = inputs.peon-ping.packages.${pkgs.stdenv.hostPlatform.system}.default;
  rtk = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;
  basePi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  # Patch the hardcoded 30s RPC send timeout in pi-coding-agent to 10 minutes,
  # since local LLM prompt processing can take 1-2 minutes on this hardware.
  #
  # pi ships as a single `bun compile`d executable (libexec/pi/pi) rather than
  # an npm-installed JS tree, so the bundled source can't be edited as a
  # separate file -- it's embedded as a text blob inside the binary. Patching
  # it in place must preserve the exact byte length of the match, or it
  # shifts every offset after it and corrupts bun's embedded-bundle trailer.
  # `6e5` + 2 padding spaces is byte-for-byte the same length as `30000`
  # (whitespace before `)` is insignificant to JS), so the replacement is
  # size-preserving. Verified this produces a working binary (`--help`,
  # `--version` both run) with only the targeted bytes changed.
  patchedPi = pkgs.runCommand "pi-patched" { } ''
    cp -r ${basePi} $out
    chmod -R u+w $out
    LC_ALL=C sed -i 's/}, 30000);/}, 6e5  );/' $out/libexec/pi/pi
  '';
  pi = pkgs.symlinkJoin {
    name = "pi";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ patchedPi ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_latest ]} \
        --run 'if [ -z "$LITELLM_KEY" ]; then op whoami > /dev/null 2>&1 || eval $(op signin); export LITELLM_KEY="$(op read '"'"'op://Private/litellm-pi/notesPlain'"'"')"; fi'
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
    command = "${pkgs.python3}/bin/python3 ${permissionStats}/capture.py";
  };

  # Claude Code hooks `moshi-hook install` would normally write into
  # ~/.claude/settings.json itself. The event/matcher/async shape is read back
  # from the derivation's passthru.agentConfigs (see pkgs/moshi-hook) so it
  # tracks whatever this binary's template actually emits -- that file can't
  # be mutated at activation time since programs.claude-code owns
  # ~/.claude/settings.json as a read-only Nix store symlink, same constraint
  # as the peon-ping/herdr hooks below. `command` is rebuilt with a proper Nix
  # interpolation rather than kept from the parsed JSON: this Nix keeps
  # store-path context on strings read via readFile, and builtins.fromJSON
  # refuses any string carrying it -- so context is stripped before parsing
  # (safe here since matcher/async/type are plain non-path strings and
  # `command` is unconditionally replaced below with a value that does carry
  # proper context back to the moshi-hook package).
  moshiHookClaudeCommand = "'${moshi-hook}/bin/moshi-hook' claude-hook";
  moshiClaudeHooks =
    lib.mapAttrs
      (
        _event: groups:
        map (
          group: group // { hooks = map (h: h // { command = moshiHookClaudeCommand; }) group.hooks; }
        ) groups
      )
      (
        builtins.fromJSON (
          builtins.unsafeDiscardStringContext (
            builtins.readFile "${moshi-hook.passthru.agentConfigs}/claude-hooks.json"
          )
        )
      );

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
      herdr
      moshi-hook
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

    # Symlink the permission-stats scripts into their data dir so they can be run
    # directly (e.g. `~/.claude/permission-stats/report.py --daily`) while always
    # tracking the current build. capture.py imports report.py from its own dir;
    # both being symlinks in the same dir keeps that import working. The dir also
    # holds runtime events/ and reports/, which home-manager leaves untouched.
    home.file.".claude/permission-stats/capture.py".source = "${permissionStats}/capture.py";
    home.file.".claude/permission-stats/report.py".source = "${permissionStats}/report.py";

    xdg.configFile."herdr/config.toml".source =
      (pkgs.formats.toml { }).generate "herdr-config.toml"
        herdrConfig;

    # `herdr integration install pi`/`claude` would normally drop these files
    # itself and (for claude) rewrite settings.json to add the SessionStart
    # hook below. That rewrite can't run here since programs.claude-code owns
    # settings.json as a read-only Nix store symlink, so both halves are
    # reproduced declaratively instead: the asset files come straight from
    # herdr's source tree (kept in sync by bumping the herdr flake input), and
    # the hook wiring lives alongside our other SessionStart hooks below.
    home.file.".pi/agent/extensions/herdr-agent-state.ts".source =
      "${inputs.herdr}/src/integration/assets/pi/herdr-agent-state.ts";

    home.file.".claude/hooks/herdr-agent-state.sh" = {
      source = "${inputs.herdr}/src/integration/assets/claude/herdr-agent-state.sh";
      executable = true;
    };

    # moshi-hook's pi extension: same "reproduced declaratively" situation as
    # herdr above, except there's no source tree to point at -- the file is
    # rendered by the moshi-hook binary itself, so it's captured at build time
    # instead (see pkgs/moshi-hook's passthru.agentConfigs). The corresponding
    # Claude Code hooks are spliced into programs.claude-code.settings.hooks
    # below via moshiClaudeHooks.
    home.file.".pi/agent/extensions/moshi-hooks.ts".source =
      "${moshi-hook.passthru.agentConfigs}/pi-extension.ts";

    home.file.".pi/agent/extensions/pi-continue.json".text = builtins.toJSON {
      reasoning = false;
      summarizerModel = "instruct";
    };

    # pi-continue (and other extensions) declare @earendil-works/pi-coding-agent
    # as a peerDependency, resolved at runtime via `import.meta.resolve`. Extensions
    # live under ~/.pi/agent/npm{,2,3}/node_modules, which pi manages itself via
    # `npm install` against its own package-lock.json -- that peer is never
    # installed there since it isn't published to npm; it's meant to be the host
    # CLI. Node's ESM resolver walks every ancestor node_modules directory, so
    # placing a symlink one level up, at ~/.pi/agent/node_modules (outside the
    # npm-managed tree, safe from `pi`'s own installs pruning it), makes it
    # resolvable for every extension underneath. Points at patchedPi rather than
    # the `pi` package's own store path so it always matches whatever pi version
    # this config actually installs.
    home.file.".pi/agent/node_modules/@earendil-works/pi-coding-agent".source =
      "${patchedPi}/lib/node_modules/@earendil-works/pi-coding-agent";

    home.file.".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "litellm-home";
      defaultModel = "coding";
      quietStartup = true;
      enabledModels = [
        "chat"
        "coding"
        "instruct"
        "instruct-reasoning"
        "planning"
        "research"
      ];
      packages = [
        "npm:@gotgenes/pi-permission-system"
        "npm:@gotgenes/pi-subagents"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:@juicesharp/rpiv-todo"
        "npm:@quintinshaw/pi-dynamic-workflows"
        "npm:@samfp/pi-memory"
        "npm:pi-bar"
        "npm:pi-continue"
        "npm:pi-intercom"
        "npm:pi-lens"
        "npm:pi-mcp-adapter"
        "npm:pi-rtk-optimizer"
        "npm:pi-simplify"
        "npm:pi-tool-display"
        "npm:pi-web-access"
      ];
      skills = [
        "~/.claude/skills"
      ];
      compaction = {
        enabled = true;
        reserveTokens = 16384;
        keepRecentTokens = 15000;
      };
      theme = "dark";
    };

    home.file.".pi/agent/models.json".text = builtins.toJSON {
      providers = {
        "litellm-home" = {
          baseUrl = "https://litellm.home.jeffutter.com/v1";
          api = "openai-completions";
          apiKey = "$LITELLM_KEY";
          compat = {
            supportsDeveloperRole = false;
            supportsReasoningEffort = false;
          };
          models = [
            {
              id = "chat";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "coding";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "instruct";
              reasoning = false;
              contextWindow = 131072;
            }
            {
              id = "instruct-reasoning";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "planning";
              reasoning = true;
              contextWindow = 131072;
            }
            {
              id = "research";
              reasoning = true;
              contextWindow = 131072;
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
            "nix build *"
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
        tui = "fullscreen";
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
            ]
            ++ (moshiClaudeHooks.PreToolUse or [ ]);
          PermissionRequest = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ]
          ++ (moshiClaudeHooks.PermissionRequest or [ ]);
          PermissionDenied = [ { hooks = [ permissionStatsCapture ]; } ];
          PostToolUse = [ { hooks = [ permissionStatsCapture ]; } ] ++ (moshiClaudeHooks.PostToolUse or [ ]);
          PostToolUseFailure = [ (mkPeonEntry { matcher = "Bash"; }) ];
          UserPromptSubmit = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
            peonUserPromptHelpers
          ]
          ++ (moshiClaudeHooks.UserPromptSubmit or [ ]);
          Stop = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ]
          ++ (moshiClaudeHooks.Stop or [ ]);
          SessionStart = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { async = false; })
            {
              matcher = "*";
              hooks = [
                {
                  type = "command";
                  command = "bash '${config.home.homeDirectory}/.claude/hooks/herdr-agent-state.sh' session";
                  timeout = 10;
                }
              ];
            }
          ]
          ++ (moshiClaudeHooks.SessionStart or [ ]);
          SessionEnd = [
            { hooks = [ permissionStatsCapture ]; }
            (mkPeonEntry { })
          ]
          ++ (moshiClaudeHooks.SessionEnd or [ ]);
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
        agent-browser = "${agent-browser}/share/agent-browser/skills/agent-browser";
        ast-grep = "${ast-grep-skill}/ast-grep/skills/ast-grep";
        backlog-execute = ./ai/skills/backlog-execute;
        backlog-planner = ./ai/skills/backlog-planner;
        brainstorming = ./ai/skills/brainstorming;
        elixir = ./ai/skills/elixir;
        excalidraw-diagram = "${excalidraw-diagram-skill-wrapped}";
        grill-me = "${grill-me-skill}/skills/productivity/grill-me";
        herdr = "${herdr-skill}";
        humanizer = "${humanizer}";
        kami = "${mkKamiSkill config.jeff.kamiSkillBrand}";
        peon-ping-config = peonSkill "peon-ping-config";
        peon-ping-log = peonSkill "peon-ping-log";
        peon-ping-rename = peonSkill "peon-ping-rename";
        peon-ping-toggle = peonSkill "peon-ping-toggle";
        peon-ping-use = peonSkill "peon-ping-use";
        review-pi-work = ./ai/skills/review-pi-work;
        stop-slop = "${stop-slop}";
        todoist-cli = "${todoist-cli-skill}";
        voice-dna = ./ai/skills/voice-dna;
        voice-dna-creator = ./ai/skills/voice-dna-creator;
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
  }; # end config
}
