{ pkgs, config, ... }:

let
in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    _1password-cli
    # binutils
    llvmPackages_13.bintools-unwrapped
    clang_13
    cargo-watch
  ];

  programs.ghostty = {
    enable = false;
  };

  programs.git.userEmail = "jeff@jeffutter.com";

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
