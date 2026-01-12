{
  theme,
  ...
}:

{
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
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
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
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
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      sync_address = "https://atuin.home.jeffutter.com";
      search_mode = "fuzzy";
      update_check = false;
      # https://github.com/atuinsh/atuin/issues/1749
      timezone = "-6";
    };
  };

  programs.bat = {
    enable = true;
    themes = {
      "${theme.name}" = {
        src = theme.bat;
      };
    };
    config = {
      theme = theme.name;
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    changeDirWidgetCommand = "fd --type d";
    defaultCommand = "fd --type f";
    fileWidgetCommand = "fd --type f";
  };
}
