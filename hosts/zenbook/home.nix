{ lib, ... }:
{
  imports = [
    ../../modules/home/languages/rust.nix
    ../../modules/home/languages/javascript.nix
    ../../modules/home/languages/ai.nix
    ../../modules/home/opencode.nix
    ./gui/eww.nix
    ./gui/hyprland.nix
    ./gui/idle.nix
    ./gui/apps.nix
  ];

  # OLED energy savings: override background colors to pure black
  stylix.override = {
    base00 = "000000"; # Default background
    base01 = "000000"; # Lighter background
    base02 = "111111"; # Selection background (slightly lighter for visibility)
  };

  # Apply same OLED background overrides to Neovim (Stylix is disabled for it)
  programs.nixvim.colorschemes.tokyonight.settings.on_colors =
    lib.mkForce "function(colors) colors.bg = '#000000' colors.bg_dark = '#000000' colors.bg_highlight = '#111111' colors.comment = '#b4bcd0' end";

  programs.claude-code.settings.model = "sonnet";

  programs.ghostty = {
    enable = true;
  };

  home.file.".ssh/allowed_signers".text = ''
    jeff@jeffutter.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdcZzshajKcShGRcADGbH2V3Dzjv+C65imbg2/B6gkh
  '';

  programs.git.settings = {
    user.email = "jeff@jeffutter.com";
    gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
  };

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
