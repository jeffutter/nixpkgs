{ stdenv, lib, pkgs, fetchFromGitHub }:

let
  pname = "elixir-ls";
  version = "0.6.5";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "elixir-lsp";
    repo = "elixir-ls";
    rev = "v${version}";
    sha256 = "0ri70d2dm9cc2vswh4mppn14yx460721s0kqc9cgzx56ppy0rkfw";
  };

  buildInputs = with pkgs; with beamPackages; [ hex elixir erlang git cacert ];

  configurePhase = ''
    export HOME=$TMPDIR
    export HEX_HOME="$TMPDIR/hex"
    export MIX_HOME="$TMPDIR/mix"
    export MIX_DEPS_PATH="$out"
  '';

  buildPhase = ''
    mix local.rebar --force
    mix deps.get
    mix compile
    mix elixir_ls.release -o release/
  '';

  installPhase = ''
    mkdir $out/bin
    cp -Rp release/* $out/bin/
    chmod 755 $out/bin/language_server.sh
  '';

  meta = with lib; {
    description = "A frontend-independent IDE \"smartness\" server for Elixir. Implements the \"Language Server Protoco\" standard and provides debugger support via the \"Debug Adapter Protocol\"";
    homepage = "https://github.com/elixir-lsp/elixir-ls";
    license = licenses.asl20;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
