{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
  gzip,
}:

let
  version = "3.16.0";

  # ldcli is not in nixpkgs, so we repackage the upstream prebuilt Go release
  # binaries. `bin/update-ldcli` refreshes the version and these hashes.
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/launchdarkly/ldcli/releases/download/v${version}/ldcli_${version}_darwin_arm64.tar.gz";
      hash = "sha256-Ye8RG4oT3JrkjQqMk2hRJGZsU4QJe6yZXvPfdvnswLo=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/launchdarkly/ldcli/releases/download/v${version}/ldcli_${version}_darwin_amd64.tar.gz";
      hash = "sha256-KSIYhEE8JBwNoXmf9IaEdQYeCP8SO7xeGAEbYrt/neQ=";
    };
    "aarch64-linux" = {
      url = "https://github.com/launchdarkly/ldcli/releases/download/v${version}/ldcli_${version}_linux_arm64.tar.gz";
      hash = "sha256-ILj0BzGqgMtZlF0vaOqZ+ldFM5VNYiAs+nIP32IEi4M=";
    };
    "x86_64-linux" = {
      url = "https://github.com/launchdarkly/ldcli/releases/download/v${version}/ldcli_${version}_linux_amd64.tar.gz";
      hash = "sha256-E9tzpoY04YBCDriVKFc7vsSiYqEPNBkEKavugCL/SvI=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "ldcli";
  inherit version;

  src = fetchurl (
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "ldcli: unsupported system ${stdenvNoCC.hostPlatform.system}")
  );

  dontUnpack = true;

  nativeBuildInputs = [
    gnutar
    gzip
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin" ldcli
    chmod +x "$out/bin/ldcli"
    runHook postInstall
  '';

  meta = {
    description = "LaunchDarkly CLI for managing feature flags, projects and environments";
    homepage = "https://github.com/launchdarkly/ldcli";
    license = lib.licenses.asl20;
    mainProgram = "ldcli";
    platforms = lib.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
