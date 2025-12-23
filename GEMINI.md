# Project Context: Dotfiles

## Overview
This repository manages the user configuration files (dotfiles) for a Linux environment, specifically tailored for Ubuntu. It uses **GNU Stow** for symlink management, keeping the home directory clean and the configuration version-controlled.

## Key Technologies & Tools
*   **Management:** [GNU Stow](https://www.gnu.org/software/stow/)
*   **Shell:** Bash (with Oh My Bash) & [Starship](https://starship.rs/) prompt
*   **Editor:** [Neovim](https://neovim.io/) (configured with Lua and `lazy.nvim`)
*   **Terminal:** [WezTerm](https://wezfurlong.org/wezterm/) & GNOME Terminal
*   **Multiplexer:** [Tmux](https://github.com/tmux/tmux) (with TPM - Tmux Plugin Manager)
*   **Utilities:** `fzf`, `eza`, `zoxide`, `bat`, `ranger`, `direnv`, `ripgrep`
    *   *Note:* On Ubuntu, `bat` is installed as `batcat`. The `install.sh` script automatically creates a symlink `/usr/local/bin/bat -> /usr/bin/batcat` to ensure the `cat` alias works.

## Directory Structure & Stow Strategy
The repository is organized into "packages" (directories) that Stow symlinks to target locations.

*   **Target: `$HOME`**
    *   `bashrc/` -> Symlinks `.bashrc` and `.inputrc`
    *   `ssh/` -> Symlinks `.ssh/config`

*   **Target: `$HOME/.config`**
    *   `nvim/` -> Symlinks `nvim/` directory
    *   `starship/` -> Symlinks `starship.toml`
    *   `tmux/` -> Symlinks `tmux/` directory
    *   `wezterm/` -> Symlinks `wezterm/` directory

## Installation & Usage

### Full Bootstrap (Fresh Install)
To install all dependencies (apt, brew, fonts, tools) and apply configurations:
```bash
./install.sh
```
*   **Installs:** Linuxbrew, Neovim, Tmux, Starship, Nerd Fonts (GeistMono), GNOME Terminal themes (Catppuccin), etc.
*   **Configures:** Git globals, FZF bindings.
*   **Applies:** Dotfiles via Stow.

### Quick Setup (Symlinks Only)
To only refresh or apply the symlinks without installing packages:
```bash
./setup.sh
```
*   Backs up existing conflicting files to `~/.dotfiles_backup_<timestamp>`.
*   Runs `stow` commands for the specific targets.

### Manual Stow Usage
To manually stow a package (e.g., `nvim`):
```bash
# For packages targeting ~/.config
stow -t ~/.config nvim

# For packages targeting ~
stow -t ~ bashrc
```

## Development Conventions
*   **Neovim:** Configuration is modularized in `nvim/nvim/lua/`. Plugins are managed via `lazy.nvim` in `nvim/nvim/lua/plugins/`.
*   **Tmux:** Plugins are managed via TPM. Press `prefix + I` to install plugins after changes.
*   **Scripts:** Bash scripts should follow standard practices (error handling with `set -e`, info/error logging functions).
