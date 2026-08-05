{ pkgs, lib, ... }:

let
  # Helper for symbolic hotkey modifiers
  mod = {
    shift = 131072;
    ctrl = 262144;
    opt = 524288;
    cmd = 1048576;
  };

  # Helper to create a symbolic hotkey entry
  hotkey =
    {
      enabled ? true,
      key ? 65535,
      keycode,
      mods ? 0,
    }:
    {
      enabled = if enabled then 1 else 0;
      value = {
        parameters = [
          key
          keycode
          mods
        ];
        type = "standard";
      };
    };

  # Common keycodes
  keycodes = {
    space = 49;
    slash = 44;
    n = 45;
    "3" = 20;
    "4" = 21;
    "5" = 23;
  };

  # Simple disabled shortcut (no parameters needed)
  disabled = {
    enabled = 0;
  };
in
{
  time.timeZone = "America/Chicago";

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
      # Originally a workaround: Homebrew 5.x refuses `brew bundle install
      # --cleanup` without --force/--force-cleanup/$HOMEBREW_ASK. nix-darwin now
      # passes --force-cleanup itself for cleanup = "zap", so that part is
      # redundant. What's left is that --force also reaches `brew install
      # --cask`, letting casks overwrite an existing app bundle. Keeping it for
      # that; drop it if cask installs start clobbering something they
      # shouldn't.
      extraFlags = [ "--force" ];
    };
    caskArgs = {
      appdir = "~/Applications";
    };

    # `trusted` is required on every non-official tap. Homebrew 6.0 turned on
    # HOMEBREW_REQUIRE_TAP_TRUST, so an untrusted tap's formulae hard-error and
    # its casks/commands are silently skipped during activation. Trust can't be
    # granted out-of-band with `brew trust` either: activation runs
    # `brew bundle --force-cleanup`, and cleanup calls Trust.replace!, which
    # overwrites ~/.homebrew/trust.json with exactly what the Brewfile declares.
    # Anything trusted by hand is wiped on the next rebuild.
    taps = [
      {
        name = "1password/tap";
        trusted = true;
      }
      {
        name = "buo/cask-upgrade";
        trusted = true;
      }
    ];

    brews = [
      "git"
      "mas"
      "mole"
    ];

    casks = [
      "1password"
      "1password-cli"
      "charles"
      "claude"
      "contexts"
      "cyberduck"
      "dash"
      "discord"
      "ghostty"
      "leader-key"
      "localsend"
      "loopback"
      "obsidian"
      "postico"
      "raycast"
      "screenflow"
      "soundsource"
      "stats"
      "switchresx"
      "visual-studio-code"
      "voiceink"
      "wireshark-app"
      "zen"
      "zoom"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "CARROTweather" = 993487541;
      "Foodnoms" = 1479461686;
      "GIPHY CAPTURE" = 668208984;
      "Home Assistant" = 1099568401;
      "Keynote" = 361285480;
      "Numbers" = 361304891;
      "Parcel" = 375589283;
      "Serial" = 877615577;
      "Tailscale" = 1475387142;
      "Todoist" = 585829637;
      "WireGuard" = 1451685025;
    };
  };

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 1;
      Hour = 0;
      Minute = 0;
    };
    options = "--delete-older-than 8d";
  };

  # Note: nixpkgs.config is set in flake.nix when using home-manager.useGlobalPkgs

  # Set Git commit hash for darwin-version to work.
  system.configurationRevision = null;

  # Used for backwards compatibility
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Match existing Nix installation's GID
  ids.gids.nixbld = 350;

  # Use Touch ID for sudo (reattach enables tmux support)
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Remap Caps Lock to Escape
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Enable fish shell integration at system level
  programs.fish.enable = true;

  # System-level packages
  environment.systemPackages = with pkgs; [
    vim
  ];

  # System preferences
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 48;
      mru-spaces = false;
      show-recents = false;
      expose-group-apps = true;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      AppleShowScrollBars = "WhenScrolling";
      "com.apple.swipescrolldirection" = false;
      # Full Keyboard Access: Tab moves focus between every control, not just
      # text fields and lists.
      AppleKeyboardUIMode = 2;
    };

    trackpad = {
      TrackpadRightClick = true;
      Clicking = false;
      # Disable three-finger tap (Look up & data detectors).
      TrackpadThreeFingerTapGesture = 0;
    };

    # AeroSpace owns window management, so the built-in tiling and
    # Stage Manager gestures are turned off to stay out of its way.
    WindowManager = {
      EnableTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTiledWindowMargins = false;
      EnableStandardClickToShowDesktop = false;
      HideDesktop = true;
      AppWindowGroupingBehavior = true;
    };

    screencapture = {
      location = "~/Downloads";
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";
    };

    menuExtraClock = {
      ShowAMPM = false;
      ShowDate = 0;
      ShowDayOfWeek = false;
    };

    iCal = {
      CalendarSidebarShown = true;
    };

    CustomUserPreferences = {
      # Keyboard layout (Colemak)
      "com.apple.HIToolbox" = {
        AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.Colemak";
        AppleEnabledInputSources = [
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 0;
            "KeyboardLayout Name" = "U.S.";
          }
          {
            "Bundle ID" = "com.apple.CharacterPaletteIM";
            InputSourceKind = "Non Keyboard Input Method";
          }
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 12825;
            "KeyboardLayout Name" = "Colemak";
          }
          {
            "Bundle ID" = "com.apple.PressAndHold";
            InputSourceKind = "Non Keyboard Input Method";
          }
        ];
      };

      # Global keyboard shortcut overrides
      NSGlobalDomain = {
        NSUserKeyEquivalents = {
          Zoom = "@$z";
        };

        # System Settings > Keyboard > Text Replacements
        NSUserDictionaryReplacementItems = [
          {
            on = 1;
            replace = "ddx";
            "with" = "Datadex";
          }
          {
            on = 1;
            replace = "omw";
            "with" = "On my way!";
          }
          {
            on = 1;
            replace = "*shrug*";
            "with" = "¯\\_(ツ)_/¯";
          }
          {
            on = 1;
            replace = "pn";
            "with" = "partner";
          }
          {
            on = 1;
            replace = "lh";
            "with" = "lighthouse";
          }
          {
            on = 1;
            replace = "interp";
            "with" = "interpreter";
          }
          {
            on = 1;
            replace = "tdu";
            "with" = "Thank you,\nDr. Utter";
          }
        ];

        # Mute the alert beep entirely (and don't flash the screen instead).
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.flash" = 0;

        # Trackpad tracking speed; macOS default is 0.6875.
        "com.apple.trackpad.scaling" = 0.875;
      };

      # Menu bar item visibility (System Settings > Control Center).
      # Positions are deliberately not managed — they're pixel offsets that
      # depend on display width.
      "com.apple.controlcenter" = {
        "NSStatusItem Visible Battery" = false;
        "NSStatusItem Visible FocusModes" = false;
        "NSStatusItem Visible Shortcuts" = false;
        "NSStatusItem Visible BentoBox" = true;
      };

      "com.apple.screencapture" = {
        showsClicks = true; # Highlight clicks in screen recordings
        captureDelay = 5.0; # Countdown before a timed capture, in seconds
      };

      # System keyboard shortcuts (symbolic hotkeys)
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # Mission Control / Spaces shortcuts - DISABLED (using AeroSpace)
          "15" = disabled;
          "16" = disabled;
          "17" = disabled;
          "18" = disabled;
          "19" = disabled;
          "20" = disabled;
          "21" = disabled;
          "22" = disabled;
          "23" = disabled;
          "24" = disabled;
          "25" = disabled;
          "26" = disabled;

          # Move window to desktop - DISABLED
          "28" = hotkey {
            enabled = false;
            key = 51;
            keycode = keycodes."3";
            mods = mod.cmd + mod.opt;
          };
          "29" = hotkey {
            enabled = false;
            key = 51;
            keycode = keycodes."3";
            mods = mod.cmd + mod.opt + mod.shift;
          };
          "30" = hotkey {
            enabled = false;
            key = 52;
            keycode = keycodes."4";
            mods = mod.cmd + mod.opt;
          };
          "31" = hotkey {
            enabled = false;
            key = 52;
            keycode = keycodes."4";
            mods = mod.cmd + mod.opt + mod.shift;
          };

          # Spotlight - DISABLED (using Raycast)
          "64" = hotkey {
            enabled = false;
            keycode = keycodes.space;
            mods = mod.cmd;
          };
        };
      };

      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true; # No .DS_Store on network
        DSDontWriteUSBStores = true;
      };
    };
  };
}
