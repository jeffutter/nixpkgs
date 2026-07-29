# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix home-manager configuration repository that manages user environments across multiple systems (Linux workstations, macOS, and different machine profiles). The configuration uses Nix flakes with home-manager and nix-darwin to declaratively manage dotfiles, packages, and services.

## Common Commands

### Building and Switching
- `~/bin/rebuild` - Rebuild NixOS or home-manager depending on system type
- `nix flake update` - Update flake inputs
- `nixfmt-rfc-style **/*.nix` - Format all Nix files
- `nix-collect-garbage --delete-older-than 7d` - Clean Nix store

### Upgrading
- `~/bin/upgrade` - Runs `nix flake update` 

## Hosts

Each host has `default.nix` (system config) and `home.nix` (user config):

- `zenbook` — Asus Zenbook laptop, NixOS + Hyprland
- `workstation` — Linux workstation, NixOS
- `work` — macOS work machine, nix-darwin
- `personal` — macOS personal machine, nix-darwin
