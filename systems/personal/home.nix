{ pkgs, config, ... }:

let
  m8c = pkgs.callPackage ../../pkgs/m8c {};

  pkgsX86 = import <nixpkgs> { localSystem = "x86_64-darwin"; overlays = config.nixpkgs.overlays; };

in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    # m8c
    llvmPackages.bintools
    pkgsX86.cargo-watch
  ];

  programs.starship.package = pkgsX86.starship;
  programs.topgrade.package = pkgsX86.topgrade;

  programs.git.userEmail = "jeff@jeffutter.com";

  programs.zsh.oh-my-zsh.plugins = ["git" "docker" "mosh" "kubectl" "macos" "vi-mode" "tmux" "1password"];

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
