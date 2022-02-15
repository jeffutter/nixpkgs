{ ... }:

let
  m8c = pkgs.callPackage ../pkgs/m8c {};

in

{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    m8c
  ];

  programs.git.userEmail = "jeff@jeffutter.com";

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_rsa";

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../Brewfile.common)
    ''
    brew "exercism"
    cask "adobe-dng-converter"
    cask "calibre"
    cask "fastrawviewer"
    cask "reaper"
    cask "steam"
    cask "synology-drive"
    mas "Serial", id: 877615577
    ''
  ];

  home.username = "jeffutter";
  home.homeDirectory = "/Users/jeffutter";
}
