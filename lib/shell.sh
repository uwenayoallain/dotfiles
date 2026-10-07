#!/usr/bin/env bash

# Shell environment: Oh My Bash, TPM, fonts, terminal theme, git identity.

install_oh_my_bash() {
    if [ -d "$HOME/.oh-my-bash" ]; then
        print_info "Oh My Bash is already installed"
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
        print_info "TPM is already installed"
        return 0
    fi
    print_info "Installing TPM..."
    run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
}

install_tmux_plugins() {
    if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        print_info "Installing tmux plugins..."
        run "$HOME/.tmux/plugins/tpm/bin/install_plugins"
    fi
}

install_nerd_font() {
    if fc-list 2>/dev/null | grep -qi GeistMono; then
        print_info "GeistMono Nerd Font is already installed"
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
    print_success "Shell environment ready"
}
