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
#   ./install.sh --pick                   # choose tiers, steps, and apps in checklists

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# cli-kit gives every screen below its look (gum + Catppuccin). Fetch it first
# on a fresh machine; if that fails the installer runs with plain output.
CLI_KIT_HOME="$HOME/projects/personal/cli-kit"
if [ ! -f "$CLI_KIT_HOME/ui.sh" ] && [ ! -f "$DOTFILES_DIR/cli-kit/ui.sh" ] && command -v git > /dev/null; then
    owner=$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null \
        | sed -E 's#^(git@github\.com:|https://github\.com/)([^/]+)/.*#\2#')
    # Private repo: gh's credentials first, then SSH, then anonymous HTTPS.
    if [ -n "${CLI_KIT_REPO:-}" ]; then
        git clone --quiet --depth 1 "$CLI_KIT_REPO" "$CLI_KIT_HOME" 2>/dev/null || true
    elif command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
        gh repo clone "$owner/cli-kit" "$CLI_KIT_HOME" -- --quiet --depth 1 2>/dev/null || true
    fi
    [ -f "$CLI_KIT_HOME/ui.sh" ] || git clone --quiet --depth 1 "git@github.com:$owner/cli-kit.git" "$CLI_KIT_HOME" 2>/dev/null \
        || git clone --quiet --depth 1 "https://github.com/$owner/cli-kit.git" "$CLI_KIT_HOME" 2>/dev/null || true
    [ -x "$CLI_KIT_HOME/install-gum" ] && [ -t 1 ] && "$CLI_KIT_HOME/install-gum" 2>/dev/null \
        && export PATH="$HOME/.local/bin:$PATH"
fi

# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
for module in apt brew snap node sdk apps shell desktop skills stow tuning private pick; do
    # shellcheck disable=SC1090
    . "$DOTFILES_DIR/lib/$module.sh"
done

ALL_TIERS=(core dev desktop optional)
DEFAULT_TIERS=(core dev desktop)
ACTIVE_TIERS=("${DEFAULT_TIERS[@]}")
ONLY_MODULES=()
SKIP_STOW=false
PICK=false

MODULES=(
    "apt:Third-party apt repositories and apt packages"
    "brew:Linuxbrew and its formulae"
    "snap:Snap packages"
    "flatpak:Flatpak applications"
    "node:NVM, Node LTS, npm/pnpm/bun globals"
    "sdk:Vite+ toolchain"
    "apps:DuckDB, AI CLIs, miniserve, AppImageLauncher"
    "shell:Oh My Bash, TPM, fonts, terminal theme"
    "vscode:VS Code extensions"
    "gnome:GNOME dconf settings"
    "tuning:Memory, swap, ZFS, Docker and power limits sized to this machine"
    "stow:Symlink the dotfiles and enable user services"
    "skills:Agent skill store fan-out and Claude Code plugins"
    "private:Personal overlay: your services, scripts, and project repos"
)

# The tier a module belongs to. Modules listed here are skipped unless that
# tier is active, so `--tier core` produces a genuinely headless install.
# Anything not listed (apt, brew, shell, stow) runs in every tier.
# Modules that run something under sudo. Everything else works unprivileged.
ROOT_MODULES=(apt brew snap flatpak sdk apps shell tuning)

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
  --pick           Choose tiers, install steps, and individual apps interactively
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
            --pick) PICK=true; shift ;;
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
    if [ "$PICK" = true ]; then run_picker; fi

    local started
    started=$(date +%s)

    # Section headers each module prints, so steps can be numbered "[n/total]".
    local -A module_steps=(
        [apt]=2 [brew]=1 [snap]=1 [flatpak]=1 [node]=1 [sdk]=1 [apps]=1
        [shell]=1 [vscode]=1 [gnome]=1 [tuning]=2 [stow]=2 [skills]=2 [private]=1
    )
    local entry name enabled=()
    STEP_TOTAL=0
    for entry in "${MODULES[@]}"; do
        name=${entry%%:*}
        module_enabled "$name" || continue
        [ "$name" = stow ] && [ "$SKIP_STOW" = true ] && continue
        enabled+=("$name")
        STEP_TOTAL=$(( STEP_TOTAL + ${module_steps[$name]:-1} ))
    done

    local mode="install"
    [ "$DRY_RUN" = true ] && mode="dry run (nothing will be changed)"
    print_banner "Workstation bootstrap" "$(hostname) · $(nproc) CPUs · $(( ($(awk '/^MemTotal:/ {print $2}' /proc/meminfo) + 524288) / 1048576 )) GB RAM" \
        "Mode" "$mode" \
        "Tiers" "${ACTIVE_TIERS[*]}" \
        "Steps" "${enabled[*]:-none}" \
        "Skipping" "${EXCLUDED_PACKAGES[*]:-nothing}"

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
        install_apt_repos
        install_apt_packages
        configure_auto_updates
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
    if module_enabled tuning; then install_tuning; fi

    if module_enabled stow && [ "$SKIP_STOW" = false ]; then
        stow_dotfiles
        enable_user_services
        install_tmux_plugins
    fi
    # After stow: the user half needs background.slice and the guard units.
    if module_enabled tuning; then install_user_tuning; fi

    # Runs after stow so the skill store at ~/.agents/skills already exists.
    if module_enabled skills; then install_agent_skills; fi

    # Last, so the overlay can rely on everything above being in place.
    if module_enabled private; then install_private_overlay; fi

    stop_sudo_keepalive

    print_summary "$started"
    echo ""
    echo -e "${BOLD}Manual steps that cannot be scripted:${NC}"
    cat <<'EOF'
  1. source ~/.bashrc  (or open a new terminal)
  2. Set "GeistMono Nerd Font" as the terminal font
  3. Select the "Catppuccin Mocha" profile in GNOME Terminal preferences
  4. Log out and back in so docker group membership takes effect
  5. Authenticate:  gh auth login
                    ngrok config add-authtoken <token>
                    sudo tailscale up
                    claude / codex / agy / opencode  (each has its own login)
  6. gh extension install github/gh-copilot   — enables the ghcs/ghce shell helpers
  7. Review packages/desktop/manual.md for apps that need a hand-download
EOF
    echo ""
}

main "$@"
