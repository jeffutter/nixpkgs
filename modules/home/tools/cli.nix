{ pkgs, ... }:

{
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.himalaya = {
    enable = true;
    # nixpkgs' himalaya 2.2.1 lacks these link inputs (libgit2 for pkg-config, sqlite for -lsqlite3).
    # Drop this once nixpkgs fixes it.
    package = pkgs.himalaya.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [
        pkgs.libgit2
        pkgs.sqlite
        pkgs.zlib
      ];
    });
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
    # The e2e_capture pty test times out in the darwin build sandbox.
    package =
      if pkgs.stdenv.hostPlatform.isDarwin then
        pkgs.atuin.overrideAttrs { doCheck = false; }
      else
        pkgs.atuin;
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
