{
  pkgs,
  ...
}:

let
  inherit (pkgs.lib) optionals;

  osewa = pkgs.callPackage ../../pkgs/osewa { };

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  gnutar = pkgs.gnutar.overrideAttrs (old: {
    doCheck = false;
    doInstallCheck = false;
    configureFlags = [
      "--with-gzip=pigz"
      "--with-xz=pixz"
      "--with-bzip2=pbzip2"
      "--with-zstd=pzstd"
    ]
    ++ optionals pkgs.stdenv.hostPlatform.isDarwin [
      "gt_cv_func_CFPreferencesCopyAppValue=no"
      "gt_cv_func_CFLocaleCopyCurrent=no"
      "gt_cv_func_CFLocaleCopyPreferredLanguages=no"
    ];
  });
in

{
  # `osewa login` runs the remote binary at the hardcoded path ~/.local/bin/osewa (enroll,
  # server --daemon, service restart), and skips its own install when it finds an identical
  # osewa on PATH - as the Nix one is. Without this link, logging in to a host fails with
  # exit 127.
  home.file.".local/bin/osewa".source = "${osewa}/bin/osewa";

  home.packages = with pkgs; [
    nix-options-search
    ast-grep
    autoconf
    bandwhich
    bash
    bash-completion
    bats
    btop
    bzip2
    cachix
    (pkgs.callPackage ../../pkgs/colgrep { })
    colmena
    comma
    curl
    difftastic
    docker
    osewa
    duckdb
    duf
    dust
    eza
    fd
    gawk
    gh
    git-absorb
    git-lfs
    glow
    gnupg
    gnused
    htop
    hunk
    hyperfine
    ijq
    imagemagick
    jq
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
    moreutils
    mosh
    ncdu
    nixfmt
    nix-output-monitor
    nix-sweep
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
    unzip
    unixtools.watch
    viddy
    wget
    worktrunk
    xz
    yq-go
    zstd
  ];
}
