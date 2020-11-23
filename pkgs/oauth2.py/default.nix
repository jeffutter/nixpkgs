{ stdenv, lib, pkgs }:

let
  pythonEnv = pkgs.python.withPackages (ps: [
  ]);
  pname = "oauth2.py";
  version = "1.0.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = pkgs.fetchFromGitHub {
			owner = "google"; 
			repo = "gmail-oauth2-tools";
			rev= "e3229155a4037267ce40f1a3a681f53221aa4d8d";
			sha256= "1cxpkiaajhq1gjsg47r2b5xgck0r63pvkyrkm7af8c8dw7fyn64f";
	};

  buildInputs = [ pythonEnv ];

  installPhase = ''
    install -D -m 0555 $src/python/oauth2.py $out/bin/oauth2.py
    echo -e "#!/bin/bash\n${pythonEnv}/bin/python $out/bin/oauth2.py \"\$@\"" > $out/bin/oauth2
    chmod 0555 $out/bin/oauth2
  '';

  meta = with lib; {
    description = "oauth2";
    homepage = "https://github.com/google/gmail-auth2-tools";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
