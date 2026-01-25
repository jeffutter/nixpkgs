{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
    ../../modules/common/i18n.nix
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

  users.users.jeffutter = {
    name = "jeffutter";
    home = "/Users/jeffutter";
  };

  system.primaryUser = "jeffutter";
  nix.settings.trusted-users = [ "jeffutter" ];
}
