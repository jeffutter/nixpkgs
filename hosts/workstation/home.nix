{
  pkgs,
  config,
  inputs,
  ...
}:

let
in
{
  # imports handled by flake.nix

  home.packages = with pkgs; [
    _1password-cli
  ];

  programs.ghostty = {
    enable = false;
  };

  programs.git.settings.user.email = "jeff@jeffutter.com";

  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "docker"
    "mosh"
    "kubectl"
    "vi-mode"
    "tmux"
    "1password"
    "debian"
  ];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
