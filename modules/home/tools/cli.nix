{ ... }:

{
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.himalaya = {
    enable = true;
    settings = {
      name = "Jeffery Utter";
    };
  };

  programs.keychain = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv = {
      enable = true;
    };
    config = {
      global = {
        load_dotenv = false;
      };
    };
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      daemon = {
        enabled = true;
        autostart = true;
      };
      filter_mode_shell_up_key_binding = "session";
      search_mode = "fuzzy";
      sync_address = "https://atuin.home.jeffutter.com";
      update_check = false;
      inline_height_shell_up_key_binding = 10;
    };
  };

  programs.bat = {
    enable = true;
    # Stylix handles theming
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    changeDirWidget.command = "fd --type d";
    defaultCommand = "fd --type f";
    fileWidget.command = "fd --type f";
  };
}
