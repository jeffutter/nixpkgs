{ pkgs, lib, ... }:

let

  wrk2 = pkgs.wrk2.overrideAttrs (old: {
    buildPhase = ''
      export MACOSX_DEPLOYMENT_TAREGT=''${MACOSX_DEPLOYMENT_TARGET:-10.12}
      make
    '';

    meta.platforms = lib.platforms.darwin;
  });

  my_google-cloud-sdk = pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ];
in
{
  imports = [
    ../common.nix
    ../darwin.nix
  ];

  home.packages = with pkgs; [
    argocd

    llvmPackages.bintools
    # wrk2

    my_google-cloud-sdk
    aws-iam-authenticator
    awscli

    jdt-language-server
    maven
    google-java-format
    grpcurl

    kotlin
    kotlin-language-server
    ktlint
    # kcat

    colima

    # These won't build on aarch64, can be moved back into common once they do
    #topgrade
    cargo-watch
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
    (builtins.readFile ../Brewfile.common)
    ''
      cask "intellij-idea-ce"
      cask "jetbrains-toolbox"
      cask "swiftbar"
      mas "MuteKey", id: 1509590766
      mas "Slack", id: 803453959
      mas "Jira", id: 1475897096
    ''
  ];

  home.username = "jeffery.utter";
  home.homeDirectory = "/Users/Jeffery.Utter";
}
