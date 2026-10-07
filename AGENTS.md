# Repository Guidelines

Personal Ubuntu/Debian workstation configuration. GNU Stow manages the
symlinks; manifests under `packages/` describe everything to install.

`CLAUDE.md` and `GEMINI.md` are symlinks to this file — edit `AGENTS.md` only.

## Project structure

```
install.sh             Orchestrator: parses flags, runs lib/ modules in order
setup.sh               Stow only (no installing), with backups
bin/snapshot.sh        Reads the live system, reports drift from the manifests

lib/                   One module per concern, sourced by install.sh
  common.sh            Colors, print_*, run/shielded, manifest readers
  apt.sh               Third-party repos + apt packages
  brew.sh              Linuxbrew + formulae + fzf key bindings
  snap.sh              Snap and Flatpak
  node.sh              NVM, Node LTS, npm/pnpm/bun globals
  sdk.sh               Vite+ toolchain
  apps.sh              DuckDB, AI CLIs, miniserve, AppImageLauncher
  shell.sh             Oh My Bash, TPM, fonts, GNOME Terminal theme
  desktop.sh           dconf dump/load, VS Code extensions
  skills.sh            Agent skill fan-out, Claude Code plugins
  stow.sh              Package->target map, conflict backup, user services
  tuning.sh            Resource limits sized from this host's RAM/cores
  pick.sh              --pick checklists (gum via cli-kit, whiptail fallback)
  private.sh           Clone and run the private overlay's install.sh

packages/<tier>/       Manifests: apt, brew, snap, flatpak, npm, pnpm, bun,
                       vscode, skills.map, claude-plugins.txt, manual.md
dconf/                 GNOME settings dumps, one file per dconf path
```

Every other top-level directory is a stow package mirroring its target path —
see the table in `README.md`.

## Commands

```bash
./install.sh [--tier core,dev,desktop,optional] [--only <modules>]
             [--dry-run] [--list] [--no-stow]
./setup.sh [--dry-run] [--unstow]
./bin/snapshot.sh [--write]
```

Reload after edits: `source ~/.bashrc`, `prefix + R` for tmux, restart Neovim
or `:Lazy sync` for plugin changes.

## Coding style

- **Bash:** `#!/usr/bin/env bash`, `set -eo pipefail`, 4-space indent,
  `lower_snake_case` functions. Modules are sourced, not executed — they
  define functions and must not run anything at source time.
- **Lua:** 2-space indent; one plugin per file in `nvim/nvim/lua/plugins/`.
- Keep tool-standard filenames (`.bashrc`, `starship.toml`, `tmux.conf`).

## Rules that are easy to get wrong

1. **`set -e` and function return values.** A function whose last statement is
   a test returns that test's status, and calling it as a plain command aborts
   the script. End such functions with an explicit `return 0` — see
   `tier_manifests` in `lib/common.sh`.
2. **Installers that append to `~/.bashrc`.** Once stowed, `~/.bashrc` is a
   symlink into this repo, so nvm/bun/Oh My Bash/Vite+ would edit a tracked
   file. Wrap those calls in `shielded` (`lib/common.sh`), never plain `run`.
3. **`run` vs direct calls.** Anything that mutates the system goes through
   `run` so `--dry-run` stays honest. Read-only probes call directly.
4. **Never abort the whole install for one package.** Loop and
   `|| print_warning "... continuing"`.
5. **Tiers are curated by hand.** `snapshot.sh --write` never rewrites a tier
   file; new packages land in `packages/unsorted/` for manual filing.

## Adding things

- **A package:** add the line to `packages/<tier>/<manager>.txt`.
- **A config file:** put it in the right stow package, then add a
  `repo:live` entry to `CONFIG_PAIRS` in `bin/snapshot.sh` so drift is caught.
- **A skill:** drop it in `skills/.agents/skills/<name>/`, list it in
  `packages/dev/skills.map`, run `./install.sh --only skills`.
- **A new install step:** add a function to the right `lib/` module, then wire
  it into `MODULES` and `main()` in `install.sh`.

## Testing

No automated tests or CI. Before committing:

```bash
bash -n install.sh setup.sh bin/snapshot.sh lib/*.sh
./install.sh --dry-run
./setup.sh --dry-run
./bin/snapshot.sh
```

## Commits

Short and direct; history uses plain verbs ("updates") and conventional
prefixes (`feat:`, `fix:`). No co-authors.

## Generic only

This repo is public. Nothing personal goes here: no project names or paths,
no personal data directories, no work aliases, no identity. Those belong in
the private overlay (`lib/private.sh`), reached through the hooks this repo
provides (`~/.bashrc.d/*.sh`, `~/.gitconfig.local`). Resource limits are always
fractions of the host (`lib/tuning.sh`), never fixed sizes.

## Security

Never commit secrets, tokens, or private keys. `ssh/` holds config only.
This repo tracks agent and editor configuration, and those tools write
credentials into the same directories as their settings — check `git diff`
before committing anything under `agents/`, `vscode/`, or `opencode/`.
`.gitignore` blocks the known credential filenames, but it is a safety net,
not a guarantee.
