{ stdenv, lib, fetchurl, makeWrapper, w3m-nox, curl, jq, gawk }:

let
  pname = "tmpmail";
  version = "1.1.7";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://git.io/tmpmail";
    sha256 = "17mvxbp3p1a6abc8nfdka56p8kj56bwqfaqiaadi017wvvp49gh4";
  };

  buildInputs = [ makeWrapper w3m-nox curl jq gawk ];

  unpackPhase = ''
    echo
  '';

  installPhase = ''
    chmod 755 $src
    makeWrapper $src $out/bin/tmpmail --prefix PATH : ${lib.makeBinPath [ w3m-nox curl jq gawk]}
  '';

  meta = with lib; {
    description = "tmpmail is a command line utility that allows you to create a temporary email address and receive emails to the temporary email address";
    homepage = "https://github.com/sdushantha/tmpmail";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
