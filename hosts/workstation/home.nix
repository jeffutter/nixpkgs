{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/home/languages/elixir.nix
    ../../modules/home/languages/rust.nix
    ../../modules/home/languages/python.nix
    ../../modules/home/languages/javascript.nix
    ../../modules/home/languages/ai.nix
  ];

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
