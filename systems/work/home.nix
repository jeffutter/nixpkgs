{ pkgs, platforms, ... }:

let

  wrk2 = pkgs.wrk2.overrideAttrs (old: {
    buildPhase = ''
      export MACOSX_DEPLOYMENT_TAREGT=''${MACOSX_DEPLOYMENT_TARGET:-10.12}
      make
    '';

    meta.platform = platforms.darwin;
  });

in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    wrk2

    kubectx
    google-cloud-sdk

    jdk
    maven
    google-java-format

    # These won't build on aarch64, can be moved back into common once they do
    topgrade
    cargo-watch
  ];

  programs.git = {
    userEmail = "jeffery.utter@thescore.com";
    signing.key = "577723BC097175AA";
    signing.signByDefault = true;
    ignores = [ ".classpath" ".factorypath" ".project" ".settings" ];
  };

  programs.zsh.oh-my-zsh.plugins = ["git" "docker" "mosh" "kubectl" "macos" "vi-mode" "gcloud"];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  programs.keychain.keys = [ "id_ed25519" ];

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../Brewfile.common)
    ''
    mas "Slack", id: 803453959
    ''
  ];

  home.username = "Jeffery.Utter";
  home.homeDirectory = "/Users/Jeffery.Utter";
}
