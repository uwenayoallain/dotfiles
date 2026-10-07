#!/usr/bin/env bash

# Shell environment: Oh My Bash, TPM, fonts, terminal theme, git identity.

install_oh_my_bash() {
    if [ -d "$HOME/.oh-my-bash" ]; then
        mark_present "Oh My Bash"
        return 0
    fi
    print_info "Installing Oh My Bash..."
    # The upstream installer rewrites ~/.bashrc; `shielded` keeps it away from
    # the tracked copy. Our own .bashrc already sources oh-my-bash.sh.
    shielded bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" -- --unattended
}

install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ -d "$tpm_dir" ]; then
        mark_present "TPM"
        return 0
    fi
    print_info "Installing TPM..."
    run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
}

install_tmux_plugins() {
    [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] || return 0
    # Skip when every @plugin in the config already has its directory.
    local conf="$HOME/.config/tmux/tmux.conf" plugin missing=0 dir
    for plugin in $(sed -n "s/^set -g @plugin '\([^']*\)'.*/\1/p" "$conf" 2>/dev/null); do
        dir=${plugin##*/}
        [ -d "$HOME/.config/tmux/plugins/$dir" ] || [ -d "$HOME/.tmux/plugins/$dir" ] || missing=$((missing + 1))
    done
    [ "$missing" -eq 0 ] && return 0
    print_info "Installing $missing tmux plugin(s)..."
    run "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

install_nerd_font() {
    if grep -qi GeistMono < <(fc-list : family 2>/dev/null); then
        mark_present "GeistMono Nerd Font"
        return 0
    fi

    print_info "Installing GeistMono Nerd Font..."
    local font_dir="$HOME/.local/share/fonts"
    run mkdir -p "$font_dir"
    if [ "$DRY_RUN" != true ]; then
        local tmp_dir
        tmp_dir=$(mktemp -d)
        curl -fsSL -o "$tmp_dir/GeistMono.zip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip"
        unzip -qo "$tmp_dir/GeistMono.zip" -d "$font_dir"
        rm -rf "$tmp_dir"
        fc-cache -f > /dev/null
    fi
    print_success "GeistMono Nerd Font installed"
}

install_gnome_terminal_theme() {
    if ! command_exists gnome-terminal; then
        print_warning "GNOME Terminal not found, skipping theme"
        return 0
    fi
    command_exists dconf || run sudo apt-get install -y dconf-cli uuid-runtime

    if grep -qi catppuccin < <(dconf dump /org/gnome/terminal/legacy/profiles:/ 2>/dev/null); then
        mark_present "Catppuccin terminal theme"
        return 0
    fi
    print_info "Installing Catppuccin theme for GNOME Terminal..."
    if [ "$DRY_RUN" = true ]; then
        print_dry "clone catppuccin/gnome-terminal and run install.py"
        return 0
    fi
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --depth 1 https://github.com/catppuccin/gnome-terminal.git "$tmp_dir/theme" \
        && (cd "$tmp_dir/theme" && python3 install.py) \
        || print_warning "GNOME Terminal theme install failed, continuing"
    rm -rf "$tmp_dir"
}

install_shell_env() {
    print_step "Setting up the shell environment"
    install_oh_my_bash
    install_tpm
    # Fonts and the terminal theme need a desktop; on a headless box they are
    # just a wasted download.
    if tier_active desktop; then
        install_nerd_font
        install_gnome_terminal_theme
    else
        print_info "Desktop tier inactive, skipping fonts and terminal theme"
    fi
    flush_present "shell pieces"
}
