{ stdenv, lib, fetchurl }:

let
  pname = "my_topgrade";
  version = "6.8.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/r-darwish/topgrade/releases/download/v${version}/topgrade-v${version}-x86_64-apple-darwin.tar.gz";
    sha256 = "14g776s6y2c7a222gidcww9s2kv4aipaxfajmz51khmwr21ybzxs";
  };

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin topgrade
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Upgrade everything";
    homepage = "https://github.com/r-darwish/topgrade";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
