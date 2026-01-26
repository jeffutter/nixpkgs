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
  imports = [
    ../../modules/home/languages/elixir.nix
    ../../modules/home/languages/rust.nix
    ../../modules/home/languages/go.nix
    ../../modules/home/languages/python.nix
    ../../modules/home/languages/javascript.nix
    ../../modules/home/languages/java.nix
    ../../modules/home/languages/ai.nix
  ];

  home.packages = with pkgs; [
    argocd
    colima
    grpcurl
    llvmPackages.bintools
    my_google-cloud-sdk
  ];

  home.file.".ssh/allowed_signers".text = ''
    jeffery.utter@pennentertainment.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoH8Rk7wSl/PdXDU0s/8F/e0z0/Brl1OdDDuJB7iLYO
  '';

  programs.git =
    let
      mkWorkConfig = dir: {
        condition = "gitdir:${dir}**";
        contents = {
          user.email = "jeffery.utter@pennentertainment.com";
          user.signingKey = "~/.ssh/id_ed25519-penn-interactive";
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
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

  programs.claude-code.settings.model = "opus";
}
