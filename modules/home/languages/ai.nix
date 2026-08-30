{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

let
  agent-browser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  backlog-md-upstream = inputs.backlog-md.packages.${pkgs.stdenv.hostPlatform.system}.default;
  backlog-md =
    # The upstream flake overlays `bun` on x86_64-linux with a prebuilt
    # "baseline" (SSE4.2) release to support older CPUs without AVX2. That
    # baseline build's `bun build --compile` output is corrupt: the
    # resulting binary segfaults inside glibc's dynamic linker (dl_main)
    # before any of backlog's code runs, regardless of buildPhase. Our
    # CPUs have AVX2, so build with nixpkgs' regular bun instead. This only
    # affects x86_64-linux; elsewhere use the pristine upstream package so we
    # don't churn the derivation hash for no reason.
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      backlog-md-upstream.overrideAttrs (old: {
        nativeBuildInputs = map (
          drv: if (drv.pname or null) == "bun" then pkgs.bun else drv
        ) old.nativeBuildInputs;
      })
    else
      backlog-md-upstream;
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
  # litellm-home's reasoning-capable models only accept these three effort values —
  # everything else (off, minimal, high, max) is clamped/hidden by pi rather than sent upstream.
  reasoningThinkingLevelMap = {
    off = null;
    minimal = null;
    low = "low";
    medium = "medium";
    high = null;
    xhigh = "xhigh";
    max = null;
  };
  ast-grep-skill = inputs.ast-grep-skill;
  matt-pocock-skills = inputs.matt-pocock-skills;
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

  # worktrunk's Claude Code plugin (skills + activity-tracking hooks), lifted
  # out of its plugin packaging so the hooks run directly (no
  # $CLAUDE_PLUGIN_ROOT / enabledPlugins) alongside our other declarative
  # hook wiring below -- programs.claude-code.settings.hooks is the only
  # place hooks are actually installed to ~/.claude/settings.json.
  worktrunkPluginRoot = "${inputs.worktrunk-plugin}/plugins/worktrunk";
  worktrunkHookScript = "${worktrunkPluginRoot}/hooks/wt.sh";
  worktrunkMarkerCommand =
    marker: ''bash "${worktrunkHookScript}" config state marker set ${marker} || true'';
  worktrunkClearCommand = ''bash "${worktrunkHookScript}" config state marker clear || true'';

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
      # open_worktree = "prefix+shift+o";
      # remove_worktree = "prefix+alt+d";
      focus_agent = "prefix+alt+1..9";
      next_agent = "prefix+N";
      previous_agent = "prefix+P";
      command = [
        {
          # open in a split beside your work
          key = "prefix+f";
          type = "shell";
          command = "herdr plugin action invoke open-file-viewer --plugin herdr-file-viewer";
          description = "File Vewer: Open";
        }
        {
          # ...or in its own tab
          key = "prefix+shift+f";
          type = "shell";
          command = "herdr plugin action invoke open-file-viewer-tab --plugin herdr-file-viewer";
          description = "File Vewer: Open Tab";
        }
        {
          # <plugin_id>.<action_id> -- note the id, not the name
          key = "cmd+r";
          type = "plugin_action";
          command = "persiyanov.reviewr.toggle";
          description = "Reviewer: Toggle";
        }
        {
          # override herdr's built-in "new worktree" key with worktrunk's
          # default-branch switch/create picker
          key = "prefix+shift+g";
          type = "plugin_action";
          command = "worktrunk.open";
          description = "Worktree: switch / create from default branch";
        }
        {
          key = "prefix+shift+c";
          type = "plugin_action";
          command = "worktrunk.open-current";
          description = "Worktree: switch / create from current branch";
        }
        {
          key = "prefix+shift+d";
          type = "plugin_action";
          command = "worktrunk.remove";
          description = "Worktree: remove";
        }
      ];
    };
  };
  moshi-hook = pkgs.callPackage ../../../pkgs/moshi-hook { };
  # `herdr --skill` prints herdr's bundled agent skill file and is the
  # documented extraction point for this (see `herdr --help`); prefer it over
  # reading the skill file out of the source tree directly, since that
  # in-tree path has already moved once across herdr releases (root
  # SKILL.md -> skills/herdr/SKILL.md as of v0.8.0) while the CLI flag is a
  # stable contract.
  herdr-skill = pkgs.runCommand "herdr-skill" { } ''
    mkdir -p $out
    ${herdr}/bin/herdr --skill > $out/SKILL.md
  '';
  rtk = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;
  basePi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  pi = pkgs.symlinkJoin {
    name = "pi";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ basePi ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_latest ]} \
        --run 'if [ -z "$LITELLM_KEY" ]; then op whoami > /dev/null 2>&1 || eval $(op signin); export LITELLM_KEY="$(op read '"'"'op://Private/litellm-pi/notesPlain'"'"')"; fi'
    '';
  };

  # llm-agents.nix's `pi` package derivation deliberately deletes `$out/lib`
  # after compiling the standalone binary (all modules are embedded in it),
  # so there's no npm-style dist+node_modules tree left in the store to
  # symlink for the `@earendil-works/pi-coding-agent` peer below (see that
  # symlink's comment). `useBun = false` is that derivation's own switch for
  # building the plain Node entry point instead: it skips the bun-compile
  # preInstall, the lib-deleting postInstall, and the rcodesign postFixup all
  # at once, leaving buildNpmPackage's default install phase to land a real
  # `lib/node_modules/@earendil-works/pi-coding-agent` in the store, complete
  # with its resolved node_modules. Those matter here: pi-continue's
  # dist/core/compaction/*.js transitively imports several of
  # pi-coding-agent's own npm deps (cross-spawn, diff, chalk, ...) at
  # module-load time, so a bare copy of `dist/` alone isn't enough -- Node's
  # resolver needs those deps sitting in an ancestor node_modules too.
  #
  # Prefer this over clearing phases with overrideAttrs: that has to be kept
  # in sync by hand every time upstream adds a phase to the bun path, and it
  # already broke once when postFixup's rcodesign step appeared and tried to
  # sign a libexec/pi/pi this build never produces.
  piCodingAgentDist =
    (basePi.override { useBun = false; }) + "/lib/node_modules/@earendil-works/pi-coding-agent";

  # Teaches Claude Code to write pi skills (SKILL.md) and pi extensions
  # (TypeScript). Rather than hand-transcribing pi's skill/extension format into
  # this repo -- which would silently drift out of sync every time pi's API
  # changes -- bundle the docs and example extensions straight out of
  # piCodingAgentDist, so this skill always reflects whatever pi version
  # `inputs.llm-agents` is pinned to. The only sync step is bumping that input.
  pi-authoring-skill = pkgs.runCommand "pi-authoring-skill" { } ''
        mkdir -p $out/references
        cp ${piCodingAgentDist}/docs/skills.md $out/references/skills.md
        cp ${piCodingAgentDist}/docs/extensions.md $out/references/extensions.md
        cp ${piCodingAgentDist}/docs/sdk.md $out/references/sdk.md
        cp -r ${piCodingAgentDist}/examples/extensions $out/references/example-extensions
        cp -r ${piCodingAgentDist}/examples/sdk $out/references/example-sdk
        chmod -R u+w $out

        cat > $out/SKILL.md <<'SKILLEOF'
    ---
    name: pi-authoring
    description: >-
      Write or edit skills and extensions for pi (the pi.dev/earendil-works coding
      agent) -- SKILL.md files under .pi/skills, ~/.pi/agent/skills, or a pi
      package's skills/ directory, and TypeScript extensions under
      .pi/extensions or ~/.pi/agent/extensions. Use whenever the user asks to
      create, modify, or debug a pi skill or pi extension, or asks how pi's
      skill/extension system works.
    ---

    # Authoring pi Skills and Extensions

    pi's skill format is the same Agent Skills standard Claude Code itself uses
    (a `SKILL.md` with YAML frontmatter: `name`, `description`, optional
    `allowed-tools`, progressive disclosure of the body). `references/skills.md`
    covers pi's specific deltas: discovery locations
    (`~/.pi/agent/skills/`, `.pi/skills/`, `.agents/skills/`, package
    `skills/` dirs), the root-`.md`-file shortcut in the first two, and naming
    validation rules.

    pi extensions have no external standard -- they're a pi-specific TypeScript
    API (lifecycle event subscriptions, custom tool registration, `ctx.reload()`,
    etc.) that changes across pi releases. Before writing or editing one, always
    read `references/extensions.md` and skim 2-3 relevant files under
    `references/example-extensions/` for the current API shape -- do not rely on
    prior/memorized knowledge of pi's extension API, since these reference files
    are refreshed to match whatever pi version is actually installed and prior
    knowledge may be stale.

    If the task involves pi's SDK (`@earendil-works/pi-coding-agent` used
    programmatically, not the CLI) instead of a CLI extension, read
    `references/sdk.md` and `references/example-sdk/` instead.
    SKILLEOF
  '';

  # Helper function to read markdown files from the ai directory
  readAiDoc = file: builtins.readFile (./ai + "/${file}");

  # The global context file every agent harness gets, assembled per harness:
  # a shared core (design bias, working preferences) behind an environment
  # preamble naming that harness's own nix-managed paths. Claude Code reads it
  # as ~/.claude/CLAUDE.md, pi as ~/.pi/agent/AGENTS.md.
  mkAgentContext = env: readAiDoc "context/${env}" + "\n" + readAiDoc "context/core.md";

  # Claude Code hooks `moshi-hook install` would normally write into
  # ~/.claude/settings.json itself. The event/matcher/async shape is read back
  # from the derivation's passthru.agentConfigs (see pkgs/moshi-hook) so it
  # tracks whatever this binary's template actually emits -- that file can't
  # be mutated at activation time since programs.claude-code owns
  # ~/.claude/settings.json as a read-only Nix store symlink, same constraint
  # as the herdr hooks below. `command` is rebuilt with a proper Nix
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
      (llm.withPlugins {
        llm-cmd = true;
        llm-jq = true;
      })
    ];

    home.file.".claude/plugins/marketplaces/superpowers".source = superpowers;

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

    # Ralph: autonomous backlog-churning loop (`/ralph`). Originally authored inside
    # gql-fiddle's own .pi/extensions/ralph, promoted here so it loads for every
    # project instead of just that one -- source lives at ./ai/pi-extensions/ralph
    # and is edited in place in this repo going forward. Its session state
    # (state.json, history.jsonl) is written to ~/.pi/agent/ralph/<project>, not
    # anywhere under this store path, so this symlink being read-only is fine.
    home.file.".pi/agent/extensions/ralph/index.ts".source = ./ai/pi-extensions/ralph/index.ts;

    # worker-heartbeat.ts: ralph's worker-side liveness companion (see its own header). Loaded
    # via -e into ralph's long-running headless steps; each intercom ping the worker sends
    # touches a nonce-scoped heartbeat file that the orchestrator polls to reset the step's
    # deadline, so slow-but-alive workers aren't killed by the wall-clock phase timeout.
    home.file.".pi/agent/extensions/ralph/worker-heartbeat.ts".source =
      ./ai/pi-extensions/ralph/worker-heartbeat.ts;

    # unblocked-todo.sh: finds backlog.md tasks whose dependencies are all Done, used by
    # ralph's choose/promote steps (see UNBLOCKED_TODO_SCRIPT in index.ts). Deployed next to
    # the extension rather than living inside each project's own backlog/ directory, since
    # ralph now loads globally; the script cds into the target project's backlog/ itself
    # rather than locating it via its own path.
    home.file.".pi/agent/extensions/ralph/unblocked-todo.sh" = {
      source = ./ai/pi-extensions/ralph/unblocked-todo.sh;
      executable = true;
    };

    # clear-alias: aliases /clear to /new. Same "promoted to load globally"
    # situation as ralph above -- source lives at ./ai/pi-extensions/clear-alias.ts
    # and is edited in place in this repo going forward.
    home.file.".pi/agent/extensions/clear-alias.ts".source = ./ai/pi-extensions/clear-alias.ts;

    # command-history: cross-session command history for pi's editor (up/down
    # arrow recall across sessions), mirroring Claude Code's behavior. Same
    # "promoted to load globally" situation as ralph above -- source lives at
    # ./ai/pi-extensions/command-history and is edited in place in this repo
    # going forward. Its state (command-history.json) is written to
    # ~/.pi/agent/, not anywhere under this store path, so this symlink being
    # read-only is fine.
    home.file.".pi/agent/extensions/command-history/index.ts".source =
      ./ai/pi-extensions/command-history/index.ts;
    home.file.".pi/agent/extensions/command-history/history-manager.ts".source =
      ./ai/pi-extensions/command-history/history-manager.ts;
    home.file.".pi/agent/extensions/command-history/history-editor.ts".source =
      ./ai/pi-extensions/command-history/history-editor.ts;
    home.file.".pi/agent/extensions/command-history/README.md".source =
      ./ai/pi-extensions/command-history/README.md;

    # pi-permission-system's global config (its permission rules) -- edited in
    # place at ./ai/pi-extensions/pi-permission-system/config.json going
    # forward rather than imperatively at ~/.pi/agent/extensions/pi-permission-system/config.json.
    home.file.".pi/agent/extensions/pi-permission-system/config.json".source =
      ./ai/pi-extensions/pi-permission-system/config.json;

    # pi-continue (and other extensions) declare @earendil-works/pi-coding-agent
    # as a peerDependency, resolved at runtime via `import.meta.resolve` followed
    # by a direct file read of dist/core/compaction/*.js relative to that resolved
    # path. Extensions live under ~/.pi/agent/npm{,2,3}/node_modules, which pi
    # manages itself via `npm install` against its own package-lock.json -- that
    # peer is never installed there since it isn't a dependency of any extension's
    # own package.json; it's meant to be the host CLI. Node's ESM resolver walks
    # every ancestor node_modules directory, so placing a symlink one level up, at
    # ~/.pi/agent/node_modules (outside the npm-managed tree, safe from `pi`'s own
    # installs pruning it), makes it resolvable for every extension underneath.
    # Points at piCodingAgentDist rather than the `pi` package's own store
    # path, since that output no longer ships this tree at all -- see
    # piCodingAgentDist's comment above.
    home.file.".pi/agent/node_modules/@earendil-works/pi-coding-agent".source = piCodingAgentDist;

    home.file.".pi/agent/AGENTS.md".text = mkAgentContext "env-pi.md";

    home.file.".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "litellm-home";
      defaultModel = "coding";
      quietStartup = true;
      enabledModels = [
        "chat"
        "chat-fast"
        "coding"
        "instruct"
        "instruct-reasoning"
        "orchestrator"
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
        "npm:pi-context"
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
            supportsReasoningEffort = true;
          };
          models = [
            {
              id = "chat";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "chat-fast";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "coding";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "instruct";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "instruct-reasoning";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "orchestrator";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "planning";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
            }
            {
              id = "research";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
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
          ENABLE_TOOL_SEARCH = true;
        };
        includeCoAuthoredBy = false;
        installMethod = "manual";
        outputStyle = "concise";
        remoteControlAtStartup = false;
        skipInstallOnStartup = true;
        sandbox = {
          excludedCommands = [
            "acli *"
            "backlog *"
            "herdr *"
            "mkdir *"
            "nix build *"
            "nix eval *"
            "rtk cargo *"
            "rtk gh *"
            "rtk git *"
          ];
          filesystem = {
            allowWrite = [
              "/private/var/folders/*/*/T/**"
              "/var/folders/*/*/T/**"
              "~/obsidian/**"
            ];
          };
          network = {
            allowedDomains = [
              "localhost"
              "127.0.0.1"
              "[::1]"
            ];
            allowLocalBinding = true;
            allowUnixSockets = [ "~/.config/herdr/herdr.sock" ];
          };
        };
        tui = "fullscreen";
        permissions = {
          defaultMode = "auto";
          additionalDirectories = [
            "~/.herdr/worktrees"
            "~/obsidian"
          ];
          allow = [
            "Bash(acli confluence *)"
            "Bash(acli jira *)"
            "Bash(biome check *)"
            "Bash(biome format *)"
            "Bash(biome lint *)"
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
            "Bash(claude agents *)"
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
            "Bash(pup auth *)"
            "Bash(pup events *)"
            "Bash(pup on-call *)"
            "Bash(rover supergraph compose *)"
            "Bash(rtk curl *)"
            "Bash(rtk find *)"
            "Bash(rtk gh *)"
            "Bash(rtk git *)"
            "Bash(rtk grep *)"
            "Bash(rtk ls *)"
            "Bash(rtk ps *)"
            "Bash(rtk read *)"
            "Bash(rtk wc *)"
            "Read(/private/tmp/claude-*/**)"
            "Read(/tmp/claude-*/**)"
            "Read(~/.claude/skills/**)"
            "Skill(humanizer)"
            "Skill(skill-creator)"
            "Skill(update-config)"
            "WebFetch(domain:api.datadoghq.com)"
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
              {
                matcher = "AskUserQuestion";
                hooks = [
                  {
                    type = "command";
                    command = worktrunkMarkerCommand "💬";
                  }
                ];
              }
            ]
            ++ (moshiClaudeHooks.PreToolUse or [ ]);
          PermissionRequest = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = worktrunkMarkerCommand "💬";
                }
              ];
            }
          ]
          ++ (moshiClaudeHooks.PermissionRequest or [ ]);
          PostToolUse = moshiClaudeHooks.PostToolUse or [ ];
          UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = worktrunkMarkerCommand "🤖";
                }
              ];
            }
          ]
          ++ (moshiClaudeHooks.UserPromptSubmit or [ ]);
          Notification = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = worktrunkMarkerCommand "💬";
                }
              ];
            }
          ];
          Stop = [
            {
              hooks = [
                {
                  type = "command";
                  command = worktrunkMarkerCommand "💬";
                }
              ];
            }
          ]
          ++ (moshiClaudeHooks.Stop or [ ]);
          WorktreeCreate = [
            {
              hooks = [
                {
                  type = "command";
                  command = ''
                    bash -c 'name=$(jq -er .name) || exit 1; cd "''${CLAUDE_PROJECT_DIR:-.}" || exit 1; bash "${worktrunkHookScript}" switch --create "$name" --no-cd --format=json | jq -er .path'
                  '';
                }
              ];
            }
          ];
          WorktreeRemove = [
            {
              hooks = [
                {
                  type = "command";
                  command = ''
                    bash -c 'p=$(jq -er .worktree_path) || exit 1; cd "''${CLAUDE_PROJECT_DIR:-.}" || exit 1; [ -e "$p" ] || exit 0; bash "${worktrunkHookScript}" remove --foreground "$p"'
                  '';
                }
              ];
            }
          ];
          SessionStart = [
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
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = worktrunkClearCommand;
                }
              ];
            }
          ]
          ++ (moshiClaudeHooks.SessionEnd or [ ]);
        };
      }
      // lib.optionalAttrs config.jeff.enableClaudeVoice {
        voice = {
          enabled = true;
          mode = "hold";
        };
      };

      context = mkAgentContext "env-claude.md";

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
        domain-modeling = "${matt-pocock-skills}/skills/engineering/domain-modeling";
        grill-me = "${matt-pocock-skills}/skills/productivity/grill-me";
        grilling = "${matt-pocock-skills}/skills/productivity/grilling";
        research = "${matt-pocock-skills}/skills/engineering/research";

        acli = ./ai/skills/acli;
        actual-cli = ./ai/skills/actual-cli;
        agent-browser = "${agent-browser}/share/agent-browser/skills/agent-browser";
        ast-grep = "${ast-grep-skill}/ast-grep/skills/ast-grep";
        backlog-execute = ./ai/skills/backlog-execute;
        backlog-planner = ./ai/skills/backlog-planner;
        brainstorming = ./ai/skills/brainstorming;
        elixir = ./ai/skills/elixir;
        excalidraw-diagram = "${excalidraw-diagram-skill-wrapped}";
        herdr = "${herdr-skill}";
        humanizer = "${humanizer}";
        kami = "${mkKamiSkill config.jeff.kamiSkillBrand}";
        pi-authoring = "${pi-authoring-skill}";
        review-pi-work = ./ai/skills/review-pi-work;
        software-design = ./ai/skills/software-design;
        stop-slop = "${stop-slop}";
        todoist-cli = "${todoist-cli-skill}";
        voice-dna = ./ai/skills/voice-dna;
        voice-dna-creator = ./ai/skills/voice-dna-creator;
        worktrunk = "${worktrunkPluginRoot}/skills/worktrunk";
        writing-clearly-and-concisely = "${the-elements-of-style}/skills/writing-clearly-and-concisely";
        wt-switch-create = "${worktrunkPluginRoot}/skills/wt-switch-create";
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
