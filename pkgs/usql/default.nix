{ stdenv, lib, fetchurl, icu }:

let
  pname = "usql";
  version = "0.7.8";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/xo/usql/releases/download/v${version}/${pname}-${version}-darwin-amd64.tar.bz2";
    sha256 = "19impaa1yy7wqddsdd2b3byvla8ds1zzkjhaxkjrspffvxbq65a3";
  };

  buildInputs = [ icu ];

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin
  '';

  dontInstall = true;

  fixupPhase = ''
    echo ${icu}/lib/libicuuc.64.dylib
    install_name_tool -change /usr/local/opt/icu4c/lib/libicuuc.64.dylib ${icu}/lib/libicuuc.64.dylib $out/bin/usql
    otool -L $out/bin/usql
  '';

  meta = with lib; {
    description = "Universal command-line interface for SQL databases";
    homepage = "https://github.com/xo/usql";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
