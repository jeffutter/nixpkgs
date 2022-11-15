{ stdenv, lib, fetchFromGitHub, rustPlatform }:

let
  pname = "wakeonlan";
  version = "0.1.0"; 
in

rustPlatform.buildRustPackage rec {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "jeffutter";
    repo = "wakeonlan-rust";
    rev = "v0.1.0";
    sha256 = "sha256-Ne4ZABsVNunAKoDoLflla5Tp0mMUmP1XHf1ijWRzjGs=";
  };
    
  cargoSha256 = "sha256-h51kf+4zfwUYOtbpCCMYIfp/AzHgdOCy5HPimiB3hlA=";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
