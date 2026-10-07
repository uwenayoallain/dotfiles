#!/usr/bin/env bash

# Re-read the live system and report what has drifted from the manifests.
#
#   ./bin/snapshot.sh            # report only
#   ./bin/snapshot.sh --write    # also copy live config files back into the repo
#                                # and write new packages into packages/unsorted/
#
# Tier assignments are curated by hand, so this never rewrites the tier files.
# Anything new lands in packages/unsorted/ for you to file into the right tier.

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=../lib/desktop.sh
. "$DOTFILES_DIR/lib/desktop.sh"

WRITE=false
[ "${1:-}" = "--write" ] && WRITE=true

ACTIVE_TIERS=(core dev desktop optional)
UNSORTED="$PACKAGES_DIR/unsorted"

# Base-system packages that come with Ubuntu itself. They show up in
# `apt-mark showmanual` but reinstalling them on a fresh system is pointless
# and, for the boot and kernel ones, actively risky.
#
# It also skips the hand-downloaded .deb apps tracked in
# packages/desktop/manual.md, which no repository can supply.
APT_IGNORE_RE='^(appimagelauncher|jdk-21|opencode|open-code|rstudio|xnview|ubuntu-|linux-generic|linux-image|linux-headers|grub-|shim-|efibootmgr|language-pack|ibus-|lib(chewing|m17n|marisa|otf|opencc|pinyin)|m17n-db|zfs-initramfs|bsdutils|dash|diffutils|findutils|grep|gzip|hostname|init$|login$|ncurses-|cups|wpasupplicant|cpu-checker|python3-netifaces|uuid-runtime|ca-certificates|apt-transport-https|dirmngr|gpg$|file$|procps$)'

# compare <label> <manifest-name> [<ignore regex>] <live list on stdin>
# The ignore regex is applied to both sides so filtered base-system packages
# do not show up as "in a manifest but not installed".
compare() {
    local label=$1 manager=$2 ignore_re=${3:-}
    local live_file
    live_file=$(mktemp)
    sort -u > "$live_file"

    local files=()
    tier_manifests files "$manager"
    local tracked=()
    read_manifest tracked "${files[@]}"

    local tracked_file
    tracked_file=$(mktemp)
    printf '%s\n' "${tracked[@]}" | awk 'NF {print $1}' | sort -u > "$tracked_file"

    if [ -n "$ignore_re" ]; then
        grep -vE "$ignore_re" "$tracked_file" > "$tracked_file.f" || true
        mv "$tracked_file.f" "$tracked_file"
    fi

    local added removed
    added=$(comm -23 "$live_file" "$tracked_file")
    removed=$(comm -13 "$live_file" "$tracked_file")

    if [ -z "$added" ] && [ -z "$removed" ]; then
        print_success "$label: in sync"
    else
        echo -e "${YELLOW}$label:${NC}"
        [ -n "$added" ] && echo "$added" | sed 's/^/    + on this machine, not in any manifest: /'
        [ -n "$removed" ] && echo "$removed" | sed 's/^/    - in a manifest, not installed here:  /'
        if [ "$WRITE" = true ] && [ -n "$added" ]; then
            mkdir -p "$UNSORTED"
            echo "$added" > "$UNSORTED/$manager.txt"
            print_info "Wrote $UNSORTED/$manager.txt"
        fi
    fi

    rm -f "$live_file" "$tracked_file"
}

print_step "Package manifests"

apt-mark showmanual 2>/dev/null | grep -vE "$APT_IGNORE_RE" | compare "apt" apt "$APT_IGNORE_RE"

if command_exists brew; then
    brew leaves 2>/dev/null | compare "brew" brew
fi

if command_exists snap; then
    snap list 2>/dev/null | tail -n +2 | awk '$1 !~ /^(bare|core[0-9]*|gnome-|gtk-common-themes|mesa-|snapd|snap-store|firmware-updater|snapd-desktop-integration|gaming-graphics-)/ {print $1}' \
        | compare "snap" snap
fi

if command_exists flatpak; then
    flatpak list --app --columns=application 2>/dev/null | compare "flatpak" flatpak
fi

if command_exists code; then
    code --list-extensions 2>/dev/null | compare "vscode" vscode
fi

print_step "Tracked config files"

# repo path : live path
CONFIG_PAIRS=(
    "bashrc/.bashrc:$HOME/.bashrc"
    "bashrc/.bash_profile:$HOME/.bash_profile"
    "bashrc/.profile:$HOME/.profile"
    "bashrc/.inputrc:$HOME/.inputrc"
    "bashrc/.tmux.conf:$HOME/.tmux.conf"
    "gitconfig/.gitconfig:$HOME/.gitconfig"
    "ssh/.ssh/config:$HOME/.ssh/config"
    "agents/.claude/settings.json:$HOME/.claude/settings.json"
    "agents/.claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
    "agents/.gemini/settings.json:$HOME/.gemini/settings.json"
    "agents/.gemini/GEMINI.md:$HOME/.gemini/GEMINI.md"
    "opencode/opencode/opencode.jsonc:$HOME/.config/opencode/opencode.jsonc"
    "vscode/Code/User/settings.json:$HOME/.config/Code/User/settings.json"
    "vscode/Code/User/keybindings.json:$HOME/.config/Code/User/keybindings.json"
    "vscode/Code/User/mcp.json:$HOME/.config/Code/User/mcp.json"
    "localbin/.local/bin/fix-pc-sleep:$HOME/.local/bin/fix-pc-sleep"
    "localbin/.local/bin/pc-freeze-guard:$HOME/.local/bin/pc-freeze-guard"
    "localbin/.local/bin/pc-background-gate:$HOME/.local/bin/pc-background-gate"
    "localbin/.local/bin/pc-watch:$HOME/.local/bin/pc-watch"
    "localbin/.local/bin/pc-status:$HOME/.local/bin/pc-status"
    "localbin/.local/lib/pc/gauges.sh:$HOME/.local/lib/pc/gauges.sh"
    "systemd/systemd/user/pc-watch.service:$HOME/.config/systemd/user/pc-watch.service"
    "systemd/systemd/user/background.slice:$HOME/.config/systemd/user/background.slice"
    "systemd/systemd/user/pc-freeze-guard.service:$HOME/.config/systemd/user/pc-freeze-guard.service"
    "systemd/systemd/user/pc-freeze-guard.timer:$HOME/.config/systemd/user/pc-freeze-guard.timer"
)

drifted=0
for pair in "${CONFIG_PAIRS[@]}"; do
    repo="$DOTFILES_DIR/${pair%%:*}"
    live="${pair#*:}"
    [ -e "$live" ] || continue
    # A symlink back into this repo means stow owns it and it cannot drift.
    if [ -L "$live" ] && [ "$(readlink -f "$live")" = "$(readlink -f "$repo")" ]; then
        continue
    fi
    if ! diff -q "$repo" "$live" &> /dev/null; then
        echo -e "${YELLOW}    drifted:${NC} ${live#"$HOME"/}"
        drifted=$((drifted + 1))
        if [ "$WRITE" = true ]; then
            mkdir -p "$(dirname "$repo")"
            cp -p "$live" "$repo"
            print_info "Copied into ${pair%%:*}"
        fi
    fi
done
[ "$drifted" -eq 0 ] && print_success "All tracked config files match the repo"

print_step "Agent skills"
if [ -d "$HOME/.agents/skills" ]; then
    live_skills=$(find "$HOME/.agents/skills" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)
    repo_skills=$(find "$DOTFILES_DIR/skills/.agents/skills" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
    if [ "$live_skills" = "$repo_skills" ]; then
        print_success "Skill store is in sync"
    else
        comm -23 <(echo "$live_skills") <(echo "$repo_skills") | sed 's/^/    + not in the repo: /'
        comm -13 <(echo "$live_skills") <(echo "$repo_skills") | sed 's/^/    - not installed:   /'
        if [ "$WRITE" = true ]; then
            rm -rf "$DOTFILES_DIR/skills/.agents/skills"
            cp -rp "$HOME/.agents/skills" "$DOTFILES_DIR/skills/.agents/skills"
            print_info "Refreshed skills/ from ~/.agents/skills"
        fi
    fi
fi

print_step "GNOME settings"
if [ "$WRITE" = true ]; then
    dump_dconf
else
    print_info "Run with --write to refresh the dconf dumps"
fi

echo ""
if [ "$WRITE" = true ]; then
    print_success "Snapshot written. Review 'git diff', then file anything in packages/unsorted/ into a tier."
else
    print_success "Snapshot complete (read-only). Re-run with --write to apply."
fi
