{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "thaw";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/thaw-app/Thaw/releases/download/${version}/Thaw_${version}.zip";
    sha256 = "sha256-I/6FDda24/girwCi2nbG1GE1wvqKDe746PoJ0e/T7sE=";
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
