#!/usr/bin/env bash

# Shared helpers for install.sh modules and bin/snapshot.sh.
# Sourced, never executed directly.

# Colors only on a terminal, and never when NO_COLOR is set (no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PACKAGES_DIR="$DOTFILES_DIR/packages"
DRY_RUN="${DRY_RUN:-false}"
EXCLUDED_PACKAGES=()

# Warnings are echoed as they happen and repeated in the final summary, so a
# long install cannot bury the one line that needed attention.
WARNINGS=()
STEP_NUM=0
STEP_TOTAL="${STEP_TOTAL:-0}"

print_info() { echo -e "  ${BLUE}→${NC} $1"; }
print_success() { echo -e "  ${GREEN}✓${NC} $1"; }
print_warning() {
    echo -e "  ${YELLOW}!${NC} $1"
    WARNINGS+=("$1")
}
print_error() { echo -e "  ${RED}✗ $1${NC}" >&2; }

# Section header, numbered when STEP_TOTAL is known: "── [3/9] Title ──────"
print_step() {
    STEP_NUM=$((STEP_NUM + 1))
    local counter=""
    [ "$STEP_TOTAL" -gt 0 ] && counter="[$STEP_NUM/$STEP_TOTAL] "
    local title="$counter$1"
    local width=72 pad rule=""
    pad=$(( width - ${#title} - 4 ))
    [ "$pad" -lt 3 ] && pad=3
    # Built in a loop: `tr` is byte-based and mangles multi-byte characters.
    while [ "$pad" -gt 0 ]; do rule+="─"; pad=$((pad - 1)); done
    echo ""
    echo -e "${BOLD}${CYAN}── ${title} ${rule}${NC}"
}

# One "│ text │" row padded by character count; printf's %-Ns counts bytes,
# which misaligns the box as soon as a line contains "·" or "→".
box_row() {
    local text=$1 style=${2:-} width=68
    text=${text:0:$width}
    local pad=$(( width - ${#text} ))
    printf "${BOLD}${CYAN}│${NC}  ${style}%s${NC}%*s${BOLD}${CYAN}│${NC}\n" "$text" "$pad" ""
}

# print_banner <title> <subtitle> [<key> <value>]...
print_banner() {
    local title=$1 subtitle=$2
    shift 2
    local rule="──────────────────────────────────────────────────────────────────────"
    echo ""
    echo -e "${BOLD}${CYAN}╭${rule}╮${NC}"
    box_row "$title" "$BOLD"
    box_row "$subtitle" "$DIM"
    echo -e "${BOLD}${CYAN}├${rule}┤${NC}"
    # Long values wrap onto continuation lines under their own column.
    local key line first
    while [ $# -ge 2 ]; do
        key=$1 first=true
        while IFS= read -r line; do
            if [ "$first" = true ]; then
                box_row "$(printf '%-10s %s' "$key" "$line")"
                first=false
            else
                box_row "$(printf '%-10s %s' "" "$line")"
            fi
        done < <(fold -s -w 57 <<< "$2" | sed 's/ *$//')
        shift 2
    done
    echo -e "${BOLD}${CYAN}╰${rule}╯${NC}"
}

# print_summary <started-at-epoch>
print_summary() {
    local elapsed=$(( $(date +%s) - $1 ))
    echo ""
    if [ ${#WARNINGS[@]} -eq 0 ]; then
        echo -e "${BOLD}${GREEN}✓ Done in $((elapsed / 60))m $((elapsed % 60))s, no warnings.${NC}"
    else
        echo -e "${BOLD}${YELLOW}! Done in $((elapsed / 60))m $((elapsed % 60))s with ${#WARNINGS[@]} warning(s):${NC}"
        local w
        for w in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}•${NC} $w"
        done
    fi
}


command_exists() { command -v "$1" &> /dev/null; }

print_dry() { echo -e "  ${DIM}[dry-run] $1${NC}"; }

# Run a command, or just print it when DRY_RUN is on.
run() {
    if [ "$DRY_RUN" = true ]; then
        print_dry "$*"
        return 0
    fi
    "$@"
}

# True when <package> was deselected in the --pick checklists.
is_excluded() {
    local pkg
    for pkg in "${EXCLUDED_PACKAGES[@]}"; do
        [ "$pkg" = "$1" ] && return 0
    done
    return 1
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
            # Unticked in `install.sh --pick` (lib/pick.sh).
            is_excluded "${line%% *}" && continue
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

# --- cli-kit ----------------------------------------------------------------
# When cli-kit (gum-based UI library, its own repo) is available, every
# print_* helper above renders through it, so install.sh, the overlay, and
# bin/ scripts share one look. Without it the plain helpers above stand.
CK_DIR_CANDIDATES=(
    "${CK_DIR:-}"
    "$DOTFILES_DIR/cli-kit"
    "$HOME/.local/share/cli-kit"
    "$HOME/projects/personal/cli-kit"
)
for _ck in "${CK_DIR_CANDIDATES[@]}"; do
    if [ -n "$_ck" ] && [ -f "$_ck/ui.sh" ]; then
        CK_DIR="$_ck"
        # shellcheck source=/dev/null
        . "$CK_DIR/ui.sh"
        CLI_KIT=true
        print_info() { ui_info "$1"; }
        print_success() { ui_ok "$1"; }
        print_warning() { ui_warn "$1"; WARNINGS+=("$1"); }
        print_error() { ui_err "$1"; }
        print_dry() { ui_dry "$1"; }
        print_step() { STEP_NUM=$((STEP_NUM + 1)); CK_STEPS=$STEP_TOTAL; ui_step "$1"; }
        print_banner() { ui_banner "$@"; }
        print_summary() { ui_summary "$1"; }
        break
    fi
done
unset _ck
CLI_KIT="${CLI_KIT:-false}"
