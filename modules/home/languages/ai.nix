{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

let
  agent-browser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  agent-slack = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-slack;
  pi-acp = pkgs.callPackage ../../../pkgs/pi-acp { };
  claude-agent-acp = pkgs.callPackage ../../../pkgs/claude-agent-acp { };
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
  kami = inputs.kami;
  apollo_skills = inputs.apollo_skills;
  # apollo_skills ships client SDKs (apollo-client/ios/kotlin), agent tooling
  # (apollo-mcp-server), and meta (skill-creator) alongside the server/federation
  # skills that are actually relevant to Jeff's work -- keep only the latter
  # rather than pulling in the whole upstream skills/ tree.
  apolloSkillsWanted = [
    "apollo-federation"
    "apollo-router"
    "apollo-server"
    "graphql-operations"
    "graphql-schema"
    "rover"
    "rust-best-practices"
  ];
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
  diagram-design-skill = inputs.diagram-design-skill;
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
  # Network endpoints, one per model use (see options.jeff.endpoints). Skill
  # sources hold no addresses: scripts and SKILL.md prose read the environment
  # variables below, which home.sessionVariables exports to every shell and so to
  # every agent started from one.
  endpoints = config.jeff.endpoints;
  endpointEnv = {
    TTS_API = endpoints.ttsApi;
    NARRATION_TTS_API = endpoints.narrationTtsApi;
    STT_API = endpoints.sttApi;
    IMAGE_API = endpoints.imageApi;
    MUSIC_API = endpoints.musicApi;
    MUSIC_STT_API = endpoints.musicSttApi;
    COVER_API = endpoints.coverApi;
    COVER_STT_API = endpoints.coverSttApi;
    TALKING_HEAD_API = endpoints.talkingHeadApi;
    TALKING_HEAD_SSH = endpoints.talkingHeadSsh;
    LORA_SSH = endpoints.loraSsh;
    LORA_UI = endpoints.loraUi;
  };
  yue2SongSkill = pkgs.callPackage ../../../pkgs/yue2-song-skill { };
  songCoverSkill = pkgs.callPackage ../../../pkgs/song-cover-skill {
    yue2-song-skill = yue2SongSkill;
  };
  ttsSpeechSkill = pkgs.callPackage ../../../pkgs/tts-speech-skill { };
  flashheadVideoSkill = pkgs.callPackage ../../../pkgs/flashhead-video-skill { };
  sttTranscribeSkill = pkgs.callPackage ../../../pkgs/stt-transcribe-skill { };
  narratedVideoSkill = pkgs.callPackage ../../../pkgs/narrated-video-skill { };
  narratedPresentationSkill = pkgs.callPackage ../../../pkgs/narrated-presentation-skill {
    narrated-video-skill = narratedVideoSkill;
    stt-transcribe-skill = sttTranscribeSkill;
    flashhead-video-skill = flashheadVideoSkill;
  };
  comfyuiSkills = pkgs.callPackage ../../../pkgs/comfyui-skills { };
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
  carin = inputs.carin.packages.${pkgs.stdenv.hostPlatform.system}.default;
  carin-skill = inputs.carin.packages.${pkgs.stdenv.hostPlatform.system}.skill;
  carin-herdr-mod = inputs.carin.packages.${pkgs.stdenv.hostPlatform.system}.herdr-mod;
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdr-core = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
  herdr-app = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app;
  # The package ships only bin/herdr-app, so darwin.nix has no .app to link into ~/Applications.
  herdrAppBundle = pkgs.runCommandLocal "herdr-app-bundle" { } ''
    app="$out/Applications/Herdr.app/Contents"
    mkdir -p "$app/MacOS"
    ln -s ${herdr-app}/bin/herdr-app "$app/MacOS/herdr-app"
    cat > "$app/Info.plist" <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>Herdr</string>
      <key>CFBundleIdentifier</key><string>dev.herdr.app</string>
      <key>CFBundleExecutable</key><string>herdr-app</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleVersion</key><string>${herdr-app.version}</string>
      <key>NSHighResolutionCapable</key><true/>
    </dict>
    </plist>
    EOF
  '';
  herdrConfig = {
    onboarding = false;
    theme = {
      name = "tokyo-night";
      auto_switch = false;
    };
    ui = {
      agent_panel_sort = "priority";
      show_agent_labels_on_pane_borders = true;
      toast.delivery = "herdr";
    };
    keys = {
      prefix = "ctrl+a";
      # open_worktree = "prefix+shift+o";
      # remove_worktree = "prefix+alt+d";
      focus_agent = "prefix+shift+1..9";
      previous_agent = "prefix+<";
      next_agent = "prefix+>";
      next_workspace = "prefix+]";
      previous_workspace = "prefix+[";
      focus_pane_left = "prefix+left";
      focus_pane_down = "prefix+down";
      focus_pane_up = "prefix+up";
      focus_pane_right = "prefix+right";
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
          # temporary pane; closes when hunk exits
          key = "cmd+r";
          type = "pane";
          command = "hunk diff";
          description = "Hunk: review working tree changes";
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
          key = "prefix+shift+o";
          type = "plugin_action";
          command = "worktrunk.open";
          description = "Worktree: open existing or create from default branch";
        }
        {
          key = "prefix+shift+c";
          type = "plugin_action";
          command = "worktrunk.open-current";
          description = "Worktree: switch / create from current branch";
        }
        {
          key = "prefix+shift+e";
          type = "plugin_action";
          command = "worktrunk.remove";
          description = "Worktree: remove";
        }
      ];
    };
  };

  # herdr-app (the desktop app) reads ~/.config/herdr-app, not herdr's config.toml.
  # An action is { command, args }, { overlay } (opened with the space and folder), or { keys }.
  herdrAppCommand = command: args: { inherit command args; };
  # Sizes match the shipped new-menu and menu mods' worktree dialogs.
  herdrAppWorktree = action: width: height: {
    overlay = {
      mod = "my-worktree";
      kind = "dialog";
      inherit width height;
      props = { inherit action; };
    };
  };
  # Keys outside the prefix whose command needs more than one argument open a one-shot action mod.
  herdrAppActions = {
    key-hunk = herdrAppCommand "pane.split" {
      direction = "right";
      argv = [
        "hunk"
        "diff"
      ];
    };
  };
  # What ctrl-a then <key> does, keyed by the typed character or, for keys that type none, the
  # keystroke. Old herdr's built-in prefix defaults with a herdr-app command, then config.toml binds.
  # `section` and `label` feed the ctrl-a ? panel in list order; one row per `group` or label.
  herdrAppPrefixList =
    let
      c = herdrAppCommand;
      bind =
        section: key: label: action:
        action // { inherit section key label; };
      tab = bind "Tabs";
      space = bind "Spaces";
      pane = bind "Panes";
      agent = bind "Agents";
      work = bind "Files and worktrees";
      app = bind "App";
      # Navigation entries keep the prefix popup open for a repeat window.
      rep = action: action // { repeat = true; };
      go = key: direction: pane key "Focus pane ${direction}" (rep (c "pane.go" { inherit direction; }));
    in
    [
      (tab "c" "New tab" (c "tab.new" { }))
      (tab "n" "Next tab" (rep (c "tab.next" { })))
      (tab "p" "Previous tab" (rep (c "tab.prev" { })))
    ]
    ++ map (
      n: tab (toString n) "Select tab by number" (c "tab.select" { index = n; }) // { group = "1-9"; }
    ) (lib.range 1 9)
    ++ [
      (tab "T" "Rename tab" (c "tab.rename" { }))
      (tab "X" "Close tab" (c "tab.close" { }))
      (space "N" "New space" (c "space.new" { }))
      (space "]" "Next space" (rep (c "space.next" { })))
      (space "[" "Previous space" (rep (c "space.prev" { })))
      (space "w" "Pick a space or tab" (c "mod.open" { name = "picker"; }))
      (space "W" "Rename space" (c "space.rename" { }))
      (space "D" "Close space" (c "space.close" { }))
      (go "h" "left")
      (go "left" "left")
      (go "j" "down")
      (go "down" "down")
      (go "k" "up")
      (go "up" "up")
      (go "l" "right")
      (go "right" "right")
      (pane "v" "Split right" (c "pane.split" { direction = "right"; }))
      (pane "-" "Split down" (c "pane.split" { direction = "down"; }))
      (pane "z" "Zoom pane" (c "pane.zoom" { }))
      (pane "x" "Close pane" (c "pane.close" { }))
      (agent ">" "Next agent" (rep (c "agent.next" { })))
      (agent "<" "Previous agent" (rep (c "agent.prev" { })))
      (work "f" "Files beside this pane" (
        c "pane.split" {
          direction = "right";
          mod = "files";
        }
      ))
      (work "F" "Files in a new tab" (
        c "tab.new" {
          name = "files";
          mod = "files";
        }
      ))
      (work "G" "Open worktree" (herdrAppWorktree "open" 560 480))
      (work "O" "Open worktree" (herdrAppWorktree "open" 560 480))
      (work "C" "New worktree from this branch" (herdrAppWorktree "new" 460 280))
      (work "E" "Remove worktree" (herdrAppWorktree "remove" 440 260))
      (app "b" "Toggle sidebar" (c "layout.toggle" { id = "sidebar"; }))
      (app "s" "Settings" (c "app.settings" { }))
      (app "?" "These keys" (c "mod.open" { name = "prefix-help"; }))
      (app "ctrl-a" "Send ctrl-a to the terminal" { keys = "ctrl+a"; })
    ];
  herdrAppPrefixMod =
    source:
    pkgs.replaceVars source {
      prefixLib = builtins.replaceStrings [ "@bindings@" ] [ (builtins.toJSON herdrAppPrefixList) ] (
        builtins.readFile ./ai/herdr-app/prefix-lib.js
      );
    };
  herdrAppModFiles =
    lib.concatMapAttrs (name: action: {
      "herdr-app/mods/${name}/main.js".source = pkgs.replaceVars ./ai/herdr-app/action.js {
        action = builtins.toJSON action;
      };
      "herdr-app/mods/${name}/mod.json".text = builtins.toJSON {
        place = "none";
        overlay = {
          kind = "popup";
          width = 1;
          height = 1;
          frame = "none";
        };
      };
    }) herdrAppActions
    // {
      "herdr-app/mods/prefix/main.js".source = herdrAppPrefixMod ./ai/herdr-app/prefix.js;
      "herdr-app/mods/prefix/mod.json".text = builtins.toJSON {
        place = "none";
        overlay = {
          kind = "popup";
          at = "top";
          offset = 40;
          width = 340;
          height = 40;
        };
      };
      "herdr-app/mods/prefix-help/main.js".source = herdrAppPrefixMod ./ai/herdr-app/prefix-help.js;
      "herdr-app/mods/prefix-help/mod.json".text = builtins.toJSON {
        place = "none";
        overlay = {
          kind = "dialog";
          width = 720;
          height = 560;
        };
      };
    };
  herdrAppPrefixKeys = {
    "cmd-r" = "mod.open:key-hunk";
  };
  # herdr-app's shipped mods exist only inside its binary, which writes them to its home on
  # start. Run it once against a scratch home, copy each mod this config changes to my-<name>,
  # and apply ai/herdr-app/patches/<name>.patch with no fuzz: a herdr-app update that moves
  # the patched lines fails this build instead of leaving a stale clone.
  # Logic lives in whole files under ai/herdr-app/mod-files/<name>/, appended to the patched
  # main.js (herdr-app rejects a sibling import that is a symlink into the store), so a patch is
  # only a few call sites. my-worktree runs worktrunk instead of git (worktrunk.js); my-agents
  # draws each agent's space avatar (space-mark.js); my-menu, my-new-menu, my-spaces and my-tabs
  # only open the my-* mods; my-workspace-status shows the branch's GitHub PR (pr-status.js).
  # `herdr-app check` then fails the build on a name the appended code needs from main.js's
  # imports and no longer finds.
  herdrAppCloneFileNames = {
    agents = [ ];
    worktree = [ ];
    menu = [ ];
    new-menu = [ ];
    spaces = [ ];
    workspace-status = [ ];
    tabs = [
      "win-close.svg"
      "win-max.svg"
      "win-min.svg"
      "win-restore.svg"
    ];
  };
  herdrAppClones = pkgs.runCommand "herdr-app-clones" { nativeBuildInputs = [ pkgs.coreutils ]; } ''
    export HOME="$TMPDIR" HERDR_APP_HOME="$TMPDIR/herdr-app-home"
    # The build sandbox has no Wayland socket and no host fontconfig state, so GPUI's
    # text system can't resolve any font for `herdr-app check` unless pointed at one
    # explicitly - without this it panics with "failed to resolve font '.SystemUIFont'".
    export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"
    export XDG_DATA_DIRS="${pkgs.dejavu_fonts}/share"
    mkdir -p "$HERDR_APP_HOME"
    ${herdr-app}/bin/herdr-app >"$TMPDIR/herdr-app.log" 2>&1 &
    pid=$!
    # It seeds its mods on start, before it needs a window; stop it once they are written.
    for _ in $(seq 150); do
      [ -f "$HERDR_APP_HOME/installed.json" ] && [ -f "$HERDR_APP_HOME/mods/worktree/main.js" ] && break
      sleep 0.2
    done
    sleep 1
    kill "$pid" 2>/dev/null || true
    [ -f "$HERDR_APP_HOME/mods/worktree/main.js" ] || { cat "$TMPDIR/herdr-app.log"; echo "herdr-app wrote no mods"; exit 1; }
    mkdir -p "$out"
    ${lib.concatMapStrings (name: ''
      cp -r --no-preserve=mode "$HERDR_APP_HOME/mods/${name}" "$out/my-${name}"
      patch --fuzz=0 -p1 -d "$out/my-${name}" < ${./ai/herdr-app/patches + "/${name}.patch"}
      ${
        lib.optionalString (builtins.pathExists (./ai/herdr-app/mod-files + "/${name}")) ''
          cat ${./ai/herdr-app/mod-files + "/${name}"}/*.js >> "$out/my-${name}/main.js"
        ''
      }${herdr-app}/bin/herdr-app check "$out/my-${name}"
    '') (builtins.attrNames herdrAppCloneFileNames)}
  '';
  herdrAppCloneFiles = lib.concatMapAttrs (
    name: extra:
    lib.listToAttrs (
      map
        (file: {
          name = "herdr-app/mods/my-${name}/${file}";
          value = {
            source = "${herdrAppClones}/my-${name}/${file}";
            force = true;
          };
        })
        (
          [
            "main.js"
            "mod.json"
          ]
          ++ extra
        )
    )
  ) herdrAppCloneFileNames;
  # A user keys.json replaces herdr-app's whole default map, so the defaults are repeated here.
  herdrAppKeys =
    let
      # Nix strings have no \u escapes; decode the JSON escape instead.
      send = escape: "send:" + builtins.fromJSON ''"${escape}"'';
    in
    {
      global = {
        "cmd-q" = "app.quit";
        "cmd-h" = "app.hide";
        "cmd-alt-h" = "app.hide_others";
        "cmd-t" = "tab.new";
        "cmd-w" = "tab.close";
        "ctrl-tab" = "tab.next";
        "ctrl-shift-tab" = "tab.prev";
        "cmd-shift-]" = "tab.next";
        "cmd-shift-[" = "tab.prev";
        "cmd-alt-]" = "space.next";
        "cmd-alt-[" = "space.prev";
        "cmd-]" = "agent.next";
        "cmd-[" = "agent.prev";
        "cmd-shift-l" = "layout.switch";
        "cmd-n" = "space.new";
        "cmd-p" = "mod.open:picker";
        "cmd-shift-p" = "app.palette";
        "cmd-," = "app.settings";
        "cmd-d" = "pane.split:right";
        "cmd-shift-d" = "pane.split:down";
        "cmd-shift-w" = "pane.close";
        "cmd-shift-enter" = "pane.zoom";
        "cmd-alt-left" = "pane.go:left";
        "cmd-alt-right" = "pane.go:right";
        "cmd-alt-up" = "pane.go:up";
        "cmd-alt-down" = "pane.go:down";
        "cmd-alt-shift-left" = "pane.swap:left";
        "cmd-alt-shift-right" = "pane.swap:right";
        "cmd-alt-shift-up" = "pane.swap:up";
        "cmd-alt-shift-down" = "pane.swap:down";
        "f2" = "tab.rename";
        "shift-f2" = "space.rename";
        "cmd-/" = "app.help";
        "cmd-shift-/" = "app.help";
        "cmd-b" = "layout.toggle:sidebar";
        "cmd-=" = "app.zoom_in";
        "cmd-+" = "app.zoom_in";
        "cmd--" = "app.zoom_out";
        "cmd-0" = "app.zoom_reset";
      }
      // lib.listToAttrs (
        lib.concatMap (
          n:
          let
            i = toString n;
          in
          [
            (lib.nameValuePair "cmd-${i}" "tab.select:${i}")
            (lib.nameValuePair "ctrl-${i}" "space.select:${i}")
          ]
        ) (lib.range 1 9)
      )
      // herdrAppPrefixKeys;
      terminal = {
        "cmd-c" = "terminal.copy";
        "cmd-v" = "terminal.paste";
        "ctrl-v" = "terminal.paste_image";
        "alt-left" = send ''\u001bb'';
        "alt-right" = send ''\u001bf'';
        "alt-backspace" = send ''\u0017'';
        "cmd-left" = send ''\u0001'';
        "cmd-right" = send ''\u0005'';
        "cmd-backspace" = send ''\u0015'';
        # Terminal only: a global ctrl-a fires too, and mod.open toggles the popup shut again.
        "ctrl-a" = "mod.open:prefix";
      };
    };
  # Same slot mapping as Stylix's Ghostty target, so herdr-app terminals match Ghostty.
  herdrAppTheme = with config.lib.stylix.colors.withHashtag; {
    background = base00;
    foreground = base05;
    cursor = base05;
    selection = base02;
    ansi = [
      base00
      base08
      base0B
      base0A
      base0D
      base0E
      base0C
      base05
      base03
      base08
      base0B
      base0A
      base0D
      base0E
      base0C
      base07
    ];
  };
  moshi-hook = pkgs.callPackage ../../../pkgs/moshi-hook { };
  zvec-grep = pkgs.callPackage ../../../pkgs/zvec-grep { };
  zgHintHook = pkgs.writeShellApplication {
    name = "zg-hint-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.gnugrep
      pkgs.findutils
      pkgs.coreutils
      zvec-grep
    ];
    text = builtins.readFile ./ai/hooks/zg-hint.sh;
  };
  backlogUnblocked = pkgs.writeShellApplication {
    name = "backlog-unblocked";
    runtimeInputs = [
      pkgs.yq-go
      pkgs.jq
      pkgs.gawk
      pkgs.coreutils
    ];
    text = builtins.readFile ./ai/pi-extensions/ralph/unblocked-todo.sh;
  };
  claudeStatusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.coreutils
    ];
    text = builtins.readFile ./ai/statusline.sh;
  };
  # Per-session spoken replies: `/talk` toggles it, a UserPromptSubmit hook
  # adds listening rules, and a Stop hook reads the reply aloud.
  voiceMode = pkgs.writeShellApplication {
    name = "voice-mode";
    runtimeInputs = [
      pkgs.jq
      pkgs.gawk
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      VOICE_TTS=${ttsSpeechSkill}/scripts/tts
    ''
    + builtins.readFile ./ai/hooks/voice-mode.sh;
  };
  talkSkill = pkgs.runCommand "talk-skill" { } ''
    mkdir -p $out
    substitute ${./ai/skills/talk/SKILL.md} $out/SKILL.md \
      --replace-fail '@voice-mode@' '${voiceMode}/bin/voice-mode'
  '';
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
      Write, edit, or debug skills, extensions, or SDK code for pi, the
      pi.dev/earendil-works coding agent. Covers SKILL.md files under .pi/skills,
      ~/.pi/agent/skills, or a pi package's skills/ directory, and TypeScript
      extensions under .pi/extensions or ~/.pi/agent/extensions. Use when the user
      asks to create, modify, or debug a pi skill or extension, or asks how they work.
    ---

    The end state is a pi file that matches the installed pi version. The
    `references/` files in this skill's directory document that version.

    1. Read the references for the task type.
       - Skill: read `references/skills.md`. pi uses the Agent Skills `SKILL.md`
         format Claude Code uses; that file lists pi's discovery paths and name rules.
       - Extension: read `references/extensions.md`, then
         `references/example-extensions/README.md`. Open the 2-3 closest examples.
       - SDK code (`@earendil-works/pi-coding-agent` imported as a library): read
         `references/sdk.md`, then `references/example-sdk/README.md`. Open the
         closest examples.
    2. Write the file using only APIs shown in those references. Memorized pi APIs
       are often outdated.
    SKILLEOF
  '';

  # Helper function to read markdown files from the ai directory
  readAiDoc = file: builtins.readFile (./ai + "/${file}");

  # The global context file every agent harness gets, assembled per harness:
  # a shared core (design bias, working preferences) behind an environment
  # preamble naming that harness's own nix-managed paths. Claude Code reads it
  # as ~/.claude/CLAUDE.md, pi as ~/.pi/agent/AGENTS.md.
  mkAgentContext =
    preamble:
    preamble
    + "\n"
    + readAiDoc "context/core.md"
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin (readAiDoc "context/macos.md")
    + lib.optionalString config.jeff.enableZvecGrep ("\n" + readAiDoc "context/code-search.md");

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
  # kami reads its brand profile from ~/.config/kami/brand.md at runtime
  # (XDG, not baked into the skill package) -- see the xdg.configFile
  # deployment below.
  options.jeff.kamiSkillBrand = lib.mkOption {
    type = lib.types.path;
    default = ./ai/kami/brand.md;
  };

  # Claude Code voice mode. Enabled only on hosts with physical access (local
  # laptops/desktops); left off on remote/headless machines where audio is
  # unwanted.
  options.jeff.enableClaudeVoice = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  # Apollo's server/federation skills are only relevant to Jeff's work
  # projects; keep them off other hosts to avoid clutter.
  options.jeff.enableApolloSkills = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  # zvec-grep (hybrid ripgrep + semantic workspace search, `zg`). Installs the
  # CLI, registers its MCP server, and (via darwin.nix/linux.nix) runs its
  # daemon as a login service. Only enabled on hosts that opt in, since the
  # daemon and its embedding models are unwanted dead weight elsewhere.
  options.jeff.enableZvecGrep = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  # Network endpoints, one per model use, not per machine: skills say "the TTS
  # API" and never name a host, so moving a service means editing one value here.
  # Two uses that run different models never share an entry, even when they
  # point at the same URL today, so repointing one cannot move the other. The skill
  # ones are exported as env vars (endpointEnv); llmApi and deciderApi feed the pi
  # config directly. No trailing slash. A skill appends its own API path to the
  # bare ones.
  options.jeff.endpoints =
    let
      # Where each service lives today. Roles below pick one as their default.
      litellm = "https://litellm.home.jeffutter.com/v1";
      homelabSwap = "https://llama.home.jeffutter.com/v1";
      homelabStt = "http://192.168.10.4:8089";
      sparkSwap = "http://192.168.10.14:8000";
      sparkSsh = "jeffutter@192.168.10.14";
      sparkTrainerUi = "http://192.168.10.14:8081";
      endpoint =
        default: description:
        lib.mkOption {
          type = lib.types.str;
          inherit default description;
        };
    in
    lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = {
          llmApi = endpoint litellm "Chat models for pi (provider litellm-home), base URL including /v1.";
          deciderApi = endpoint litellm "Decider classifier model for thinking-router, base URL including /v1.";
          ttsApi = endpoint homelabSwap "Text-to-speech models (tts-speech skill), base URL including /v1.";
          narrationTtsApi = endpoint homelabSwap "Narration voice for narrated-video and narrated-presentation, base URL including /v1.";
          sttApi = endpoint homelabSwap "Speech-to-text models (stt-transcribe skill), base URL including /v1.";
          imageApi = endpoint sparkSwap "ComfyUI image models, bare base URL (comfy adds /upstream/comfyui).";
          musicApi = endpoint sparkSwap "YuE2 song generation, bare base URL (yue2 adds /audioapi).";
          musicSttApi = endpoint homelabStt "Transcription yue2 uses to check generated lyrics, bare base URL (adds /v1/audio/transcriptions).";
          coverApi = endpoint sparkSwap "SheetSage2 and word-timestamp models for song-cover, bare base URL (cover adds /upstream/audiocpp).";
          coverSttApi = endpoint homelabStt "Transcription song-cover uses for lyrics, bare base URL (adds /v1/audio/transcriptions).";
          talkingHeadApi = endpoint sparkSwap "SoulX-FlashHead video models, bare base URL (flashhead adds /audioapi).";
          talkingHeadSsh = endpoint sparkSsh "ssh target flashhead stages inputs to and reads logs from.";
          loraSsh = endpoint sparkSsh "ssh target of the LoRA trainer (character-lora-training skill).";
          loraUi = endpoint sparkTrainerUi "Web UI of the LoRA trainer.";
        };
      };
    };

  # Host-specific Claude Code context, appended to the environment preamble in
  # ~/.claude/CLAUDE.md. The work machine uses it for how its managed sandbox
  # treats git/gh/acli, which doesn't apply anywhere else.
  options.jeff.claudeContextExtra = lib.mkOption {
    type = lib.types.lines;
    default = "";
  };

  # Claude Code's default effort level. Set here rather than via /effort,
  # which can't write to the read-only settings.json symlink.
  options.jeff.claudeEffortLevel = lib.mkOption {
    type = lib.types.enum [
      "low"
      "medium"
      "high"
      "xhigh"
      "max"
    ];
    default = "medium";
  };

  config = {
    home.packages =
      with pkgs;
      [
        agent-browser
        backlog-md
        backlogUnblocked
        carin
        claude-agent-acp
        claude-tail
        herdr
        herdr-app
        herdr-core
        moshi-hook
        pi
        pi-acp
        (llm.withPlugins {
          llm-cmd = true;
          llm-jq = true;
        })
      ]
      ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin herdrAppBundle
      ++ lib.optional config.jeff.enableZvecGrep zvec-grep;

    # Model for every new zg index. The daemon (darwin.nix / linux.nix) reads
    # the same value. jina-v2-base-code is code-trained; zg's default
    # potion-code-16m-v2 is a static model2vec embedding that ranked the right
    # function first for 1 of 10 concept queries on blueprint, jina for 8.
    # An existing index keeps the model it was built with.
    home.sessionVariables =
      endpointEnv
      // lib.optionalAttrs config.jeff.enableZvecGrep {
        ZVEC_GREP_EMBEDDING = "local/jina-embeddings-v2-base-code";
      };

    # Per-file links keep the herdr-app mod folders writable; it writes jsconfig.json and .d.ts there.
    xdg.configFile =
      herdrAppModFiles
      // herdrAppCloneFiles
      // {
        "kami/brand.md".source = config.jeff.kamiSkillBrand;

        "herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-config.toml" herdrConfig;

        "herdr-app/keys.json" = {
          text = builtins.toJSON herdrAppKeys;
          force = true;
        };
        "herdr-app/themes/stylix.json".text = builtins.toJSON herdrAppTheme;
        "herdr-app/mods/carin" = {
          source = "${carin-herdr-mod}/mods/carin";
          recursive = true;
        };

        # force: replaces the files `herdr-app do layout.clone` first wrote.
        "herdr-app/layouts/my-layout.json" = {
          source = ./ai/herdr-app/my-layout.json;
          force = true;
        };
      };

    # herdr-app rewrites settings.json (zoom, Settings screen), so merge only theme, font and ui_font into it.
    home.activation.herdrAppSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="${config.xdg.configHome}/herdr-app/settings.json"
      run mkdir -p "$(dirname "$settings")"
      [ -s "$settings" ] || run sh -c 'echo "{}" > "$1"' _ "$settings"
      tmp="$(mktemp)"
      ${pkgs.jq}/bin/jq --arg font ${lib.escapeShellArg config.stylix.fonts.monospace.name} \
        '.theme = "stylix" | .font = $font | .ui_font = $font' "$settings" > "$tmp"
      # cp onto the existing file keeps its owner and mode; mv would leave mktemp's 0600.
      run cp "$tmp" "$settings"
      rm -f "$tmp"
    '';

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

    # unblocked-todo.sh: finds backlog.md tasks whose dependencies are all Done, used by
    # ralph's choose/promote steps (see UNBLOCKED_TODO_SCRIPT in index.ts). Deployed next to
    # the extension rather than living inside each project's own backlog/ directory, since
    # ralph now loads globally; the script cds into the target project's backlog/ itself
    # rather than locating it via its own path.
    home.file.".pi/agent/extensions/ralph/unblocked-todo.sh" = {
      source = ./ai/pi-extensions/ralph/unblocked-todo.sh;
      executable = true;
    };

    home.file.".claude/workflows/ralph-backlog-loop.js".source = ./ai/workflows/ralph-backlog-loop.js;

    # clear-alias: aliases /clear to /new. Same "promoted to load globally"
    # situation as ralph above -- source lives at ./ai/pi-extensions/clear-alias.ts
    # and is edited in place in this repo going forward.
    home.file.".pi/agent/extensions/clear-alias.ts".source = ./ai/pi-extensions/clear-alias.ts;

    # thinking-router: picks the thinking level per prompt with the Jev
    # classifier (decider-4b), restoring pi's level after each run. Metrics go
    # to ~/.pi/agent/thinking-router/decisions.jsonl and optional overrides are
    # read from ~/.pi/agent/thinking-router.json, both outside this store path.
    home.file.".pi/agent/extensions/thinking-router.ts".text =
      builtins.replaceStrings [ "@deciderApi@" ] [ endpoints.deciderApi ]
        (builtins.readFile ./ai/pi-extensions/thinking-router.ts);

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

    # pi-lens: disable lazy tool activation so ast_grep_* and lsp_navigation are
    # active from the first turn instead of requiring a pi_lens_activate_tools
    # call. Headless ralph workers never make that call, so on the default lazy
    # setting these tools go entirely unused and workers fall back to blind
    # whole-file reads on large source files. Costs a slightly longer tool list
    # every turn in exchange for the tools actually being reachable.
    # Backlog.md stores its task and document bodies as markdown whose comment
    # fences are `author:` / `created:` / `---`. markdownlint parses that `---`
    # as a setext heading underline, so the line above it becomes a heading and
    # `markdownlint-cli2 --fix` rewrites stored data: strips trailing punctuation
    # off comment headers (MD026), inserts blanks around "fences", and relabels
    # the walking-skeleton spec's user-story lists, which are numbered
    # continuously on purpose because those numbers are references.
    #
    # pi-lens runs `--fix` for any fixable finding in the file, and its own
    # allowlist of deterministically-fixable rules (MD029 is absent from it)
    # gates only what gets *reported*, not what the rewrite applies. So one
    # stray blank-line warning in a ticket is enough to renumber stories nobody
    # touched. Those files are Backlog's storage format rather than prose a
    # linter should own, so exclude them from every scan, autofix included.
    # Verified in dist: written paths reach the fix pipeline through
    # isPathIgnoredByProject, which honours these globs.
    home.file.".pi-lens/config.json".text = builtins.toJSON {
      tools.lazy = false;
      ignore = [ "backlog/**" ];
    };

    # pi-intercom: inboundTrigger defaults to "always", meaning every message a
    # headless ralph worker sends via intercom hands whichever session receives it a
    # brand-new agent turn -- not an inert transcript entry the orchestrator can read
    # and move past. Ralph's whole "don't reply to workers" system-prompt guidance
    # (pi-extensions/ralph/index.ts, ORCHESTRATOR_ROLE_GUIDANCE) assumes the opposite:
    # a routine ping sits in context for the next real turn and never starts one of
    # its own. Confirmed live 2026-09-24: with this key missing from
    # ~/.pi/agent/intercom/config.json (silently falling back to "always"), the
    # orchestrator was handed a fresh turn on every worker ping and, faced with a
    # message addressed to it, went and investigated the worker's ticket in parallel
    # and replied with unsolicited findings -- both of which the system prompt
    # explicitly says not to do. No amount of prompt wording fixes a model that is
    # being given a turn expressly because a message just arrived for it; "replies"
    # stops a routine `send` ping from ever reaching that point. Declared here rather
    # than left as the hand-edited file it was, so a fresh machine doesn't silently
    # regress to "always" and reproduce this.
    #
    # brokerCommand/brokerArgs: the default broker invocation is `npx --no-install
    # tsx`, which resolves "tsx" by walking up from the broker process's own working
    # directory -- but the broker can be spawned from any project's cwd, none of
    # which have tsx installed (it lives only under ~/.pi/agent/npm/node_modules,
    # where pi installs each extension's own dependencies). Invoking tsx's cli.mjs
    # directly by absolute path sidesteps that resolution entirely.
    home.file.".pi/agent/intercom/config.json".text = builtins.toJSON {
      brokerCommand = "node";
      brokerArgs = [
        "${config.home.homeDirectory}/.pi/agent/npm/node_modules/tsx/dist/cli.mjs"
      ];
      inboundTrigger = "replies";
    };

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

    # Tool-agnostic global MCP config, read by pi-mcp-adapter (and any other
    # MCP-aware tool that follows the same convention) from
    # $XDG_CONFIG_HOME/mcp/mcp.json. Previously hand-maintained as a loose
    # file at ~/.config/mcp/mcp.json; declared here instead so it's tracked
    # alongside the rest of the AI tooling config.
    programs.mcp = {
      enable = true;
      servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp";
          protocolVersion = "auto";
        };
        backlog = {
          command = "backlog";
          args = [
            "mcp"
            "start"
          ];
          directTools = [
            "get_backlog_instructions"
            "task_create"
            "task_list"
            "task_search"
            "task_edit"
            "task_view"
            "task_archive"
            "task_complete"
            "definition_of_done_defaults_get"
            "definition_of_done_defaults_upsert"
            "document_list"
            "document_view"
            "document_create"
            "document_update"
            "document_search"
            "get_backlog_workflow_overview"
            "get_task_creation_guide"
            "get_task_execution_guide"
            "get_task_finalization_guide"
          ];
        };
      }
      // lib.optionalAttrs config.jeff.enableZvecGrep {
        # Talks to the daemon started by launchd.agents.zvec-grep /
        # systemd.user.services.zvec-grep (darwin.nix / linux.nix), not
        # spawned by the MCP client itself -- the service must be running.
        zvec-grep = {
          url = "http://127.0.0.1:7999/mcp";
        };
      };
    };

    # pi's built-in MCP support reads ~/.pi/agent/mcp.json (not the XDG file
    # above). Derived from programs.mcp.servers so there is one server list.
    # The shared entries carry pi-mcp-adapter-only keys: `directTools` becomes
    # pi's `exposure = "hidden"` + per-tool `toolExposure = "direct"`, and
    # `protocolVersion` is dropped.
    home.file.".pi/agent/mcp.json".text = builtins.toJSON {
      mcpServers = lib.mapAttrs (
        _: server:
        let
          direct = server.directTools or [ ];
        in
        lib.filterAttrs (_: v: v != null && v != { }) (
          removeAttrs server [
            "directTools"
            "protocolVersion"
          ]
        )
        // lib.optionalAttrs (direct != [ ]) {
          exposure = "hidden";
          toolExposure = lib.genAttrs direct (_: "direct");
        }
      ) config.programs.mcp.servers;
    };

    home.file.".pi/agent/AGENTS.md".text = mkAgentContext (readAiDoc "context/env-pi.md");

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
        "npm:pi-bar"
        "npm:pi-context"
        "npm:pi-intercom"
        "npm:pi-lens"
        "npm:pi-simplify"
        "npm:pi-tool-display"
        "npm:pi-web-access"
      ];
      skills = [
        "~/.claude/skills"
        # The `synced/` tree is Claude Desktop's skill sync bucket, not ours.
        # Its 13 entries describe MCP tool namespaces that don't exist in pi
        # (mcp__computer-use__*, mcp__Claude_Browser__*, Google Workspace
        # connectors), so they only cost context: ~3.1k tokens on every request.
        #
        # Must stay absolute: pi expands `~` in plain resource entries but not
        # in glob patterns, so `!~/...` silently matches nothing.
        "!${config.home.homeDirectory}/.claude/skills/synced/**"
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
          baseUrl = endpoints.llmApi;
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
              contextWindow = 196608;
            }
            {
              id = "chat-fast";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "coding";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "instruct";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "instruct-reasoning";
              reasoning = false;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "orchestrator";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "planning";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
            {
              id = "research";
              reasoning = true;
              thinkingLevelMap = reasoningThinkingLevelMap;
              input = [
                "text"
                "image"
              ];
              contextWindow = 196608;
            }
          ];
        };
      };
    };

    # `command` skips any `claude` alias, such as the work host's default-model one.
    home.shellAliases = lib.genAttrs [ "opus" "sonnet" "haiku" "fable" ] (
      model: "command claude --model ${model}"
    );

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
        # A top-level effortLevel in user settings is ignored for Opus 5.5,
        # which only reads its per-model modelSettings entry.
        effortLevel = config.jeff.claudeEffortLevel;
        enableWorkflows = true;
        env = {
          DISABLE_AUTOUPDATER = "1";
          DISABLE_INSTALLATION_CHECKS = "1";
          ENABLE_TOOL_SEARCH = "true";
          # lefthook and friends colour their output; escape codes bloat tool results.
          NO_COLOR = "1";
        };
        includeCoAuthoredBy = false;
        installMethod = "manual";
        modelSettings."claude-opus-5-5".effortLevel = config.jeff.claudeEffortLevel;
        outputStyle = "concise";
        remoteControlAtStartup = false;
        statusLine = {
          type = "command";
          command = "${claudeStatusline}/bin/claude-statusline";
          # Keeps the cache countdown moving while the session sits idle.
          refreshInterval = 30;
        };
        skipInstallOnStartup = true;
        skipWorkflowUsageWarning = true;
        sandbox = {
          excludedCommands = [
            "acli *"
            "backlog *"
            "cargo *"
            "gh *"
            "git *"
            "hc *"
            "herdr *"
            "herdr-app *"
            "mkdir *"
            "nix build *"
            "nix eval *"
          ];
          filesystem = {
            allowWrite = [
              "/private/var/folders/*/*/T/**"
              "/var/folders/*/*/T/**"
              "~/.local/share/carin/**"
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
            allowUnixSockets = [
              "~/.config/herdr/herdr.sock"
              "~/.local/state/herdr-core/default/default.sock"
              "~/.config/herdr-app/herdr-app.sock"
            ];
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
            "Bash(curl *)"
            "Bash(echo \"exit=$?\")"
            "Bash(find *)"
            "Bash(gh *)"
            "Bash(git *)"
            "Bash(grep *)"
            "Bash(lefthook *)"
            "Bash(ls *)"
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
            "Bash(ps *)"
            "Bash(pup auth *)"
            "Bash(pup events *)"
            "Bash(pup on-call *)"
            "Bash(read *)"
            "Bash(rover supergraph compose *)"
            "Bash(wc *)"
            "Read(/private/tmp/claude-*/**)"
            "Read(/tmp/claude-*/**)"
            "mcp__backlog"
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
          PostToolUseFailure =
            lib.optional config.jeff.enableZvecGrep {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "${zgHintHook}/bin/zg-hint-hook";
                }
              ];
            }
            ++ (moshiClaudeHooks.PostToolUseFailure or [ ]);
          UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = worktrunkMarkerCommand "🤖";
                }
                {
                  type = "command";
                  command = "${voiceMode}/bin/voice-mode inject";
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
                {
                  type = "command";
                  command = "${voiceMode}/bin/voice-mode speak";
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

      context = mkAgentContext (
        readAiDoc "context/env-claude.md"
        + lib.optionalString (config.jeff.claudeContextExtra != "") ("\n" + config.jeff.claudeContextExtra)
      );

      agents = {
        blind-reader = ''
          ---
          name: blind-reader
          description: Independent reader for ralph-backlog-loop. Answers a prompt using only the files it names, with no other context. Started by the workflow script, not by hand.
          tools: Read
          ---

          You are an independent reader. Your prompt is everything you know about the task.

          - Open only the files the prompt names by absolute path. Do not look for other files.
          - Answer every question the prompt asks, in the order it asks them.
          - Base each answer on what the files show. When a file does not settle a question, say so.
          - Do not guess what answer the caller expects.
          - Return the answer only. Do not add a preamble or a summary of your method.
        '';
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
        grill-with-docs = "${matt-pocock-skills}/skills/engineering/grill-with-docs";
        grilling = "${matt-pocock-skills}/skills/productivity/grilling";
        handoff = "${matt-pocock-skills}/skills/productivity/handoff";
        research = "${matt-pocock-skills}/skills/engineering/research";
        prototype = "${matt-pocock-skills}/skills/engineering/prototype";
        to-spec = "${matt-pocock-skills}/skills/engineering/to-spec";
        to-tickets = "${matt-pocock-skills}/skills/engineering/to-tickets";
        wayfinder = "${matt-pocock-skills}/skills/engineering/wayfinder";

        acli = ./ai/skills/acli;
        actual-cli = ./ai/skills/actual-cli;
        agent-browser = "${agent-browser}/share/agent-browser/skills/agent-browser";
        agent-slack = "${agent-slack}/share/skills/agent-slack/agent-slack";
        ast-grep = "${ast-grep-skill}/ast-grep/skills/ast-grep";
        backlog-execute = ./ai/skills/backlog-execute;
        backlog-planner = ./ai/skills/backlog-planner;
        setup-backlog-tracker = ./ai/skills/setup-backlog-tracker;
        brainstorming = ./ai/skills/brainstorming;
        carin = "${carin-skill}";
        character-lora-training = ./ai/skills/character-lora-training;
        diagram-design = "${diagram-design-skill}/skills/diagram-design";
        diff-explanation-core = ./ai/skills/diff-explanation-core;
        elixir = ./ai/skills/elixir;
        excalidraw-diagram = "${excalidraw-diagram-skill-wrapped}";
        explain-diff-html = ./ai/skills/explain-diff-html;
        explain-diff-markdown = ./ai/skills/explain-diff-markdown;
        explain-pr-body = ./ai/skills/explain-pr-body;
        explain-diff-video = ./ai/skills/explain-diff-video;
        graphql-schema-html = ./ai/skills/graphql-schema-html;
        herdr = "${herdr-skill}";
        herdr-core = "${herdr-core}/share/skills/herdr-core/herdr-core";
        humanizer = "${humanizer}";
        hunk-review = "${pkgs.hunk}/skills/hunk-review";
        kami = "${kami}/skills/kami";
        pi-authoring = "${pi-authoring-skill}";
        pr-preflight = ./ai/skills/pr-preflight;
        rebase = ./ai/skills/rebase;
        review-pi-work = ./ai/skills/review-pi-work;
        skill-critic = ./ai/skills/skill-critic;
        software-design = ./ai/skills/software-design;
        stop-slop = "${stop-slop}";
        todoist-cli = "${todoist-cli-skill}";
        voice-dna = ./ai/skills/voice-dna;
        voice-dna-creator = ./ai/skills/voice-dna-creator;
        worktrunk = "${worktrunkPluginRoot}/skills/worktrunk";
        writing-clearly-and-concisely = "${the-elements-of-style}/skills/writing-clearly-and-concisely";
        wt-switch-create = "${worktrunkPluginRoot}/skills/wt-switch-create";
        yue2-song = "${yue2SongSkill}";
        song-cover = "${songCoverSkill}";
        tts-speech = "${ttsSpeechSkill}";
        flashhead-video = "${flashheadVideoSkill}";
        talk = "${talkSkill}";
        stt-transcribe = "${sttTranscribeSkill}";
        narrated-video = "${narratedVideoSkill}";
        narrated-presentation = "${narratedPresentationSkill}";
        comfyui-remote = "${comfyuiSkills}/comfyui-remote";
        comfy-moss-image = "${comfyuiSkills}/comfy-moss-image";
        comfy-z-image = "${comfyuiSkills}/comfy-z-image";
        comfy-krea-2 = "${comfyuiSkills}/comfy-krea-2";
        comfy-flux2-klein = "${comfyuiSkills}/comfy-flux2-klein";
      }
      // lib.optionalAttrs config.jeff.enableZvecGrep {
        zg = ./ai/skills/zg;
      }
      // lib.optionalAttrs config.jeff.enableApolloSkills (
        builtins.listToAttrs (
          map
            (name: {
              inherit name;
              value = apollo_skills + "/skills/${name}";
            })
            (
              builtins.filter (
                name:
                (builtins.readDir (apollo_skills + "/skills")).${name} == "directory"
                && builtins.elem name apolloSkillsWanted
              ) (builtins.attrNames (builtins.readDir (apollo_skills + "/skills")))
            )
        )
      );
    };
  }; # end config
}
