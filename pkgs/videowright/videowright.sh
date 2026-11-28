#!@shell@
# `videowright init` sets up the current folder as a video project. Every other
# command goes to the packaged CLI, after refreshing the project's module links
# (an `npm install` of a project dependency prunes them).
set -eu
PATH=@coreutils@/bin:$PATH

modules=@out@/lib/node_modules

link() {
  mkdir -p node_modules/.bin node_modules/@playwright
  for name in videowright vitest @playwright/test; do
    # A real directory is the user's own npm install: leave it.
    if [ -L "node_modules/$name" ] || [ ! -e "node_modules/$name" ]; then
      ln -sfn "$modules/$name" "node_modules/$name"
    else
      echo "videowright: node_modules/$name is not a Nix link; leaving it" >&2
    fi
  done
  for name in videowright vitest playwright tsc; do
    ln -sfn "@out@/libexec/$name" "node_modules/.bin/$name"
  done
}

if [ "${1-}" = init ]; then
  assets=$modules/videowright/skill/assets/install
  link
  for f in package.json tsconfig.json env.d.ts; do
    [ -e "$f" ] || cp --no-preserve=mode "$assets/$f" "$f"
  done
  if ! grep -q '"type": *"module"' package.json; then
    echo 'videowright: add "type": "module" to package.json' >&2
    exit 1
  fi
  echo "Videowright project ready in $PWD"
  exit 0
fi

if [ -e videowright.config.ts ]; then
  link
fi
exec @out@/libexec/videowright "$@"
