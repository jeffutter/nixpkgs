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

  # A fresh worktree has no node_modules and no gitignored CLAUDE.local.md, so
  # every agent session in it first fails a build, then installs. Both guarded
  # so repos without a pnpm lockfile or a local rules file are untouched.
  # CI=1 keeps pnpm from running `lefthook install` into the shared .git.
  postStartSetup = ''
    if test -f pnpm-lock.yaml && ! test -d node_modules; then
      CI=1 pnpm install --frozen-lockfile
    fi
    if test -f "{{ primary_worktree_path }}/CLAUDE.local.md" && ! test -e CLAUDE.local.md; then
      cp "{{ primary_worktree_path }}/CLAUDE.local.md" CLAUDE.local.md
    fi
  '';
in
{
  # Worktrunk itself comes from modules/home/packages.nix.
  xdg.configFile."worktrunk/config.toml".source =
    (pkgs.formats.toml { }).generate "worktrunk-config.toml"
      {
        pre-start.direnv = direnvEnvrc;
        post-start.setup = postStartSetup;
      };
}
