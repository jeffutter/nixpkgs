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

  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        disable = [
          "yadm"
          "node"
          "gem"
          "nix"
          "gcloud"
          "opam"
        ];
        ignore_failures = [ "containers" ];
        cleanup = true;
      };
      commands = {
        "Expire old home-manager configs" = "home-manager expire-generations '-1 week'";
        "Run garbage collection on Nix store" = "nix-collect-garbage --delete-older-than 7d";
      };
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
    changeDirWidgetCommand = "fd --type d";
    defaultCommand = "fd --type f";
    fileWidgetCommand = "fd --type f";
  };
}
