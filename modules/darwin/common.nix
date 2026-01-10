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
  # Homebrew package management - common configuration
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    caskArgs = {
      appdir = "~/Applications";
    };

    taps = [
      "1password/tap"
      "buo/cask-upgrade"
    ];

    brews = [
      "git"
      "mas"
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
      "docker-desktop"
      "fujifilm-x-webcam"
      "ghostty"
      "home-assistant"
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
    ];

    masApps = {
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
    };
  };

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

  # Match existing Nix installation's GID
  ids.gids.nixbld = 30000;

  # Use Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

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
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      "com.apple.swipescrolldirection" = false;
    };

    trackpad = {
      TrackpadRightClick = true;
      Clicking = false;
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
    };
  };
}
