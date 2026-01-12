{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    delve
    go
    gofumpt
    gomodifytags
    gore
    goreleaser
    gotest
    gotools
    impl
  ];
}
