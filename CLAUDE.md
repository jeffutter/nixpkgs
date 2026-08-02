# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix home-manager configuration repository that manages user environments across multiple systems (Linux workstations, macOS, and different machine profiles). The configuration uses Nix flakes with home-manager and nix-darwin to declaratively manage dotfiles, packages, and services.

## Common Commands

### Building and Switching
- `~/bin/rebuild` - Rebuild this machine (`nixos-rebuild` on NixOS,
  `darwin-rebuild` on macOS). Takes an optional config name; autodetects
  otherwise.
- `nixfmt **/*.nix` - Format all Nix files (nixfmt 1.x is the RFC-style
  formatter; there is no separate `nixfmt-rfc-style`)
- `nix-collect-garbage --delete-older-than 7d` - Clean Nix store

### Upgrading
- `~/bin/update` - Pulls, runs `nix flake update`, and refreshes the pinned
  binary packages under `pkgs/`. Follow with `~/bin/rebuild` to apply.

## Hosts

Each host has `default.nix` (system config) and `home.nix` (user config):

- `zenbook` — Asus Zenbook laptop, NixOS + Hyprland
- `workstation` — Linux workstation, NixOS
- `work` — macOS work machine, nix-darwin
- `personal` — macOS personal machine, nix-darwin
