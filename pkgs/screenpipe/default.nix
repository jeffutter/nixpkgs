{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  runCommand,
  makeBinaryWrapper,
  autoPatchelfHook,
  bun,
  ffmpeg,
  libgbm,
  wayland,
  xorg,
  openblas,
  openssl,
  dbus,
  xz,
  libpulseaudio,
  src,
}:

let
  version = "0.3.346";

  # The "screenpipe" npm package is a thin shim whose optionalDependencies pull
  # the prebuilt platform binary from @screenpipe/cli-<platform>. We skip the
  # JS shim and fetch the platform tarball directly. Hashes are the SRI
  # `dist.integrity` values from the npm registry.
  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@screenpipe/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
      hash = "sha512-qyqivXdDIhfrJKuGQVYIvZAW3DWq7K+sX9SM/7uT9UcSJvcC3zkGCJ0T8TMCXF57TbLlEhAPV21vwhu7Zrk05Q==";
    };
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/@screenpipe/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
      hash = "sha512-MAmMtrBHJtE+RUyLgTsM/6mSDOQqtZInIX/0fu3p4DB89+wq6HYNlm/EZzm0RzazKWUFIUEl6xe1zKOJksJGpQ==";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "screenpipe: unsupported system ${stdenv.hostPlatform.system}");

  skills = runCommand "screenpipe-skills-${version}" { } ''
    mkdir -p $out
    cp -r ${src}/.claude/skills/screenpipe-api $out/screenpipe-api
    cp -r ${src}/.claude/skills/screenpipe-cli $out/screenpipe-cli
  '';
in
stdenvNoCC.mkDerivation {
  pname = "screenpipe";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  sourceRoot = "package";

  nativeBuildInputs = [ makeBinaryWrapper ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    libgbm
    wayland
    xorg.libxcb
    openblas
    openssl
    dbus
    xz
    libpulseaudio
  ];

  dontConfigure = true;
  dontBuild = true;
  # Prebuilt; darwin binary is ad-hoc signed and stripping invalidates it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Lay out the unwrapped binary next to its assets in libexec, then create
    # a wrapper on PATH that injects ffmpeg. mlx.metallib must remain in the
    # same directory as the binary that loads it. screenpipe's
    # find_bun_executable() ignores PATH and only checks dirname(current_exe)
    # then a few hardcoded paths, so we also drop a bun symlink alongside.
    mkdir -p $out/libexec/screenpipe
    install -Dm755 bin/screenpipe $out/libexec/screenpipe/screenpipe
    ln -s ${bun}/bin/bun $out/libexec/screenpipe/bun
  ''
  + lib.optionalString stdenv.isDarwin ''
    install -Dm644 bin/mlx.metallib $out/libexec/screenpipe/mlx.metallib
  ''
  + ''
    makeWrapper $out/libexec/screenpipe/screenpipe $out/bin/screenpipe \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg bun ]} \
      --set-default SCREENPIPE_NO_REMINDERS 1

    runHook postInstall
  '';

  passthru = { inherit skills; };

  meta = {
    description = "screenpipe CLI — AI that knows everything you've seen, said, or heard";
    homepage = "https://github.com/screenpipe/screenpipe";
    license = lib.licenses.mit;
    platforms = lib.attrNames sources;
    mainProgram = "screenpipe";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
