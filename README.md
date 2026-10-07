# Dotfiles

Reproducible Ubuntu/Debian workstation: shell, editors, CLI tools, desktop
apps, agent skills, and GNOME settings, all driven from manifests.

## Bootstrap a new PC

```bash
sudo apt update && sudo apt install -y git stow
git clone --recurse-submodules <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

That single command installs every tier except `optional`, symlinks the
configs, tunes the machine to its own hardware, and applies the personal
overlay if one is reachable. It is idempotent — re-run it any time.

Prefer to choose? `./install.sh --pick` walks through checklists for tiers,
install steps, individual apps, and (with the overlay) projects and services.


If you cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Usage

```bash
./install.sh                    # core + dev + desktop (the default)
./install.sh --tier core        # headless box: shell and CLI tools only
./install.sh --tier optional    # NVIDIA driver, ZFS, filesystem tools
./install.sh --only apt,stow    # re-run just those modules
./install.sh --dry-run          # print every action, change nothing
./install.sh --list             # show tiers, package counts, and modules
./install.sh --no-stow          # install tools without touching symlinks
./install.sh --pick             # choose tiers, steps, and apps interactively
./install.sh --only tuning      # re-size every resource cap for this machine

./setup.sh                      # symlinks only, with backups
./setup.sh --unstow             # remove the symlinks

./bin/snapshot.sh               # report drift between this PC and the repo
./bin/snapshot.sh --write       # pull live config and new packages back in
```

## Tiers

| Tier | What it covers | Modules it enables |
| --- | --- | --- |
| `core` | Shell, build tools, and the CLI utilities `.bashrc` depends on. Safe on a server. | `apt` `brew` `shell` `stow` |
| `dev` | Docker, Node (Vite+), Java, AI CLIs, VS Code, agent skills. | `node` `apps` `vscode` `skills` |
| `desktop` | Browsers, GUI apps, snaps, flatpaks, fonts, GNOME theme and settings. | `snap` `flatpak` `gnome` |
| `optional` | Host-specific: NVIDIA driver, ZFS, NTFS/exFAT support. Never runs by default. | — |

A tier scopes both the manifests *and* the modules, so `--tier core` on a
headless box installs no SDKs, GUI apps, fonts, or desktop theme. `--only`
overrides this and runs exactly the modules you name.

## Layout

```
packages/<tier>/       # what to install — one file per package manager
  apt.txt  brew.txt  snap.txt  flatpak.txt
  npm.txt  pnpm.txt  bun.txt  vscode.txt
  skills.map           # which agent sees which skill
  claude-plugins.txt   # Claude Code marketplaces and plugins
  manual.md            # apps that must be downloaded by hand

lib/                   # install.sh modules, one per concern
  common.sh apt.sh brew.sh snap.sh node.sh
  apps.sh shell.sh desktop.sh skills.sh stow.sh tuning.sh pick.sh private.sh

bin/snapshot.sh        # re-read the live system, report what drifted
dconf/                 # GNOME settings dumps, one file per dconf path
```

Everything else is a stow package whose directory mirrors its target path:

| Package | Target | Contents |
| --- | --- | --- |
| `bashrc` | `$HOME` | `.bashrc`, `.bash_profile`, `.profile`, `.inputrc`, `.tmux.conf` |
| `gitconfig` | `$HOME` | `.gitconfig` |
| `ssh` | `$HOME` | `.ssh/config` |
| `localbin` | `$HOME` | `.local/bin`: `pc-watch`, `pc-status`, `pc-freeze-guard`, `pc-background-gate`, `fix-pc-sleep`; `.local/lib/pc` shared gauges |
| `agents` | `$HOME` | Claude and Gemini config files |
| `skills` | `$HOME` | `.agents/skills` — the shared skill store |
| `nvim` `tmux` `starship` `wezterm` | `$HOME/.config` | editor, multiplexer, prompt, terminal |
| `vscode` | `$HOME/.config` | `Code/User` settings, keybindings, snippets, MCP |
| `opencode` | `$HOME/.config` | `opencode.jsonc` |
| `systemd` | `$HOME/.config` | `background.slice`, the freeze-guard timer, `pc-watch.service` |
| `applications` | `$HOME/.local/share` | `.desktop` overrides, the pc-watch icon |

## Resource tuning

`./install.sh --only tuning` sizes every limit from the machine it runs on —
nothing is a fixed number, so the same repo is right on a small laptop and a
big workstation. Re-run it after moving to new hardware.

| What | Limit |
| --- | --- |
| ZFS ARC (when ZFS is loaded) | 6–20% of RAM, via `tmpfiles.d` (never `modprobe.d`/initramfs) |
| zram swap | half of RAM, at most 8 GiB, zstd |
| All Docker containers (`containers.slice`) | reclaim at 50% of RAM, hard cap 65%, 75% of the cores |
| Batch jobs (`background.slice`) | reclaim at 25% of RAM, hard cap 35%, half the cores, idle CPU priority |
| Ollama | unload after 5 idle minutes, one model, cap 60% of RAM |
| Power | `performance` profile at boot; PL1 cap only on listed laptop models |
| Hybrid-graphics laptops | NVIDIA GPU on-demand with runtime D3, so it sleeps until CUDA/prime-run wakes it |

A user unit joins the batch pool with `Slice=background.slice`.

### Staying smooth

| Command | What it does |
| --- | --- |
| `pc-watch` (service) | Reads pressure stalls, memory, swap and temperature every 5 s. When the machine is *about* to lag it pops a notification naming the cause and the heaviest apps, with **Details** and **Pause background jobs** buttons. One per episode, updated in place, then a short "back to normal". |
| `pc-status [--watch]` | One screen: smooth / getting heavy / lagging and why, usage bars, slice limits, heaviest apps, recent guard actions. |
| `pc-freeze-guard` (every minute) | On high swap, restarts idle desktop utilities sitting on swap. Lagging for 2 minutes: freezes every unit in `background.slice`; 5 minutes: stops them. Thaws when smooth. `--freeze` / `--thaw` by hand. |
| `pc-background-gate <cmd>` | Starts a command only after the desktop has been idle for a while and stops it when you return. |

All of them share one rule (`~/.local/lib/pc/gauges.sh`): pressure-stall time
first, because that is what lag is; fill levels second; swap only counts while
RAM is also tight. Every threshold is a percentage.

### Re-running is cheap

Every step checks what is already there and reports it on one line
(`✓ 80 apt packages already in place`); only missing pieces are installed,
`apt-get update` runs only when something is about to be installed, and
services are enabled only if they are not already.

## Personal overlay

Anything personal — your services, scripts for your data, project lists,
work aliases, git identity — belongs in a separate private repo with its own
`install.sh`, by default `~/dotfiles-private` cloned from
`<your-github>/dotfiles-private`. `install.sh` runs it last. Override with
`DOTFILES_PRIVATE_DIR` / `DOTFILES_PRIVATE_REPO`. This repo only provides
the hooks: `~/.bashrc.d/*.sh` is sourced by `.bashrc`, and `~/.gitconfig.local`
is included by `.gitconfig`.

## Look and feel

Installer output goes through cli-kit (a gum + Catppuccin shell UI library),
cloned to `~/projects/personal/cli-kit` on first run (`CLI_KIT_REPO` to
override). Without it, the same output is printed plainly.

## Agent skills

Skills live once in `~/.agents/skills` (stowed from `skills/`) and are
symlinked into each agent's own directory. `packages/dev/skills.map` decides
who sees what:

```
.claude/skills: find-skills frontend-design improve skill-creator turborepo
.gemini/skills: all
.config/opencode/skills: find-skills frontend-design skill-creator
```

Add a skill by dropping it in `skills/.agents/skills/<name>/`, listing it in
`skills.map`, and running `./install.sh --only skills`.

## Adding something new

1. Install it however you normally would.
2. Run `./bin/snapshot.sh` — it will show up as `+ not in any manifest`.
3. Add the line to the right `packages/<tier>/` file, or run
   `./bin/snapshot.sh --write` and move it out of `packages/unsorted/`.
4. Commit.

Config files are checked the same way: `snapshot.sh` diffs each tracked file
against its live copy, and `--write` copies the live version back into the repo.

## After the automated install

These cannot be scripted:

1. `source ~/.bashrc`, then set **GeistMono Nerd Font** as the terminal font
   and select the **Catppuccin Mocha** profile in GNOME Terminal preferences.
2. Log out and back in so `docker` group membership applies.
3. Authenticate: `gh auth login`, `ngrok config add-authtoken <token>`,
   `sudo tailscale up`, plus the individual logins for `claude`, `codex`,
   `agy`, `opencode`, and `coderabbit`.
4. `gh extension install github/gh-copilot` — enables the `ghcs` / `ghce`
   shell helpers defined in `.bashrc`.
5. Inside tmux, `prefix + I` to install plugins (the installer does this too).
6. Security wordlists — `.bashrc` points `$SECURITY_TOOLS_DIR` at `~/security`,
   which is not created automatically:
   ```bash
   mkdir -p ~/security && git clone --depth 1 \
     https://github.com/danielmiessler/SecLists.git ~/security/SecLists
   ```
7. Review `packages/desktop/manual.md` for the apps that need a hand-download
   (RStudio, Zen, Waterfox, the AppImages) and the licences to re-enter.
8. Laptop sleep on NVIDIA hardware: `sudo ~/.local/bin/fix-pc-sleep`.

## Secrets

No credentials are tracked. `.gitignore` blocks tokens, keys, `auth.json`,
`.credentials*`, OAuth files, session history, and agent state. When adding a
new tracked config, check it with `git diff` before committing — several agent
tools write tokens into the same directories as their settings.

## Validating changes

There are no automated tests. Reload the affected tool:

- **Bash:** `source ~/.bashrc`
- **Tmux:** `prefix + R`
- **Neovim:** restart, or `:Lazy sync` after plugin changes
- **Scripts:** `bash -n install.sh lib/*.sh bin/*.sh`, then `--dry-run`
