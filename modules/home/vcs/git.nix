{ ... }:

{
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
    };
  };

  programs.delta = {
    enable = false;
    options = {
      side-by-side = true;
      line-numbers-left-format = "";
      line-numbers-right-format = "| ";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      aliases = {
        dft = "difftool";
        diffp = "--no-ext-diff";
      };
      user = {
        name = "Jeffery Utter";
        email = "jeff@jeffutter.com";
      };
      github = {
        user = "jeffutter";
      };
      fetch = {
        prune = true;
      };
      pull = {
        rebase = false;
      };
      init = {
        defaultBranch = "main";
      };
    };
    # Stylix handles delta theming
    ignores = [
      ".DS_Store?"
      ".Spotlight-V100"
      ".Trashes"
      "._*"
      ".aider*"
      ".direnv"
      ".elixir_ls"
      ".envrc"
      ".vscode"
      "DS_Store"
      "Thumbs.db"
      "ehthumbs.db"
      "hs_err*"
      "project-notes.org"
      "project_notes.org"
      "shell.nix"
    ];
  };
}
