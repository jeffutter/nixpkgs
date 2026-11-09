# Gate only build failures here; a runtime-bug fix that switches off brings the bug back silently.
inputs: final: prev:
let
  inherit (prev) lib;
  nixpkgsRev = inputs.nixpkgs.rev;

  workaround =
    {
      name,
      active,
      patched,
      stock,
    }:
    if active then
      patched
    else
      lib.warn "workaround '${name}' is switched off on this nixpkgs (${nixpkgsRev}); if everything builds, delete it. If it fails, re-enable the gate." stock;

  # Current nixpkgs leaves these link inputs unresolved for crates that need them.
  brokenLinksRev = "f4a03c008967841f2a0b3cb7c436fc6fc31671f6";

  withBuildInputs =
    pkg: inputs':
    pkg.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ inputs';
    });

  linkFix =
    name: stock: inputs':
    workaround {
      inherit name stock;
      active = nixpkgsRev == brokenLinksRev;
      patched = withBuildInputs stock inputs';
    };

  nix-options-search-stock =
    inputs.nix-options-search.packages.${prev.stdenv.hostPlatform.system}.default;
in
{
  himalaya = linkFix "himalaya libgit2/sqlite" prev.himalaya [
    prev.libgit2
    prev.sqlite
    prev.zlib
  ];
  viddy = linkFix "viddy sqlite" prev.viddy [ prev.sqlite ];
  cargo-outdated = linkFix "cargo-outdated sqlite" prev.cargo-outdated [ prev.sqlite ];
  sqlx-cli = linkFix "sqlx-cli sqlite" prev.sqlx-cli [ prev.sqlite ];

  nix-options-search = workaround {
    name = "nix-options-search zstd";
    active = nixpkgsRev == brokenLinksRev;
    stock = nix-options-search-stock;
    patched = nix-options-search-stock.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd ];
    });
  };
}
