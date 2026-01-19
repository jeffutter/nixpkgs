{
  pkgs,
  inputs,
  ...
}:

let
  inherit (pkgs.lib) optionals;

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  gnutar = pkgs.gnutar.overrideAttrs (old: {
    configureFlags = [
      "--with-gzip=pigz"
      "--with-xz=pixz"
      "--with-bzip2=pbzip2"
      "--with-zstd=pzstd"
    ]
    ++ optionals pkgs.stdenv.isDarwin [
      "gt_cv_func_CFPreferencesCopyAppValue=no"
      "gt_cv_func_CFLocaleCopyCurrent=no"
      "gt_cv_func_CFLocaleCopyPreferredLanguages=no"
    ];
  });
in

{
  home.packages = with pkgs; [
    inputs.nix-options-search.packages.${pkgs.stdenv.hostPlatform.system}.default
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    autoconf
    bandwhich
    bash-completion
    bash
    btop
    bzip2
    cachix
    colmena
    comma
    curl
    difftastic
    docker
    duckdb
    dust
    duf
    eza
    fd
    gawk
    gh
    git-absorb
    git-lfs
    gnused
    gnupg
    grex
    htop
    hyperfine
    hunspell
    hunspellDicts.en_US
    ijq
    imagemagick
    ispell
    jq
    jujutsu
    k6
    kubectl
    kubectx
    (pkgs.kubectl-node-shell.overrideAttrs (
      {
        meta ? { },
        ...
      }:
      {
        meta = meta // {
          platforms = pkgs.lib.platforms.unix;
        };
      }
    ))
    lftp
    mprocs
    mosh
    ncdu
    nixfmt
    p7zip
    pigz
    pixz
    pbzip2
    protobuf
    pstree
    pv
    ripgrep
    restic
    rsync
    ruplacer
    shellcheck
    sshfs
    ssh-copy-id
    gnutar
    #tlaplus
    tmate
    unzip
    unixtools.watch
    viddy
    vips
    # (builtins.getFlake "github:jeffutter/wakeonlan-rust/v0.1.1")
    wavpack
    wakatime-cli
    wget
    xz
    yq-go
    zstd
  ];
}
