{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "thaw";
  version = "1.0.0-beta.4";

  src = fetchurl {
    url = "https://github.com/stonerl/Thaw/releases/download/${version}/Thaw_${version}.zip";
    sha256 = "sha256-v5XlyIrNdp3pnDqhIBbdAbZkF265fNLStS+t+EshL68=";
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
    homepage = "https://github.com/stonerl/Thaw";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [ ];
  };
}
