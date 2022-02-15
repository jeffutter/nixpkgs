{ pkgs, config, ... }:

let
  m8c = pkgs.callPackage ../../pkgs/m8c {};

  pkgsX86 = import <nixpkgs> { localSystem = "x86_64-darwin"; overlays = config.nixpkgs.overlays; };

in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    # m8c
    pkgsX86.cargo-watch
    pkgsX86.topgrade
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
