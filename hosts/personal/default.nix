{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
  ];

  homebrew.casks = [
    "adobe-dng-converter"
    "calibre"
    "fastrawviewer"
    "nvidia-geforce-now"
    "reaper"
    "rustdesk"
    "steam"
  ];

  homebrew.masApps = {
    "GarageBand" = 682658836;
  };

  users.users.jeffutter = {
    name = "jeffutter";
    home = "/Users/jeffutter";
  };

  system.primaryUser = "jeffutter";
  nix.settings.trusted-users = [ "jeffutter" ];
}
