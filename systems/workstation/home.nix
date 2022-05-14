{ pkgs, config, ... }:

let

in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    cargo-watch
  ];

  programs.git.userEmail = "jeff@jeffutter.com";

  programs.zsh.oh-my-zsh.plugins = ["git" "docker" "mosh" "kubectl" "vi-mode" ];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
