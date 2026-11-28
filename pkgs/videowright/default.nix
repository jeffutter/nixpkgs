# Videowright and the tools its skill uses, pinned. Upstream installs these with
# npm into every video project and symlinks the skill from there. Here the skill
# is global, and `videowright` links the packaged modules into a project (see
# videowright.sh), so nothing is fetched at run time.
{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
  playwright-test,
  playwright-driver,
  typescript,
  ffmpeg,
  coreutils,
  which,
  runtimeShell,
  tts-speech-skill,
  stt-transcribe-skill,
  yue2-song-skill,
}:

buildNpmPackage {
  pname = "videowright";
  version = (lib.importJSON ./package.json).version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDepsHash = "sha256-ZqvFfS/SHIud+2mvCdo+wGxoYt3bpXrH20xg+eq7MHY=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/libexec
    cp -r node_modules $out/lib/node_modules
    modules=$out/lib/node_modules
    pkg=$modules/videowright

    # Playwright comes from nixpkgs so that it matches the Chromium build.
    mkdir -p $modules/@playwright
    for name in playwright playwright-core @playwright/test; do
      rm -rf "$modules/$name"
      ln -s "${playwright-test}/lib/node_modules/$name" "$modules/$name"
    done

    # Vite's default cache directory is inside this package, which is read-only.
    for f in $pkg/dist/cli/dev.js $pkg/dist/cli/render.js; do
      substituteInPlace "$f" --replace-fail 'configFile: false,' \
        'configFile: false, cacheDir: `''${process.cwd()}/node_modules/.vite`,'
    done

    # Sourced in a subshell: it needs substituteInPlace, and changes directory.
    (
      voicePatch=${./skill-local-audio.patch}
      voiceTake=${./voice/local-take.mjs}
      tts=${tts-speech-skill}/scripts/tts
      stt=${stt-transcribe-skill}/scripts/stt
      yue2=${yue2-song-skill}/scripts/yue2
      source ${./patch-skill.sh} $pkg/skill
    )
    substituteInPlace $pkg/dist/types.d.ts --replace-fail \
      'provider: "gemini" |' 'provider: "local" | "gemini" |'

    tool() {
      makeWrapper ${nodejs}/bin/node "$out/libexec/$1" \
        --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
        --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS 1 \
        --prefix PATH : ${
          lib.makeBinPath [
            ffmpeg
            which
          ]
        } \
        --add-flags "$2"
    }
    tool videowright $pkg/dist/cli/bin.js
    tool vitest $modules/vitest/vitest.mjs
    tool playwright ${playwright-test}/lib/node_modules/@playwright/test/cli.js
    ln -s ${typescript}/bin/tsc $out/libexec/tsc

    substitute ${./videowright.sh} $out/bin/videowright \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by coreutils ${coreutils} \
      --subst-var out
    chmod +x $out/bin/videowright

    runHook postInstall
  '';

  meta = {
    description = "Animated explainer videos in HTML, CSS and JS";
    homepage = "https://github.com/scosman/videowright";
    license = lib.licenses.mit;
    mainProgram = "videowright";
    inherit (nodejs.meta) platforms;
  };
}
