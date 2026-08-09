#!/usr/bin/env bash

# Symlink the dotfiles with GNU Stow, without installing anything.
# Conflicting real files are moved into a timestamped backup directory first.
#
#   ./setup.sh              # stow everything
#   ./setup.sh --dry-run    # show what would be linked
#   ./setup.sh --unstow     # remove the symlinks

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=lib/stow.sh
. "$DOTFILES_DIR/lib/stow.sh"

UNSTOW=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --unstow) UNSTOW=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--unstow]"
            exit 0
            ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac
done

if ! command_exists stow; then
    print_error "GNU Stow is not installed. Run: sudo apt install stow"
    exit 1
fi

if [ "$UNSTOW" = true ]; then
    print_step "Unstowing dotfiles"
    cd "$DOTFILES_DIR"
    run stow -D -t "$HOME" "${STOW_HOME_PACKAGES[@]}"
    run stow -D -t "$HOME/.config" "${STOW_CONFIG_PACKAGES[@]}"
    run stow -D -t "$HOME/.local/share" "${STOW_SHARE_PACKAGES[@]}"
    print_success "Dotfiles unstowed"
    exit 0
fi

stow_dotfiles
enable_user_services

echo ""
print_info "Next: source ~/.bashrc, then 'prefix + I' inside tmux to install plugins"
