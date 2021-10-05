{stdenv
  , lib
  , gnumake
  , gcc
  , SDL2
  , libserialport
  , fetchFromGitHub }:

let
  pname = "m8c";
  version = "1.0.3";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "laamaa";
    repo = pname;
    rev = "v${version}";
    hash = "sha256:0yrd6lnb2chgafhw1cz4awx2s1sws6mch5irvgyddgnsa8ishcr5";
  };

  installFlags = [ "PREFIX=$(out)" ];
  nativeBuildInputs = [ gnumake gcc ];
  buildInputs = [ SDL2 libserialport ];

  meta = with lib; {
    description = "Cross-platform M8 tracker headless client";
    homepage = "https://github.com/laamaa/m8c";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
