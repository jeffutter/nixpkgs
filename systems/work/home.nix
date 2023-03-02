{ pkgs, lib, ... }:

let

  wrk2 = pkgs.wrk2.overrideAttrs (old: {
    buildPhase = ''
      export MACOSX_DEPLOYMENT_TAREGT=''${MACOSX_DEPLOYMENT_TARGET:-10.12}
      make
    '';

    meta.platforms = lib.platforms.darwin;
  });

  my_google-cloud-sdk = pkgs.google-cloud-sdk.withExtraComponents [pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin];

in
{
  imports = [
    ../common.nix
    ../darwin.nix
  ];

  home.packages = with pkgs; [
    llvmPackages.bintools
    wrk2

    my_google-cloud-sdk

    jdt-language-server
    maven
    google-java-format
    grpcurl

    kotlin
    kotlin-language-server
    ktlint
    kcat

    # These won't build on aarch64, can be moved back into common once they do
    #topgrade
    cargo-watch
  ];

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  programs.git = {
    userEmail = "jeffery.utter@thescore.com";
    signing.key = "577723BC097175AA";
    signing.signByDefault = true;
    ignores = [ ".classpath" ".factorypath" ".project" ".settings" ];
  };

  programs.zsh.oh-my-zsh.plugins = ["git" "docker" "mosh" "kubectl" "macos" "vi-mode" "gcloud" "tmux" "1password"];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  programs.keychain.keys = [ "id_ed25519" ];

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../Brewfile.common)
    ''
    cask "elgato-stream-deck"
    cask "intellij-idea-ce"
    cask "jetbrains-toolbox"
    cask "swiftbar"
    mas "MuteKey", id: 1509590766
    mas "Slack", id: 803453959
    ''
  ];

  home.username = "Jeffery.Utter";
  home.homeDirectory = "/Users/Jeffery.Utter";
}
