{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "thaw";
  version = "2.0.1";

  src = fetchurl {
    url = "https://github.com/thaw-app/Thaw/releases/download/${version}/Thaw_${version}.zip";
    sha256 = "sha256-qv78GGqWsuC3hosJZt9Mvjv2c3ztP5sloi1sB9xvj7o=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -r Thaw.app $out/Applications/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Menu bar manager for macOS";
    homepage = "https://github.com/thaw-app/Thaw";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [ ];
  };
}
