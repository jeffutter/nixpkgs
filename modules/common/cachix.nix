{
  ...
}:
{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://jeffutter.cachix.org"
      "https://nix-community.cachix.org"
      "https://colmena.cachix.org"
    ];

    trusted-public-keys = [
      "jeffutter.cachix.org-1:ANzVqMBfIdjVJm1I7wAD/Dmr7hkqtsX6gWf+VXvC7Uw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
    ];
  };

}
