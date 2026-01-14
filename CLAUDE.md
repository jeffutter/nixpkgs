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
- `~/bin/upgrade` - Runs `nix flake update` then `topgrade` for system-wide updates
- `topgrade` - Cross-platform system updater that handles Nix, Homebrew, etc.

## Architecture

### File Structure
- **`flake.nix`** - Main entry point defining all inputs and outputs
- **`hosts/`** - System-specific configurations
  - `zenbook/` - Asus Zenbook Linux laptop (NixOS + Hyprland)
  - `workstation/` - Linux workstation (NixOS)
  - `work/` - macOS work machine (nix-darwin)
  - `personal/` - macOS personal machine (nix-darwin)
- **`modules/`** - Modular reusable configurations
  - `darwin/common.nix` - Shared macOS configuration (Homebrew, keyboard, system preferences)
  - `home/common.nix` - Main home-manager module that imports all submodules
  - `home/packages.nix` - Common packages (100+ CLI tools)
  - `home/themes.nix` - Tokyo Night Storm theme via Stylix
  - `home/darwin.nix` - macOS-specific home settings (AeroSpace)
  - `home/linux.nix` - Linux-specific home settings
  - `home/shells/` - Fish shell configuration
  - `home/terminals/` - Ghostty and tmux configuration
  - `home/editors/` - Neovim via NixVim with LSP
  - `home/languages/` - Language-specific tooling (rust, go, elixir, python, javascript, java, ai)
  - `home/vcs/` - Git and jujutsu configuration
  - `home/tools/` - CLI utilities (starship, ssh, direnv, zoxide)
- **`pkgs/`** - Custom package definitions (ltex-lsp, m8c)
- **`bin/`** - Custom scripts (upgrade, rebuild, sunset)

### Host Configurations
Each host has a `default.nix` (system config) and `home.nix` (user config):

1. **zenbook** (x86_64-linux) - NixOS with Hyprland/Sway, Intel GPU
2. **workstation** (x86_64-linux) - NixOS workstation
3. **work** (aarch64-darwin) - macOS with AeroSpace, work-specific tools
4. **personal** (aarch64-darwin) - macOS with AeroSpace, personal setup

### Flake Outputs
- `nixosConfigurations` - zenbook, workstation
- `darwinConfigurations` - work, personal
- `homeConfigurations` - Standalone home-manager configs

### Key Technologies
- **Window Managers**: Hyprland (primary), Sway (fallback) on Linux; AeroSpace on macOS
- **Shell**: Fish with abbreviations, aliases, and plugins
- **Terminal**: Ghostty
- **Editor**: Neovim via NixVim with LSP, Treesitter, and plugins
- **Theme**: Tokyo Night Storm (system-wide via Stylix)
- **Package Management**: Nix flakes + Homebrew on macOS

### Development Environment
- **Languages**: Rust, Go, Elixir, Python, JavaScript/Node, Java (selectively imported per host)
- **Tools**: Docker, kubectl, various CLI tools (ripgrep, fd, eza, etc.)
- **Version Control**: Git with difftastic, jujutsu
- **Fonts**: Monaspace Nerd Font family

### Configuration Patterns
- Hosts selectively import language modules from `modules/home/languages/`
- Platform-specific handling via separate `darwin.nix` and `linux.nix` modules
- Stylix handles consistent theming across all applications
- Custom Wayland wrappers for applications (zoom, obsidian, etc.) on Linux
- macOS uses Colemak keyboard layout
- Work machine uses per-directory git credentials
