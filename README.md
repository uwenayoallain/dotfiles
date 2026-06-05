# Dotfiles

GNU Stow based dotfiles for a Debian/Ubuntu workstation.

## Install

Full bootstrap for a new PC:

```bash
./install.sh
```

Tools only, without stowing dotfiles:

```bash
./install.sh --no-stow
```

Symlinks only, with backups for conflicting files:

```bash
./setup.sh
```

The full installer covers the shell environment, Homebrew CLI tools, Docker,
NVM/Node, npm/pnpm/bun global CLIs, DuckDB, ngrok, tmux plugins, Oh My Bash,
fonts, Git defaults, VS Code, and VS Code extensions from
`vscode/extensions.txt`.
