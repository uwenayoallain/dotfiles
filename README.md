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

That single command installs every tier except `optional`, then symlinks the
configs. It is idempotent — re-run it any time.

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

./setup.sh                      # symlinks only, with backups
./setup.sh --unstow             # remove the symlinks

./bin/snapshot.sh               # report drift between this PC and the repo
./bin/snapshot.sh --write       # pull live config and new packages back in
```

## Tiers

| Tier | What it covers | Modules it enables |
| --- | --- | --- |
| `core` | Shell, build tools, and the CLI utilities `.bashrc` depends on. Safe on a server. | `apt` `brew` `shell` `stow` |
| `dev` | Docker, podman, Node/Flutter/Java, AI CLIs, VS Code, agent skills. | `node` `sdk` `apps` `vscode` `skills` |
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
  sdk.sh apps.sh shell.sh desktop.sh skills.sh stow.sh

bin/snapshot.sh        # re-read the live system, report what drifted
dconf/                 # GNOME settings dumps, one file per dconf path
```

Everything else is a stow package whose directory mirrors its target path:

| Package | Target | Contents |
| --- | --- | --- |
| `bashrc` | `$HOME` | `.bashrc`, `.bash_profile`, `.profile`, `.inputrc`, `.tmux.conf` |
| `gitconfig` | `$HOME` | `.gitconfig` |
| `ssh` | `$HOME` | `.ssh/config` |
| `localbin` | `$HOME` | `.local/bin` scripts: `serve`, `serve-media`, `fix-pc-sleep` |
| `agents` | `$HOME` | Claude, Codex, and Gemini config files |
| `skills` | `$HOME` | `.agents/skills` — the shared skill store |
| `nvim` `tmux` `starship` `wezterm` | `$HOME/.config` | editor, multiplexer, prompt, terminal |
| `vscode` | `$HOME/.config` | `Code/User` settings, keybindings, snippets, MCP |
| `opencode` | `$HOME/.config` | `opencode.jsonc` |
| `systemd` | `$HOME/.config` | user services (`media-server`, `t3code`, `appimagelauncherd`) |
| `applications` | `$HOME/.local/share` | `.desktop` overrides and media-server assets |

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
   `gemini`, `opencode`, `cursor-agent`, and `coderabbit`.
4. `gh extension install github/gh-copilot` — enables the `ghcs` / `ghce`
   shell helpers defined in `.bashrc`.
5. `flutter doctor` to finish the Android/Flutter toolchain, and extract
   Android Studio to `/opt/android-studio` if you want the IDE.
6. Inside tmux, `prefix + I` to install plugins (the installer does this too).
7. Security wordlists — `.bashrc` points `$SECURITY_TOOLS_DIR` at `~/security`,
   which is not created automatically:
   ```bash
   mkdir -p ~/security && git clone --depth 1 \
     https://github.com/danielmiessler/SecLists.git ~/security/SecLists
   ```
8. Review `packages/desktop/manual.md` for the apps that need a hand-download
   (RStudio, Zen, Waterfox, the AppImages) and the licences to re-enter.
9. Laptop sleep on NVIDIA hardware: `sudo ~/.local/bin/fix-pc-sleep`.

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
