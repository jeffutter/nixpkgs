{ stdenv, lib, fetchFromGitHub, gcc, openssl, zlib }:

let
  pname = "wrk2";
in

stdenv.mkDerivation {
  name = pname;

  src = fetchFromGitHub {
    owner = "giltene";
    repo = "wrk2";
    rev = "44a94c17d8e6a0bac8559b53da76848e430cb7a7";
    sha256 = "0d24bjs3nnafl3svrbgc2if447c1irckxfprzsbbipn31i352x8y";
  };

  preConfigure = "LD=$CC";

  buildInputs = [ gcc openssl zlib ];

  patches = [
    ./sw_vers.patch
  ];

  makeFlags = [ "WITH_OPENSSL=${openssl.dev}" ];

  buildPhase = ''
    export MACOSX_DEPLOYMENT_TAREGT=''${MACOSX_DEPLOYMENT_TARGET:-10.12}
    make
  '';

  NIX_CFLAGS_COMPILE = "-DluaL_reg=luaL_Reg";

  installPhase = ''
    install -D -m 0555 wrk $out/bin/wrk2
  '';

  meta = with lib; {
    description = "A constant throughput, correct latency recording variant of wrk";
    homepage = "https://github.com/giltene/wrk2";
    license = licenses.asl20;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
