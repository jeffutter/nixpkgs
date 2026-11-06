{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.3.0";

  # Upstream publishes the native binary as per-platform npm packages. Fetch
  # those tarballs directly instead of going through npm: each unpacks to
  # package/{bin,lib}, and bin/zg finds its bundled libs through an
  # $ORIGIN/../lib RPATH. Hashes are SRI sha256; refresh with
  # bin/update-zvec-grep.
  npmUrl =
    target: "https://registry.npmjs.org/@zvec/zvec-grep-${target}/-/zvec-grep-${target}-${version}.tgz";
  sources = {
    "aarch64-darwin" = {
      url = npmUrl "darwin-arm64";
      hash = "sha256-0/h4PfnP4eNfdGhMs9nlUIoaEweYbuzu1jteYtHUT4A=";
    };
    "x86_64-linux" = {
      url = npmUrl "linux-x64-gnu";
      hash = "sha256-7P7n4EnUGrPyvLzbLKM+uVysLZLGujvrSFfaCqLCaqI=";
    };
    "aarch64-linux" = {
      url = npmUrl "linux-arm64-gnu";
      hash = "sha256-qtZco2Se5roBj3qgn6+MaefZDvjScP28ovJzRfSLdJQ=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "zvec-grep: unsupported system ${stdenv.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "zvec-grep";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # The bundled libs (ggml, llama, onnxruntime, zvec) sit next to the binary;
  # the only external dependencies are libstdc++ and libgcc_s.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # Only the CPU build is packaged. The optional CUDA components upstream
  # downloads in a postinstall step are not included.

  dontConfigure = true;
  dontBuild = true;
  # Prebuilt; stripping would invalidate the signed darwin binaries.
  dontStrip = true;

  # Keep bin/ and lib/ together so the $ORIGIN/../lib RPATH (and the darwin
  # equivalent) still resolves; the kernel resolves the symlink in $out/bin
  # to the real executable path before expanding $ORIGIN.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/zvec-grep $out/bin
    cp -r bin lib $out/lib/zvec-grep/
    # The darwin tarball ships no plugins.json.
    if [ -e plugins.json ]; then cp plugins.json $out/lib/zvec-grep/; fi
    ln -s $out/lib/zvec-grep/bin/zg $out/bin/zg
    runHook postInstall
  '';

  meta = {
    description = "Agent-friendly hybrid workspace search across code and non-code content";
    homepage = "https://github.com/zvec-ai/zvec-grep";
    license = lib.licenses.asl20;
    platforms = lib.attrNames sources;
    mainProgram = "zg";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
