# This file was created in whole or in part by generative AI.
{ pkgs, ... }:

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
  # Homebrew package management
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; # Remove formulae not in config (use "none" to be safe initially)
      upgrade = true;
    };
    caskArgs = {
      appdir = "~/Applications";
    };

    taps = [
      "1password/tap"
      "buo/cask-upgrade"
      "menubar-apps/menubar-apps"
      "fastrepl/hyprnote"
    ];

    brews = [
      "git"
      "mas"
    ];

    casks = [
      # Common
      "1password"
      "1password-cli"
      "charles"
      "claude"
      "contexts"
      "cyberduck"
      "dash"
      "discord"
      "docker-desktop"
      "fujifilm-x-webcam"
      "ghostty"
      "jordanbaird-ice"
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
      "hyprnote@nightly"
      # Work-specific
      "balenaetcher"
      "deskpad"
      "granola"
      "intellij-idea-ce"
      "jetbrains-toolbox"
      "pullbar"
      "rode-central"
      "shottr"
    ];

    masApps = {
      # Common
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "CARROTweather" = 993487541;
      "Foodnoms" = 1479461686;
      "GIPHY CAPTURE" = 668208984;
      "Home Assistant" = 1099568401;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Parcel" = 375589283;
      "Serial" = 877615577;
      "Tailscale" = 1475387142;
      "Todoist" = 585829637;
      "WireGuard" = 1451685025;
      # Work-specific
      "Jira" = 1475897096;
      "Slack" = 803453959;
      "Xcode" = 497799835;
    };
  };

  # Define the user
  users.users."jeffery.utter" = {
    name = "jeffery.utter";
    home = "/Users/Jeffery.Utter";
  };

  # Set primary user for user-specific settings
  system.primaryUser = "jeffery.utter";

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set Git commit hash for darwin-version to work.
  system.configurationRevision = null;

  # Used for backwards compatibility
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Match existing Nix installation's GID (installed before nix-darwin changed default from 30000 to 350)
  ids.gids.nixbld = 30000;

  # Use Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Remap Caps Lock to Escape
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Enable fish shell integration at system level (sets up PATH in /etc/fish/)
  programs.fish.enable = true;

  # System-level packages (available to all users)
  environment.systemPackages = with pkgs; [
    vim
  ];

  # System preferences - matching your current settings
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 48;
      mru-spaces = false; # Don't rearrange spaces based on most recent use
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      # Traditional (non-natural) scrolling
      "com.apple.swipescrolldirection" = false;
    };

    trackpad = {
      # Two-finger right click enabled
      TrackpadRightClick = true;
      # Tap to click disabled
      Clicking = false;
    };

    # Screenshot settings
    screencapture = {
      location = "~/Downloads";
    };

    # Finder settings
    finder = {
      FXPreferredViewStyle = "Nlsv"; # List view
    };

    # Menu bar clock settings
    menuExtraClock = {
      ShowAMPM = false;
      ShowDate = 0; # Don't show date
      ShowDayOfWeek = false;
    };

    CustomUserPreferences = {
      # Keyboard layout (Colemak)
      # Note: This sets the preference but may require logout/restart to take effect
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
        # Cmd+Shift+Z -> Zoom menu item
        NSUserKeyEquivalents = {
          Zoom = "@$z";
        };
      };

      # System keyboard shortcuts (symbolic hotkeys)
      #
      # These IDs are Apple's internal identifiers, not officially documented but stable.
      # Common IDs:
      #   15-26: Switch to Desktop 1-12
      #   28-31: Move window to desktop
      #   32-34: Mission Control
      #   60-61: Input source switching
      #   64: Spotlight, 65: Finder search
      #   79-82: Accessibility zoom
      #   98: Show Help menu
      #   160: Launchpad, 162: Notification Center, 164: Do Not Disturb
      #
      # To discover/add new shortcuts:
      #   1. Change the shortcut in System Settings → Keyboard → Keyboard Shortcuts
      #   2. Run: defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys
      #   3. Find the ID that changed and note its parameters
      #   4. Add it here using the `hotkey` or `disabled` helpers
      #
      # Parameter format: [ asciiCode keycode modifierFlags ]
      #   - asciiCode: ASCII value of key (65535 for special keys)
      #   - keycode: Virtual keycode (e.g., space=49, slash=44)
      #   - modifierFlags: Sum of mod.shift/ctrl/opt/cmd values
      #
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # Mission Control / Spaces shortcuts - DISABLED (using AeroSpace)
          "15" = disabled; # Switch to Desktop 1
          "16" = disabled; # Switch to Desktop 2
          "17" = disabled; # Switch to Desktop 3
          "18" = disabled; # Switch to Desktop 4
          "19" = disabled; # Switch to Desktop 5
          "20" = disabled; # Switch to Desktop 6
          "21" = disabled; # Switch to Desktop 7
          "22" = disabled; # Switch to Desktop 8
          "23" = disabled; # Switch to Desktop 9
          "24" = disabled; # Switch to Desktop 10
          "25" = disabled; # Switch to Desktop 11
          "26" = disabled; # Switch to Desktop 12

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
    };
  };
}
