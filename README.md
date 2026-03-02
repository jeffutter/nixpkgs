# jeffutter's Nix Configuration

Nix flake managing user environments across NixOS, macOS (nix-darwin), and standalone home-manager systems.

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
- On macOS: [nix-darwin](https://github.com/LnL7/nix-darwin) for system-level config

Enable flakes by adding to `/etc/nix/nix.conf` or `~/.config/nix/nix.conf`:
```
experimental-features = nix-flakes nix-command
```

## Setup

```bash
git clone git@github.com:jeffutter/nixpkgs.git ~/.config/home-manager
```

## Applying Configuration

The `~/bin/rebuild` script handles the right command for each platform automatically:

```bash
~/bin/rebuild
```

Or run the appropriate command manually:

**NixOS:**
```bash
sudo nixos-rebuild switch --flake ~/.config/home-manager#<hostname>
# e.g. zenbook or workstation
```

**macOS (nix-darwin):**
```bash
darwin-rebuild switch --flake ~/.config/home-manager#<hostname>
# e.g. work or personal
```

**Standalone home-manager:**
```bash
home-manager switch --flake ~/.config/home-manager#<user>@<hostname>
```

## Updating

```bash
nix flake update          # update all flake inputs
~/bin/rebuild             # apply updates
```

Or use `~/bin/upgrade` which runs both plus `topgrade` for a full system update.

## Hosts

| Host | Platform | Description |
|------|----------|-------------|
| `zenbook` | x86_64-linux (NixOS) | Asus Zenbook laptop with Hyprland |
| `workstation` | x86_64-linux (NixOS) | Linux workstation |
| `work` | aarch64-darwin (nix-darwin) | macOS work machine |
| `personal` | aarch64-darwin (nix-darwin) | macOS personal machine |
