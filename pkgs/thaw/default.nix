{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "thaw";
  version = "1.2.0";

  src = fetchurl {
    url = "https://github.com/stonerl/Thaw/releases/download/${version}/Thaw_${version}.zip";
    sha256 = "sha256-1n9NMe+foFeEmphUC4EM+kLgvGYBnTYFq9CORcaaoG8=";
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
