{ pkgs, ... }:

{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    jdk
  ];

  programs.git.userEmail = "jeffery.utter@thescore.com";

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  programs.keychain.keys = [ "id_ed25519" ];

  home.file."Brewfile".text = builtins.concatStringsSep "\n" [
    (builtins.readFile ../Brewfile.common)
    ''
    ''
  ];

  home.username = "Jeffery.Utter";
  home.homeDirectory = "/Users/Jeffery.Utter";
}
