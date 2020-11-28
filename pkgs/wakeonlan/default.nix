{ stdenv, lib, fetchFromGitHub, nim }:

let
  pname = "wakeonlan";
in

stdenv.mkDerivation {
  name = pname;

  src = fetchFromGitHub {
    owner = "jeffutter";
    repo = "wakeonlan";
    rev = "0549b96546d48e3d2cbc9b392349feb98e4deb82";
    sha256 = "0scnq0qb9s9xbx24sbah2k9zzwc3j1b6nwrbl30q4v0xbaiqj07a";
  };

  buildInputs = [ nim ];

  buildPhase = ''
    nim --nimcache=$TMPDIR c -d:release wakeonlan.nim
  '';

  installPhase = ''
    install -D -m 0555 wakeonlan $out/bin/wakeonlan
  '';

  meta = with lib; {
    description = "Simple wake-on-lan program written in Nim";
    homepage = "https://github.com/jeffutter/wakeonlan";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
