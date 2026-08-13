{ pkgs, ... }:

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

  users.users.jeffutter = {
    name = "jeffutter";
    home = "/Users/jeffutter";
  };

  system.primaryUser = "jeffutter";
  nix.settings.trusted-users = [ "jeffutter" ];

  # Match existing Nix installation's GID
  ids.gids.nixbld = 350;
}
