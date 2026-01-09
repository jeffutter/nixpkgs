{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  my_google-cloud-sdk = pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ];
in
{
  home.packages = with pkgs; [
    argocd

    llvmPackages.bintools

    my_google-cloud-sdk

    maven
    google-java-format
    grpcurl

    colima
  ];

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  programs.git =
    let
      mkWorkConfig = dir: {
        condition = "gitdir:${dir}";
        contents = {
          user.email = "jeffery.utter@thescore.com";
          signing.key = "~/.ssh/id_ed25519-penn-interactive";
          commit.gpgSign = true;
          tag.gpgSign = true;
        };
      };
    in
    {
      includes = [
        (mkWorkConfig "~/theScore/")
      ];
      ignores = [
        ".classpath"
        ".factorypath"
        ".project"
        ".settings"
      ];
      settings = {
        url."git@github.com-penn-interactive:penn-interactive/" = {
          insteadOf = "git@github.com:penn-interactive/";
        };
      };
    };

  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "docker"
    "mosh"
    "kubectl"
    "macos"
    "vi-mode"
    "gcloud"
    "tmux"
    "1password"
  ];

  programs.ssh = {
    matchBlocks = {
      "github.com-penn-interactive" = {
        hostname = "github.com";
        user = "git";
        addKeysToAgent = "yes";
        identitiesOnly = true;
        identityFile = "~/.ssh/id_ed25519-penn-interactive";
      };
    };
  };

  programs.keychain.keys = [ "id_ed25519" ];

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../../systems/Brewfile.common)
    ''
      cask "balenaetcher"
      cask "deskpad"
      cask "intellij-idea-ce"
      cask "jetbrains-toolbox"
      cask "pullbar"
      cask "rode-central"
      cask "shottr"
      mas "Jira", id: 1475897096
      mas "Slack", id: 803453959
      mas "Xcode", id: 497799835
      tap "menubar-apps/menubar-apps"
    ''
  ];

  home.username = "jeffery.utter";
  home.homeDirectory = "/Users/Jeffery.Utter";
}
