{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.14.1";

  # Repackages the same prebuilt release archives
  # https://github.com/Paca-AI/paca/releases/download/install-acp-bridge.sh
  # would otherwise curl-pipe-bash download and unpack itself. No
  # checksums.txt is published alongside these releases, so hashes here
  # were fetched and pinned by hand (nix-prefetch-url) against v0.14.1.
  sources = {
    "x86_64-linux" = {
      url = "https://github.com/Paca-AI/paca/releases/download/v${version}/paca-acp-bridge_${version}_linux_amd64.tar.gz";
      hash = "sha256-sIcXJXBLw+/nyY1eCYJ4yMFObVMuM6GtMj8YkH13J/M=";
    };
    "aarch64-linux" = {
      url = "https://github.com/Paca-AI/paca/releases/download/v${version}/paca-acp-bridge_${version}_linux_arm64.tar.gz";
      hash = "sha256-hvOFeSU4lOWxJPvwBg8zpi68TJyppciR42TIRPIPWwA=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/Paca-AI/paca/releases/download/v${version}/paca-acp-bridge_${version}_darwin_amd64.tar.gz";
      hash = "sha256-5VRCn9xBuB6IfwFnE8rrt4gx0ydT30qaw8Vuu931tSg=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/Paca-AI/paca/releases/download/v${version}/paca-acp-bridge_${version}_darwin_arm64.tar.gz";
      hash = "sha256-xeUAjv7OOY9HsIFP7vO86/bd3W/uSzjGyFWXGyB+ECo=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "paca-acp-bridge";
  inherit version;

  src = fetchurl sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 paca-acp-bridge $out/bin/paca-acp-bridge
    runHook postInstall
  '';

  meta = {
    description = "Bridges a Paca ACP-type agent to a coding CLI running on this machine";
    homepage = "https://github.com/Paca-AI/paca/tree/master/apps/acp-bridge";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames sources;
    mainProgram = "paca-acp-bridge";
  };
}
