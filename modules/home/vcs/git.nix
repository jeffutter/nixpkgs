{ ... }:

{
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
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
    ignores = [
      ".DS_Store?"
      ".Spotlight-V100"
      ".Trashes"
      "._*"
      ".aider*"
      ".direnv"
      ".elixir_ls"
      ".envrc"
      ".expert"
      ".pi/continue/"
      ".vscode"
      ".zvec-grep/"
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
