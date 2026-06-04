{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  onnxruntime,
  openssl,
  curl,
  zlib,
}:

let
  version = "1.5.0";

  # Prebuilt release tarballs from the next-plaid GitHub releases (same artifacts
  # the upstream Homebrew tap installs). Each archive contains a single `colgrep`
  # binary. Hashes are SRI sha256 of the .tar.xz; refresh with bin/update-colgrep.
  baseUrl = "https://github.com/lightonai/next-plaid/releases/download/v${version}";
  sources = {
    "aarch64-darwin" = {
      url = "${baseUrl}/colgrep-aarch64-apple-darwin.tar.xz";
      hash = "sha256-aB2BWL+V3OFjr1MAv9GL+oWoO1ugPDDXpOoVG8pnrFM=";
    };
    "x86_64-linux" = {
      url = "${baseUrl}/colgrep-x86_64-unknown-linux-gnu.tar.xz";
      hash = "sha256-16PUipidvOU3Gmfk9bvQhvuvH4SnZqNqAZleTZROlIE=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "colgrep: unsupported system ${stdenv.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "colgrep";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  # The tarball wraps the binary in a single colgrep-<triple>/ directory; let
  # the default unpacker auto-detect it as the source root.

  nativeBuildInputs =[ makeBinaryWrapper ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  # autoPatchelfHook rewrites the interpreter/RPATH of the prebuilt ELF so it
  # resolves against the Nix store instead of FHS paths. Only needed on Linux;
  # the darwin Mach-O binary links system libs at fixed paths and runs as-is.
  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    onnxruntime
    openssl
    curl
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  # Prebuilt; the darwin binary is ad-hoc signed and stripping invalidates it.
  dontStrip = true;

  installPhase =
    ''
      runHook preInstall
    ''
    # On darwin the binary downloads a compatible ONNX Runtime to ~/.cache on
    # first use (exactly as the Homebrew install does), so no wrapping is needed.
    + lib.optionalString stdenv.isDarwin ''
      install -Dm755 colgrep $out/bin/colgrep
    ''
    # On Linux the runtime ONNX auto-download is a generic build that won't link
    # on NixOS, so point ORT at the (properly linked) nixpkgs onnxruntime and
    # skip the download. ORT_DYLIB_PATH takes precedence over every other lookup.
    + lib.optionalString stdenv.isLinux ''
      install -Dm755 colgrep $out/libexec/colgrep/colgrep
      makeWrapper $out/libexec/colgrep/colgrep $out/bin/colgrep \
        --set-default ORT_DYLIB_PATH ${onnxruntime}/lib/libonnxruntime.so \
        --set-default ORT_LIB_LOCATION ${onnxruntime}/lib \
        --set-default ORT_PREFER_DYNAMIC_LINK 1 \
        --set-default ORT_SKIP_DOWNLOAD 1
    ''
    + ''
      runHook postInstall
    '';

  meta = {
    description = "Semantic code search powered by ColBERT";
    homepage = "https://github.com/lightonai/next-plaid/tree/main/colgrep";
    license = lib.licenses.asl20;
    platforms = lib.attrNames sources;
    mainProgram = "colgrep";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
