# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix home-manager configuration repository that manages user environments across multiple systems (Linux workstations, macOS, and different machine profiles). The configuration uses home-manager to declaratively manage dotfiles, packages, and services.

## Common Commands

### Installation and Setup
- `nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && nix-channel --update` - Add home-manager channel
- `nix-shell '<home-manager>' -A install` - Install home-manager
- `ln -s ~/.config/home-manager/systems/<name>/home.nix ~/.config/home-manager/home.nix` - Link system-specific config

### Building and Switching
- `home-manager switch` - Apply configuration changes
- `home-manager build` - Build configuration without switching
- `nixfmt-rfc-style **/*.nix` - Format all Nix files
- `home-manager expire-generations '-1 week'` - Clean old generations
- `nix-collect-garbage --delete-older-than 7d` - Clean Nix store

### macOS Homebrew Integration
- `brew bundle install` - Install Homebrew applications (using Brewfile.common)

### Upgrading
- `~/bin/upgrade` (which runs `topgrade`) - Update all packages and systems
- `topgrade` - Cross-platform system updater that handles Nix, Homebrew, etc.

## Architecture

### File Structure
- **`home.nix`** - Main entry point (symlinked to system-specific config)
- **`systems/`** - System-specific configurations
  - `common.nix` - Shared configuration for all systems
  - `darwin.nix` - macOS-specific settings (AeroSpace, dock settings)
  - `zenbook/home.nix` - Linux laptop configuration (Wayland/Hyprland)
  - `workstation/home.nix`, `personal/home.nix`, `work/home.nix` - Other machine profiles
- **`pkgs/`** - Custom package definitions (ltex-lsp, m8c)
- **`nvim/`** - Neovim configuration (Lua-based)
- **`bin/`** - Custom scripts (upgrade, sunset, wrappers)
- **`vivid/themes/`** - Color schemes for terminal

### System Types
1. **Linux Systems**: Use Wayland (Hyprland/Sway), waybar, hyprlock, terminal-focused
2. **macOS Systems**: Use AeroSpace window manager, Homebrew for GUI apps
3. **Common Elements**: Fish/Zsh shells, Git, development tools, Neovim, terminal apps

### Key Technologies
- **Window Managers**: Hyprland (primary), Sway (fallback) on Linux; AeroSpace on macOS
- **Shells**: Fish (primary), Zsh (with oh-my-zsh)
- **Terminal**: Ghostty (primary), Kitty (secondary)
- **Editor**: Neovim with custom Lua configuration
- **Theme**: Tokyo Night Moon (consistent across all applications)
- **Package Management**: Nix packages + Homebrew on macOS

### Development Environment
- **Languages**: Rust, Go, Elixir, Python, JavaScript/Node
- **Tools**: Docker, kubectl, various CLI tools (ripgrep, fd, eza, etc.)
- **Version Control**: Git with difftastic, jujutsu
- **Fonts**: Monaspace Nerd Font family

### Configuration Patterns
- System-specific configs import `common.nix` and override/extend as needed
- Extensive use of Nix flakes for external packages
- Custom package wrappers for Wayland compatibility
- Consistent theming using Tokyo Night across all applications
- MacOS uses Colemak keyboard layout, Linux uses standard QWERTY