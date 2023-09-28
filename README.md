# Install

## Install Nix
```bash
mkdir .config
git clone git@github.com:jeffutter/nixpkgs.git .config/home-manager
ln -s .config/nixpkgs/systems/<name>/home.nix .config/home-manager/home.nix
sh <(curl -L https://nixos.org/nix/install)
```

## Restart Shell

## Install Home Manager
```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# May need:
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}

nix-shell '<home-manager>' -A install
```

## Install Homebrew & Homebrew Apps
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew bundle install
```
