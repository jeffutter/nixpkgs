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
}
