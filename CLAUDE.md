# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with GNU Stow for Linux (Ubuntu/Debian). It contains configuration files for Bash, Neovim, Tmux, Starship, WezTerm, and SSH, along with automated installation scripts.

## Installation and Setup

### Quick Setup (Stow Only)
```bash
./setup.sh
```
Symlinks dotfiles using stow. Backs up existing `.bashrc` and `.inputrc` before stowing.

### Full Installation (Tools + Dotfiles)
```bash
./install.sh
```
Installs all dependencies via Linuxbrew and apt, then stows dotfiles. Use `--no-stow` flag to install tools only.

**Key installations:**
- Prerequisites via apt: build-essential, curl, git, stow, bat, tree, xclip, tmux, unzip
- Linuxbrew packages: eza, fd, zoxide, starship, fzf, ranger, direnv, neovim, gobuster, ffuf, xh
- Additional: ngrok (official repo), TPM (Tmux Plugin Manager), Oh My Bash, GeistMono Nerd Font, Catppuccin GNOME Terminal theme
- Git config sets user to "Your Name" <you@example.com>

## Directory Structure

The repository uses stow package structure:
- `bashrc/` → stows to `$HOME`
- `ssh/` → stows to `$HOME`
- `nvim/`, `starship/`, `tmux/`, `wezterm/` → stow to `$HOME/.config`

**Stow targets:**
```bash
stow -t "$HOME" bashrc ssh
stow -t "$HOME/.config" nvim starship tmux wezterm
```

## Neovim Configuration

**Entry point:** `nvim/nvim/init.lua`

**Architecture:**
- Uses lazy.nvim for plugin management
- Modular Lua configuration split into:
  - `lua/options.lua` - Editor options
  - `lua/keymaps.lua` - Key mappings
  - `lua/plugins/*.lua` - Individual plugin configurations
  - `lua/misc.lua` - Miscellaneous settings

**Key plugins:**
- LSP: Mason, nvim-lspconfig, fidget (status)
- Completion: nvim-cmp with various sources
- Telescope: Fuzzy finder
- Treesitter: Syntax highlighting
- DAP: Debug Adapter Protocol
- Git: Gitsigns, Neogit
- UI: Lualine, Trouble, Zen mode
- AI: See `lua/plugins/ai.lua`
- Utilities: Harpoon, Mini.nvim, Obsidian, CodeSnap

**LSP Servers configured:**
- clangd, rust_analyzer, pyright, ts_ls, gopls, lua_ls, bash-language-server

**Important keybindings:**
- Leader key: `<Space>`
- `jj` in insert mode → Escape
- `<leader>rn` → LSP rename
- `<leader>ca` → Code action
- `gd` → Go to definition
- `K` → Hover documentation
- Buffer navigation: `th/tl` (prev/next), `td` (delete)
- Splits: `<C-W>,` and `<C-W>.` for resizing
- `WW` → Save, `QQ` → Force quit

## Tmux Configuration

**Config files:** `tmux/tmux/tmux.conf` (main), `tmux/tmux/tmux.reset.conf` (keybindings)

**Prefix:** `Ctrl+A` (set in tmux.conf)

**Key bindings:**
- `prefix + R` → Reload config
- `prefix + s` → Split horizontally
- `prefix + v` → Split vertically
- `prefix + h/j/k/l` → Navigate panes
- `prefix + ,/./−/=` → Resize panes
- `prefix + H/L` → Previous/next window
- `prefix + c` → Kill pane
- `prefix + K` → Clear screen
- `prefix + o` → Session picker (sessionx)
- `prefix + p` → Floating terminal (floax)

**Plugins managed by TPM:** Located in `~/.tmux/plugins/` (not in dotfiles repo)
- tpm, tmux-sensible, tmux-yank, tmux-resurrect, tmux-continuum
- tmux-thumbs, tmux-fzf, tmux-fzf-url, catppuccin-tmux, tmux-sessionx, tmux-floax

Install plugins: `prefix + I` inside tmux

## Bash Configuration

**File:** `bashrc/.bashrc`

**Shell framework:** Oh My Bash with Starship prompt

**Key aliases:**
- `v` → nvim
- `cat` → bat
- `cd` → z (zoxide)
- `l` → eza with icons/git
- Git: `gss` (status), `gc` (commit), `gp` (push), `glog` (pretty log)
- Docker: `dco` (compose), `dps` (ps), `dx` (exec)
- Security: `nm` (nmap), `gobust`, `fuzz` (ffuf), `server` (http.server), `tunnel` (ngrok)

**Functions:**
- `update` → Updates all package managers (apt, brew, Oh My Bash, TPM, Neovim plugins)
- `ranger` / `rr` → File manager with cd on exit
- `fcd` → Fuzzy find directory
- `fv` → Fuzzy find and open in nvim
- `ghcs` → GitHub Copilot suggest
- `ghce` → GitHub Copilot explain

**Environment:**
- Editor: nvim
- FZF default: `fd --type f --hidden --follow`
- Extensive PATH including Go, Cargo, Linuxbrew, pnpm, bun
- NVM configured at `$HOME/.config/nvm`

## Git Workflow

Default branch: `main`
Core editor: nvim
Pull strategy: merge (not rebase)

## Common Development Tasks

### Testing Configuration Changes

**Bash:**
```bash
source ~/.bashrc
```

**Tmux:**
```bash
prefix + R  # or tmux source ~/.config/tmux/tmux.conf
```

**Neovim:**
Restart nvim or `:source $MYVIMRC`

### Adding New Dotfiles

1. Create directory matching target structure
2. Add configuration files
3. Update stow command in setup.sh/install.sh if needed
4. Run `stow -t <target> <package>`

### Modifying Neovim Plugins

Plugin configs are in `nvim/nvim/lua/plugins/`. Each major plugin has its own file. Lazy.nvim auto-manages plugins defined in these files. After changes, restart nvim or run `:Lazy sync`.

## Important Notes

- **Font requirement:** GeistMono Nerd Font must be set in terminal for proper icon rendering
- **Tmux plugins:** Must run `prefix + I` after first install to load TPM plugins
- **Starship:** Requires Nerd Font for proper prompt rendering
- **Security tools:** Require `$SECURITY_TOOLS_DIR` environment variable for wordlists/scripts
- **Backup behavior:** Both scripts create timestamped backups in `~/.dotfiles_backup_*` before overwriting
