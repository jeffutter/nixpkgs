{ lib, pkgs, ... }:

let
  # Copied into the store, so the script never depends on a file living next to
  # it in ~/bin.
  excludeFile = ./restic-excludes.txt;

  # Pin Apple's ssh on macOS: the Nix restic wrapper prepends its own OpenSSH
  # build to PATH, which gets EHOSTUNREACH on the LAN and ignores UseKeychain.
  # Elsewhere restic's own ssh is fine, so pass no override.
  sftpOpts = lib.optionalString pkgs.stdenv.isDarwin ''-o "sftp.command=/usr/bin/ssh $SFTP_HOST -s sftp"'';

  backup = pkgs.writeShellApplication {
    name = "backup";
    # writeShellApplication already sets errexit/nounset/pipefail.
    runtimeInputs = [
      pkgs.restic
      pkgs.coreutils # date, uname
    ];
    text = ''
      set -x

      SFTP_HOST="jeffutter@truenas.local"
      SFTP_OPTS=(${sftpOpts})

      # Short hostname, so snapshots from each machine are distinguishable in a
      # shared repo. `uname -n` reports FQDNs on some hosts and Bonjour's
      # <name>.local on macOS; keep the first label.
      HOST_TAG="$(uname -n)"
      HOST_TAG="''${HOST_TAG%%.*}"

      cd ~

      # Extra args land before the backup root, so ad-hoc restic flags work:
      #   backup --dry-run
      restic -r "sftp:$SFTP_HOST:/mnt/data/restic/home" \
        "''${SFTP_OPTS[@]}" \
        --verbose \
        backup \
        --tag "$HOST_TAG" \
        --one-file-system \
        --tag "$(date +"%Y-%m-%dT%H:%M:%S%z")" \
        --exclude-caches \
        --exclude-file="${excludeFile}" \
        --exclude-if-present PG_VERSION \
        "$@" \
        ~/
    '';
  };
in
{
  home.packages = [ backup ];
}
