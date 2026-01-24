{
  pkgs,
  config,
  inputs,
  ...
}:

let
  happy = pkgs.callPackage ../../pkgs/happy { happy-src = inputs.happy; };
in

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
    happy
  ];

  programs.ghostty = {
    enable = false;
  };

  programs.git.settings.user.email = "jeff@jeffutter.com";

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";

  programs.claude-code.settings.model = "sonnet";

  # Disable GTK/dconf targets for headless LXC container
  stylix.targets.gtk.enable = false;
  dconf.enable = false;
}
