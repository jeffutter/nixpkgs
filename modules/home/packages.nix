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
    doCheck = false;
    doInstallCheck = false;
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

  # worktrunk 0.68.0 has two unit tests that enumerate the OS process table;
  # both panic in the hermetic Nix build sandbox (own pid / child sh not
  # visible). Skip just those two so the rest of the suite still runs.
  worktrunk = pkgs.worktrunk.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=shell::utils::tests::test_process_name_and_ppid_self"
      "--skip=shell::utils::tests::test_probe_reports_invoked_name_for_sh"
    ];
  });
in

{
  home.packages = with pkgs; [
    inputs.nix-options-search.packages.${pkgs.stdenv.hostPlatform.system}.default
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
