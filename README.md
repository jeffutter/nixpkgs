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

The `~/bin/rebuild` script picks the right command and flake output for the
current machine:

```bash
~/bin/rebuild                  # autodetect
~/bin/rebuild personal         # force a specific config
~/bin/rebuild -- --show-trace  # pass flags through
```

On NixOS the config name is the short hostname. On macOS the hostname is
IT-assigned and meaningless, so the config is selected by username.

Or run the appropriate command manually:

**NixOS:**
```bash
sudo nixos-rebuild switch --flake ~/.config/home-manager#<config>
# e.g. zenbook or workstation
```

**macOS (nix-darwin):**
```bash
sudo darwin-rebuild switch --flake ~/.config/home-manager#<config>
# e.g. work or personal
```

## Updating

`~/bin/update` pulls, updates all flake inputs, and refreshes the pinned
binary packages under `pkgs/`:

```bash
~/bin/update              # fetch updates
~/bin/rebuild             # apply them
```

## Hosts

| Host | Platform | Description |
|------|----------|-------------|
| `zenbook` | x86_64-linux (NixOS) | Asus Zenbook laptop with Hyprland |
| `workstation` | x86_64-linux (NixOS) | Linux workstation |
| `work` | aarch64-darwin (nix-darwin) | macOS work machine |
| `personal` | aarch64-darwin (nix-darwin) | macOS personal machine |
