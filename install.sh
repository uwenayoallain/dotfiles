#!/usr/bin/env bash

# Workstation bootstrap.
#
# Installs every tool, application, and config this machine relies on, from
# manifests under packages/ and modules under lib/. Safe to re-run: every step
# checks for what it is about to install first.
#
#   ./install.sh                          # core + dev + desktop
#   ./install.sh --tier core              # headless / server subset
#   ./install.sh --tier optional          # host-specific drivers and filesystems
#   ./install.sh --only apt,stow          # re-run just those modules
#   ./install.sh --dry-run                # print what would happen
#   ./install.sh --list                   # show tiers and modules

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
for module in apt brew snap node sdk apps shell desktop skills stow; do
    # shellcheck disable=SC1090
    . "$DOTFILES_DIR/lib/$module.sh"
done

ALL_TIERS=(core dev desktop optional)
DEFAULT_TIERS=(core dev desktop)
ACTIVE_TIERS=("${DEFAULT_TIERS[@]}")
ONLY_MODULES=()
SKIP_STOW=false

MODULES=(
    "apt:Third-party apt repositories and apt packages"
    "brew:Linuxbrew and its formulae"
    "snap:Snap packages"
    "flatpak:Flatpak applications"
    "node:NVM, Node LTS, npm/pnpm/bun globals"
    "sdk:Flutter, Android Studio, Vite+"
    "apps:DuckDB, AI CLIs, miniserve, AppImageLauncher"
    "shell:Oh My Bash, TPM, fonts, terminal theme"
    "vscode:VS Code extensions"
    "gnome:GNOME dconf settings"
    "stow:Symlink the dotfiles and enable user services"
    "skills:Agent skill store fan-out and Claude Code plugins"
)

# The tier a module belongs to. Modules listed here are skipped unless that
# tier is active, so `--tier core` produces a genuinely headless install.
# Anything not listed (apt, brew, shell, stow) runs in every tier.
# Modules that run something under sudo. Everything else works unprivileged.
ROOT_MODULES=(apt brew snap flatpak sdk apps shell)

declare -A MODULE_TIER=(
    [snap]=desktop
    [flatpak]=desktop
    [gnome]=desktop
    [node]=dev
    [sdk]=dev
    [apps]=dev
    [vscode]=dev
    [skills]=dev
)

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --tier <list>    Comma-separated tiers to install (default: ${DEFAULT_TIERS[*]})
                   Available: ${ALL_TIERS[*]}
  --only <list>    Comma-separated modules to run (default: all)
  --no-stow        Install tools only, do not symlink the dotfiles
  --dry-run        Print the actions instead of performing them
  --list           List the available tiers and modules, then exit
  -h, --help       Show this message
EOF
}

list_targets() {
    echo "Tiers:"
    local tier
    for tier in "${ALL_TIERS[@]}"; do
        local counts=""
        local manifest
        for manifest in "$PACKAGES_DIR/$tier"/*.txt; do
            [ -e "$manifest" ] || continue
            local n
            n=$(grep -cvE '^\s*(#|$)' "$manifest")
            counts+=" $(basename "$manifest" .txt)=$n"
        done
        printf '  %-10s%s\n' "$tier" "${counts:-  (no manifests)}"
    done
    echo ""
    echo "Modules:"
    local entry
    for entry in "${MODULES[@]}"; do
        printf '  %-10s %s\n' "${entry%%:*}" "${entry#*:}"
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tier)
                IFS=',' read -ra ACTIVE_TIERS <<< "$2"
                shift 2
                ;;
            --only)
                IFS=',' read -ra ONLY_MODULES <<< "$2"
                shift 2
                ;;
            --no-stow) SKIP_STOW=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            --list) list_targets; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) print_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    local tier valid
    for tier in "${ACTIVE_TIERS[@]}"; do
        valid=false
        local known
        for known in "${ALL_TIERS[@]}"; do
            [ "$tier" = "$known" ] && valid=true
        done
        if [ "$valid" = false ]; then
            print_error "Unknown tier '$tier'. Available: ${ALL_TIERS[*]}"
            exit 1
        fi
    done
}

main() {
    parse_args "$@"

    echo ""
    echo "========================================"
    echo "   Workstation Bootstrap"
    echo "========================================"
    print_info "Tiers:   ${ACTIVE_TIERS[*]}"
    print_info "Modules: ${ONLY_MODULES[*]:-all}"
    [ "$DRY_RUN" = true ] && print_warning "Dry run — nothing will be changed"
    echo ""

    # Only ask for a password when a module that actually needs root will run,
    # so `--only skills` or `--only stow` stay password-free.
    local needs_root=false module
    for module in "${ROOT_MODULES[@]}"; do
        if module_enabled "$module"; then
            needs_root=true
            break
        fi
    done

    if [ "$needs_root" = true ] && [ "$DRY_RUN" != true ]; then
        if ! start_sudo_keepalive; then
            print_error "sudo authentication failed"
            exit 1
        fi
    fi
    trap stop_sudo_keepalive EXIT

    if module_enabled apt; then
        run sudo apt-get update
        install_apt_repos
        install_apt_packages
    fi
    if module_enabled brew; then install_brew; setup_fzf; fi
    if module_enabled snap; then install_snaps; fi
    if module_enabled flatpak; then install_flatpaks; fi
    if module_enabled node; then install_node; fi
    if module_enabled sdk; then install_sdks; fi
    if module_enabled apps; then install_apps; fi
    if module_enabled shell; then install_shell_env; fi
    if module_enabled vscode; then install_vscode_extensions; fi
    if module_enabled gnome; then load_dconf; fi

    if module_enabled stow && [ "$SKIP_STOW" = false ]; then
        stow_dotfiles
        enable_user_services
        install_tmux_plugins
    fi

    # Runs after stow so the skill store at ~/.agents/skills already exists.
    if module_enabled skills; then install_agent_skills; fi

    stop_sudo_keepalive

    echo ""
    print_success "Installation complete"
    echo ""
    print_info "Manual steps that cannot be scripted:"
    cat <<'EOF'
  1. source ~/.bashrc  (or open a new terminal)
  2. Set "GeistMono Nerd Font" as the terminal font
  3. Select the "Catppuccin Mocha" profile in GNOME Terminal preferences
  4. Log out and back in so docker group membership takes effect
  5. Authenticate:  gh auth login
                    ngrok config add-authtoken <token>
                    sudo tailscale up
                    claude / codex / gemini / opencode / cursor-agent  (each has its own login)
  6. flutter doctor          — finish the Android/Flutter toolchain
  7. gh extension install github/gh-copilot   — enables the ghcs/ghce shell helpers
  8. Review packages/desktop/manual.md for apps that need a hand-download
EOF
    echo ""
}

main "$@"
