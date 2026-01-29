{
  config,
  pkgs,
  inputs,
  ...
}:

let
  beads = inputs.beads.packages.${pkgs.system}.default;
  beadsCompletions = pkgs.runCommand "beads-fish-completions" { } ''
    ${beads}/bin/bd completion fish > $out
  '';
in
{
  programs.fish = {
    enable = true;
    completions = {
      bd = builtins.readFile beadsCompletions;
      docker = builtins.readFile "${pkgs.docker}/share/fish/vendor_completions.d/docker.fish";
    };
    shellAbbrs = {
      "gcan!" = "git commit -v -a --no-edit --amend";
      dc = "docker compose";
      g = "git";
      gco = "git checkout";
      gpf = "git push --force";
      h = "himalaya";
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };
    shellAliases = {
      bzip2 = "pbzip2";
      cat = "bat -pp";
      df = "duf";
      gunzip = "pigz -d";
      gz = "pigz";
      ll = "eza -l --color always --icons -a -s type";
      ls = "eza -G --color auto -s type";
      xz = "pixz";
    };
    functions = {
      kca = "kubectl $argv --all-namespaces";
    };
    plugins = [
      {
        name = "fenv";
        src = inputs.fish-plugin-fenv;
      }
      {
        name = "autopair";
        src = inputs.fish-plugin-autopair;
      }
    ];
    shellInit = ''
      set fish_greeting

      set -x LANG "en_US.UTF-8"
      set -x LC_COLLATE "en_US.UTF-8"
      set -x LC_CTYPE "en_US.UTF-8"
      set -x LC_MESSAGES "en_US.UTF-8"
      set -x LC_MONETARY "en_US.UTF-8"
      set -x LC_NUMERIC "en_US.UTF-8"
      set -x LC_TIME "en_US.UTF-8"
      set -x LC_ALL "en_US.UTF-8"

      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && ! set -q NIX_GLOBAL_SOURCED
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        set -x  NIX_GLOBAL_SOURCED "true"
      end
      if [ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ] && ! set -q NIX_HOME_SOURCED
        fenv source ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh
        set -x NIX_HOME_SOURCED "true"
      end

      fish_add_path -p "$HOME/bin"
      fish_add_path -p "$HOME/homebrew/bin"
      fish_add_path -a /usr/local/bin
      fish_add_path -a /Applications/Docker.app/Contents/Resources/bin

      set -x HOMEBREW_CASK_OPTS "--appdir=$HOME/Applications"
      set -x ERL_AFLAGS "-kernel shell_history enabled"

      set -gx ATUIN_NOBIND "true"
      set -x RUST_SRC_PATH "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    '';
    interactiveShellInit = ''
      fish_vi_key_bindings
      bind -M default vv edit_command_buffer

      bind \cr _atuin_search
      bind -M insert \cr _atuin_search

      set -x GPG_TTY (tty)
      set -x PINENTRY_USER_DATA "USE_CURSES=1"
      set -x COLORTERM truecolor
      set -x AWS_DEFAULT_REGION "us-east-1";
      set -x AWS_PAGER "";
      set -x EDITOR "nvim";

      # Stylix handles LS_COLORS and fish theme colors
    '';
  };
}
