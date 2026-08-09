# Package manifests

What to install, grouped by tier. `install.sh` reads every manifest for the
active tiers and concatenates them, so a package listed in `core` is installed
whether you asked for `core` alone or `core,dev,desktop`.

## Tiers

| Tier | Runs by default | For |
| --- | --- | --- |
| `core` | yes | Shell, build tools, and the CLI utilities `.bashrc` depends on. Safe on a headless server. |
| `dev` | yes | Docker, podman, Node/Flutter/Java, AI CLIs, VS Code, agent skills. |
| `desktop` | yes | Browsers, GUI apps, snaps, flatpaks, fonts, GNOME settings. |
| `optional` | **no** | Host-specific: NVIDIA driver, ZFS, NTFS/exFAT. Check the hardware first. |

A tier also decides which `install.sh` modules run — see `MODULE_TIER` in
`install.sh`. Dropping a `snap.txt` into `packages/core/` would not make snaps
install on a `--tier core` run, because the `snap` module itself is gated on
the `desktop` tier.

## File format

One entry per line. `#` starts a comment, blank lines are ignored, and
trailing comments are stripped:

```
ripgrep          # modern grep
```

| File | Consumed by | Entry format |
| --- | --- | --- |
| `apt.txt` | `lib/apt.sh` | package name |
| `brew.txt` | `lib/brew.sh` | formula name |
| `snap.txt` | `lib/snap.sh` | name, plus optional flags: `slack-term --edge` |
| `flatpak.txt` | `lib/snap.sh` | application ID, installed `--user` from flathub |
| `npm.txt` `pnpm.txt` `bun.txt` | `lib/node.sh` | package spec |
| `vscode.txt` | `lib/desktop.sh` | `publisher.extension` |
| `claude-plugins.txt` | `lib/skills.sh` | `marketplace <name> <repo>` or `plugin@marketplace` |
| `skills.map` | `lib/skills.sh` | `<dir relative to $HOME>: <skill>... \| all` |
| `manual.md` | humans | apps with no scriptable download |

## Keeping it accurate

```bash
./bin/snapshot.sh            # report what drifted
./bin/snapshot.sh --write    # write new packages to packages/unsorted/
```

Tier assignment is a judgement call, so `--write` never edits a tier file. It
drops additions in `packages/unsorted/` (gitignored) for you to file by hand.

Some packages legitimately show up as "in a manifest, not installed here" —
things you want on a new machine but have not installed on this one. That is
information, not an error.

## Adding a third-party apt repository

`apt.txt` cannot install from a repository that does not exist yet. Add the
repo to `install_apt_repos()` in `lib/apt.sh` first:

```bash
add_repo <name> <signing-key-url> <deb source line>
```

It writes `/etc/apt/keyrings/<name>.gpg` and
`/etc/apt/sources.list.d/<name>.list`, skips if the list file already exists,
and warns instead of failing when the key cannot be fetched.
