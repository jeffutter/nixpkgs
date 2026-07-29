{ pkgs, ... }:

let
  # .envrc is almost always gitignored, so a fresh `wt` worktree starts without
  # one and the flake devshell never loads on cd. Recreate and trust it.
  #
  # pre-start blocks worktree creation, so the devshell is in place before any
  # post-start hook or `wt switch -x <cmd>` runs; post-start would race.
  #
  # Guarded three ways, since a user hook fires in every repository:
  #   no flake.nix          -> no-op, non-nix repos untouched
  #   .envrc already exists -> left alone, never clobbered
  #   direnv not installed  -> nested `if`, not `&&`; a bare `&&` that fails
  #                            returns non-zero and would abort creation
  direnvEnvrc = ''
    if test -f flake.nix && ! test -f .envrc; then
      echo "use flake" > .envrc || exit 1
      if command -v direnv >/dev/null; then direnv allow; fi
    fi
  '';
in
{
  # Worktrunk itself comes from modules/home/packages.nix.
  xdg.configFile."worktrunk/config.toml".source =
    (pkgs.formats.toml { }).generate "worktrunk-config.toml"
      {
        pre-start.direnv = direnvEnvrc;
      };
}
