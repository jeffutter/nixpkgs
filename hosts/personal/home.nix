{ pkgs, config, inputs, ... }:

let
  m8c = pkgs.callPackage ../../pkgs/m8c { };
in
{
  # imports handled by flake.nix

  home.packages = with pkgs; [
    # m8c
    llvmPackages.bintools
    cargo-watch
  ];

  programs.git.settings.user.email = "jeff@jeffutter.com";

  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "docker"
    "mosh"
    "kubectl"
    "macos"
    "vi-mode"
    "tmux"
    "1password"
  ];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_rsa";

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../../systems/Brewfile.common)
    ''
      brew "exercism"
      cask "adobe-dng-converter"
      cask "calibre"
      cask "fastrawviewer"
      cask "reaper"
      cask "steam"
      mas "Serial", id: 877615577
    ''
  ];

  home.username = "jeffutter";
  home.homeDirectory = "/Users/jeffutter";
}
