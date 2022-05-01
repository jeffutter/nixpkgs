{ stdenv, lib, fetchFromGitHub, rustPlatform }:

let
  pname = "wakeonlan";
  version = "0.0.1"; 
in

rustPlatform.buildRustPackage rec {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "jeffutter";
    repo = "wakeonlan-rust";
    rev = "3856ceed4bd545505dc0b42315f58080743a93b8";
    sha256 = "sha256-+MneuHxLWOgf0MnRh5YH3aeV3UJ+GI+02BnczZdmYbU=";
  };
    
  cargoSha256 = "sha256-V0JgzQb1kpRkU9x8tJ8njgscEgf7gJDlxP7D3PvUQ+Q=";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
