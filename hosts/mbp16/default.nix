{ pkgs, config, ... }:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
  ];

  homebrew.casks = [
    "fastrawviewer"
    "reaper"
    "steam"
  ];

  homebrew.masApps = {
  };

  # Dock contents. nix-darwin owns this list, so rearranging the Dock by hand
  # gets reverted on the next rebuild — edit here instead.
  system.defaults.dock = {
    persistent-apps = [
      { app = "/System/Applications/Apps.app"; }
      { app = "${homeDir}/Applications/Zen.app"; }
      { app = "${homeDir}/Applications/Ghostty.app"; }
      { app = "/System/Applications/Messages.app"; }
      { app = "/System/Applications/Mail.app"; }
      { app = "/System/Applications/Calendar.app"; }
      { app = "/System/Applications/Music.app"; }
      { app = "/System/Applications/System Settings.app"; }
    ];

    persistent-others = [
      {
        folder = {
          path = "${homeDir}/Downloads";
          arrangement = "date-added";
          displayas = "stack";
          showas = "fan";
        };
      }
    ];
  };

  users.users.jeffutter = {
    name = "jeffutter";
    home = "/Users/jeffutter";
  };

  system.primaryUser = "jeffutter";
  nix.settings.trusted-users = [ "jeffutter" ];

  # Match existing Nix installation's GID
  ids.gids.nixbld = 350;
}
