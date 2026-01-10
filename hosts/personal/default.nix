# This file was created in whole or in part by generative AI.
{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
  ];

  homebrew.casks = [
    "adobe-dng-converter"
    "calibre"
    "fastrawviewer"
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
