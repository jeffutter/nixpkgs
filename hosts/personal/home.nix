{
  pkgs,
  config,
  inputs,
  ...
}:

let
  m8c = pkgs.callPackage ../../pkgs/m8c { };
in
{
  home.packages = with pkgs; [
    # m8c
    llvmPackages.bintools
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
}
