{
  lib,
  stdenv,
  fetchYarnDeps,
  fixup-yarn-lock,
  yarn,
  nodejs,
  happy-src,
}:

stdenv.mkDerivation {
  pname = "happy-coder";
  version = "0.14.0-0";

  # Build from the monorepo root
  src = happy-src;

  nativeBuildInputs = [
    fixup-yarn-lock
    yarn
    nodejs
  ];

  # Fetch yarn dependencies from the monorepo's yarn.lock
  offlineCache = fetchYarnDeps {
    yarnLock = "${happy-src}/yarn.lock";
    hash = "sha256-3tU274YBXpeoHxadXyFKvxUvPeydLRXMkD3dbZHr2yI=";
  };

  patchPhase = ''
    runHook prePatch

    # Fix --version to exit properly instead of continuing to Claude Code
    # Replace the comment line with an actual process.exit(0)
    sed -i 's|// Don'"'"'t exit - continue to pass --version to Claude Code|process.exit(0)|g' packages/happy-cli/src/index.ts

    runHook postPatch
  '';

  configurePhase = ''
    runHook preConfigure

    export HOME=$TMPDIR

    # Patch package.json to only include happy-cli workspace to save disk space
    node -e "
      const fs = require('fs');
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      pkg.workspaces = ['packages/happy-cli'];
      pkg.private = true;
      fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "

    fixup-yarn-lock yarn.lock
    yarn config --offline set yarn-offline-mirror $offlineCache
    yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
    patchShebangs node_modules

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # Build the happy-cli workspace package (package name is "happy-coder")
    yarn --offline workspace happy-coder run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/happy-cli

    # Copy the built output and bin directory
    cp -r packages/happy-cli/dist $out/lib/happy-cli/
    cp -r packages/happy-cli/bin $out/lib/happy-cli/

    # Copy only production dependencies (filter out workspace symlinks)
    mkdir -p $out/lib/happy-cli/node_modules
    for dep in node_modules/*; do
      if [ -L "$dep" ]; then
        # Skip symlinks (workspace packages)
        continue
      fi
      cp -r "$dep" $out/lib/happy-cli/node_modules/
    done

    # Create symlink to the bin entry point
    mkdir -p $out/bin
    ln -s $out/lib/happy-cli/bin/happy.mjs $out/bin/happy

    runHook postInstall
  '';

  # Metadata
  meta = with lib; {
    description = "Code on the go — control AI coding agents from your mobile device";
    homepage = "https://github.com/slopus/happy";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
