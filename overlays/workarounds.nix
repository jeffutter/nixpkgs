inputs: final: prev: {
  # The nix-options-search flake builds zstd-sys without pkg-config and libzstd, and the
  # build fails on current nixpkgs. Delete this once the flake declares them itself (check
  # with a plain `inputs.nix-options-search.packages.<system>.default` build).
  nix-options-search =
    inputs.nix-options-search.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
        buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd ];
      });

  # rustaceanvim's luarocks check phase starts rust-analyzer and waits for it to index a
  # workspace; that times out in the nix sandbox on macOS (9.2.2-2), which fails the whole
  # system build. Same plugin, check phase off. Delete once the upstream check passes in the
  # sandbox again.
  vimPlugins = prev.vimPlugins.extend (
    _: _: {
      rustaceanvim = prev.neovimUtils.buildNeovimPlugin {
        luaAttr = prev.neovim-unwrapped.lua.pkgs.rustaceanvim.overrideAttrs { doCheck = false; };
      };
    }
  );
}
