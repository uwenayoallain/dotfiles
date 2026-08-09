#!/usr/bin/env bash

# Shared helpers for install.sh modules and bin/snapshot.sh.
# Sourced, never executed directly.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PACKAGES_DIR="$DOTFILES_DIR/packages"
DRY_RUN="${DRY_RUN:-false}"

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

print_step() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

command_exists() { command -v "$1" &> /dev/null; }

# Run a command, or just print it when DRY_RUN is on.
run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[dry-run]${NC} $*"
        return 0
    fi
    "$@"
}

# Read a manifest into a bash array, skipping comments and blank lines.
# Usage: read_manifest <array-name> <file> [<file>...]
read_manifest() {
    local -n _target=$1
    shift
    local file line
    for file in "$@"; do
        [ -f "$file" ] || continue
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [ -z "$line" ] && continue
            _target+=("$line")
        done < "$file"
    done
    return 0
}

# Collect the manifest files for one package manager across the active tiers.
# Usage: tier_manifests <array-name> <manager>
tier_manifests() {
    local -n _files=$1
    local manager=$2
    local tier
    for tier in "${ACTIVE_TIERS[@]}"; do
        local candidate="$PACKAGES_DIR/$tier/$manager.txt"
        [ -f "$candidate" ] && _files+=("$candidate")
    done
    # Without this the function inherits the status of the last -f test, which
    # under `set -e` would abort the caller whenever the last tier has no
    # manifest for this manager.
    return 0
}

# True when <tier> is one of the tiers selected for this run.
tier_active() {
    local tier
    for tier in "${ACTIVE_TIERS[@]}"; do
        [ "$tier" = "$1" ] && return 0
    done
    return 1
}

# True when the module should run.
#
# `--only` is an explicit override and wins outright. Otherwise a module runs
# only if the tier it belongs to is active, so `--tier core` on a server does
# not drag in SDKs, GUI apps, or the desktop theme. MODULE_TIER lives in
# install.sh; a module absent from it runs in every tier.
module_enabled() {
    local name=$1

    if [ ${#ONLY_MODULES[@]} -gt 0 ]; then
        local wanted
        for wanted in "${ONLY_MODULES[@]}"; do
            [ "$wanted" = "$name" ] && return 0
        done
        return 1
    fi

    local required="${MODULE_TIER[$name]:-}"
    [ -z "$required" ] && return 0
    tier_active "$required"
}

# Shell startup files that third-party installers like to append to.
SHELL_RC_FILES=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
    "$HOME/.zshrc"
)

# Run an installer that appends PATH lines to the shell startup files.
#
# Once the dotfiles are stowed those files are symlinks into this repo, so an
# installer appending to ~/.bashrc silently edits a tracked file. This swaps
# each symlink for a plain copy, runs the command, then restores the symlink
# and throws the installer's additions away — .bashrc already exports
# everything they would have added.
#
# Usage: shielded <command> [args...]
shielded() {
    if [ "$DRY_RUN" = true ]; then
        run "$@"
        return 0
    fi

    local -a shielded_files=() shielded_targets=()
    local rc link_value resolved
    for rc in "${SHELL_RC_FILES[@]}"; do
        [ -L "$rc" ] || continue
        # Keep the raw link value so the symlink is restored exactly as it
        # was; resolve separately, because the value is often relative to
        # $HOME and would not resolve against the current directory.
        link_value=$(readlink "$rc")
        resolved=$(readlink -f "$rc")
        shielded_files+=("$rc")
        shielded_targets+=("$link_value")
        rm "$rc"
        if [ -f "$resolved" ]; then
            cp "$resolved" "$rc"
        else
            : > "$rc"
        fi
    done

    local status=0
    "$@" || status=$?

    local i
    for i in "${!shielded_files[@]}"; do
        rm -f "${shielded_files[$i]}"
        ln -s "${shielded_targets[$i]}" "${shielded_files[$i]}"
    done

    return "$status"
}

# Keep a single sudo credential alive for the whole run so long installs
# do not stall waiting for a password prompt nobody is watching.
sudo_keepalive_pid=""
start_sudo_keepalive() {
    [ "$DRY_RUN" = true ] && return 0
    command_exists sudo || return 0
    [ -n "$sudo_keepalive_pid" ] && return 0
    sudo -v || return 1
    while true; do
        sudo -n true 2>/dev/null
        sleep 60
    done &> /dev/null &
    sudo_keepalive_pid=$!
}

stop_sudo_keepalive() {
    [ -n "$sudo_keepalive_pid" ] && kill "$sudo_keepalive_pid" 2>/dev/null
    sudo_keepalive_pid=""
}
