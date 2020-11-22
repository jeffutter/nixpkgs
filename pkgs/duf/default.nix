{ stdenv, lib, fetchurl }:

let
  pname = "duf";
  version = "0.3.1";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_Darwin_x86_64.tar.gz";
    sha256 = "07a39805caiprn2xdajk3qsdyhxwnsmkraaf1z3fhq34alp0sp5v";
  };

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin duf
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Disk Usage/Free Utility (Linux, BSD & macOS)";
    homepage = "https://github.com/muesli/duf";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
