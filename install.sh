#!/usr/bin/env bash

# Dotfiles Installation Script for Ubuntu
# This script installs all required tools, prioritizing Linuxbrew when appropriate

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================
# Prerequisites (via apt)
# ============================================
install_prerequisites() {
    print_info "Installing prerequisites via apt..."
    sudo apt update
    sudo apt install -y \
        build-essential \
        curl \
        git \
        stow \
        bat \
        tree \
        xclip \
        nmap \
        tmux \
        file \
        procps \
        bash-completion \
        unzip \
        ca-certificates \
        gpg \
        apt-transport-https \
        software-properties-common \
        python3-pip \
        python3-venv \
        jq \
        cmake \
        shellcheck \
        shfmt \
        openjdk-21-jre-headless \
        maven
    
    # Fix for bat on Ubuntu (installed as batcat)
    if command_exists batcat && ! command_exists bat; then
        print_info "Fixing bat command (batcat -> bat)..."
        sudo ln -s /usr/bin/batcat /usr/local/bin/bat
    fi

    print_success "Prerequisites installed"
}

# ============================================
# Linuxbrew Installation
# ============================================
install_linuxbrew() {
    if command_exists brew; then
        print_info "Homebrew is already installed"
    else
        print_info "Installing Homebrew (Linuxbrew)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        print_success "Homebrew installed"
    fi
    
    # Ensure brew is in PATH
    if [ -d /home/linuxbrew/.linuxbrew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
}

# ============================================
# Tools via Homebrew
# ============================================
install_brew_packages() {
    print_info "Installing packages via Homebrew..."
    
    local packages=(
        eza        # Modern ls replacement
        fd         # Modern find replacement
        zoxide     # Smarter cd command
        starship   # Cross-shell prompt
        xh         # Modern HTTP client
        fzf        # Fuzzy finder
        ranger     # File manager
        direnv     # Directory-based env management
        neovim     # Text editor
        gobuster   # Directory/file brute-forcer
        ffuf       # Fast web fuzzer
        uv         # Extremely fast Python package installer and resolver
        ripgrep    # Fast recursive search (rg)
        flyctl     # Fly.io CLI
        jupyterlab # Notebook/lab environment
    )
    
    for package in "${packages[@]}"; do
        if brew list "$package" &> /dev/null; then
            print_info "$package is already installed"
        else
            print_info "Installing $package..."
            brew install "$package"
        fi
    done
    
    print_success "Homebrew packages installed"
}

# ============================================
# GitHub CLI
# ============================================
install_gh() {
    if command_exists gh; then
        print_info "GitHub CLI is already installed"
    else
        print_info "Installing GitHub CLI..."
        sudo apt install -y gh
        print_success "GitHub CLI installed"
    fi
}

# ============================================
# Docker (via official apt repo)
# ============================================
install_docker() {
    if command_exists docker; then
        print_info "Docker is already installed"
    else
        print_info "Installing Docker via official repository..."

        sudo apt install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        sudo usermod -aG docker "$USER"

        print_success "Docker installed"
        print_warning "Log out and back in for docker group membership to take effect"
    fi
}

# ============================================
# NVM (Node Version Manager) + Node.js
# ============================================
install_nvm() {
    export NVM_DIR="$HOME/.config/nvm"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        print_info "NVM is already installed"
    else
        print_info "Installing NVM (Node Version Manager)..."
        mkdir -p "$NVM_DIR"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        print_success "NVM installed"
    fi

    # Load NVM for this session
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! nvm ls --lts --no-colors | grep -q 'v[0-9]'; then
        print_info "Installing Node.js LTS via NVM..."
        nvm install --lts
    else
        print_info "Node.js LTS is already installed in NVM"
    fi

    nvm alias default 'lts/*'
    nvm use default
    print_success "Node.js active version: $(node --version)"
}

# ============================================
# Node Ecosystem (pnpm + bun)
# ============================================
install_node_ecosystem() {
    # Ensure NVM and Node are loaded
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Enable pnpm via corepack
    if command_exists corepack; then
        print_info "Enabling pnpm via corepack..."
        corepack enable pnpm
        print_success "pnpm enabled: $(pnpm --version 2>/dev/null || echo 'ready')"
    else
        print_warning "corepack not found, skipping pnpm setup"
    fi

    # Install bun
    if command_exists bun; then
        print_info "bun is already installed"
    else
        print_info "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
        print_success "bun installed"
    fi

    local npm_packages=(
        @anthropic-ai/claude-code
        @google/gemini-cli
        @openai/codex
        opencode-ai
        yarn
    )

    for package in "${npm_packages[@]}"; do
        print_info "Installing/updating npm global package: $package"
        npm install -g "$package"
    done

    export PNPM_HOME="$HOME/.local/share/pnpm"
    mkdir -p "$PNPM_HOME"
    export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"

    if command_exists pnpm; then
        print_info "Installing/updating pnpm global package: kirimase"
        pnpm add -g kirimase
    fi
}

# ============================================
# DuckDB
# ============================================
install_duckdb() {
    if command_exists duckdb; then
        print_info "DuckDB is already installed"
    else
        print_info "Installing DuckDB..."
        mkdir -p "$HOME/.local/bin"
        local tmp_dir
        tmp_dir=$(mktemp -d)
        curl -fsSL -o "$tmp_dir/duckdb.zip" \
            "https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip"
        unzip -q "$tmp_dir/duckdb.zip" -d "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin/duckdb"
        rm -rf "$tmp_dir"
        print_success "DuckDB installed to ~/.local/bin/duckdb"
    fi
}

# ============================================
# Visual Studio Code
# ============================================
install_vscode() {
    if command_exists code; then
        print_info "Visual Studio Code is already installed"
    else
        print_info "Installing Visual Studio Code via the Microsoft apt repository..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
        sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        rm -f /tmp/packages.microsoft.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

        sudo apt update
        sudo apt install -y code
        print_success "Visual Studio Code installed"
    fi
}

install_vscode_extensions() {
    local extensions_file
    extensions_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vscode/extensions.txt"

    if ! command_exists code; then
        print_warning "code command not found, skipping VS Code extensions"
        return
    fi

    if [ ! -f "$extensions_file" ]; then
        print_warning "VS Code extension inventory not found, skipping"
        return
    fi

    print_info "Installing VS Code extensions from $extensions_file..."
    while IFS= read -r extension || [ -n "$extension" ]; do
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue
        code --install-extension "$extension" --force
    done < "$extensions_file"
    print_success "VS Code extensions installed"
}

configure_vscode_settings() {
    local settings_file="$HOME/.config/Code/User/settings.json"
    local rg_path="/home/linuxbrew/.linuxbrew/bin/rg"

    if [ ! -x "$rg_path" ] && command_exists rg; then
        rg_path="$(command -v rg)"
    fi

    mkdir -p "$(dirname "$settings_file")"

    python3 - "$settings_file" "$rg_path" <<'PY'
import re
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
rg_path = sys.argv[2]
key = "todo-tree.ripgrep"

if settings_path.exists() and settings_path.read_text().strip():
    text = settings_path.read_text()
else:
    settings_path.write_text('{\n  "todo-tree.ripgrep": "' + rg_path + '"\n}\n')
    sys.exit(0)

replacement = f'"{key}": "{rg_path}"'
if f'"{key}"' in text:
    text = re.sub(r'"todo-tree\.ripgrep"\s*:\s*"[^"]*"', replacement, text)
else:
    closing_index = text.rfind("}")
    if closing_index == -1:
        text = '{\n  "todo-tree.ripgrep": "' + rg_path + '"\n}\n'
    else:
        prefix = text[:closing_index].rstrip()
        suffix = text[closing_index:]
        if prefix.endswith("{"):
            insertion = "\n  " + replacement + "\n"
        elif prefix.endswith(","):
            insertion = "\n  " + replacement + ",\n"
        else:
            insertion = ",\n  " + replacement + "\n"
        text = prefix + insertion + suffix

settings_path.write_text(text)
PY

    print_success "VS Code Todo Tree configured to use $rg_path"
}

# ============================================
# ngrok Installation (via official apt repo)
# ============================================
install_ngrok() {
    if command_exists ngrok; then
        print_info "ngrok is already installed"
    else
        print_info "Installing ngrok via official repository..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update
        sudo apt install -y ngrok
        print_success "ngrok installed"
    fi
}

# ============================================
# TPM (Tmux Plugin Manager)
# ============================================
install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ -d "$tpm_dir" ]; then
        print_info "TPM is already installed"
    else
        print_info "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
        print_success "TPM installed"
        print_warning "Remember to press prefix + I inside tmux to install plugins"
    fi
}

# ============================================
# Oh My Bash Installation
# ============================================
install_oh_my_bash() {
    if [ -d "$HOME/.oh-my-bash" ]; then
        print_info "Oh My Bash is already installed"
    else
        print_info "Installing Oh My Bash..."
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
        print_success "Oh My Bash installed"
    fi
}

# ============================================
# FZF Key Bindings Setup
# ============================================
setup_fzf() {
    print_info "Setting up FZF key bindings..."
    if [ -f /home/linuxbrew/.linuxbrew/opt/fzf/install ]; then
        /home/linuxbrew/.linuxbrew/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-zsh
    fi
    print_success "FZF setup complete"
}

# ============================================
# Nerd Font Installation (GeistMono)
# ============================================
install_nerd_font() {
    local font_dir="$HOME/.local/share/fonts"
    local font_name="GeistMono"
    
    if fc-list | grep -qi "GeistMono"; then
        print_info "GeistMono Nerd Font is already installed"
        return
    fi
    
    print_info "Installing GeistMono Nerd Font..."
    
    mkdir -p "$font_dir"
    
    # Download latest GeistMono Nerd Font from GitHub releases
    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    curl -fsSL -o GeistMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip"
    unzip -q GeistMono.zip -d "$font_dir"
    
    # Clean up
    cd -
    rm -rf "$tmp_dir"
    
    # Refresh font cache
    fc-cache -fv
    
    print_success "GeistMono Nerd Font installed"
    print_warning "You may need to select 'GeistMono Nerd Font' in your terminal preferences"
}

# ============================================
# Catppuccin Theme for GNOME Terminal
# ============================================
install_gnome_terminal_theme() {
    # Check if we're running GNOME Terminal
    if ! command_exists gnome-terminal; then
        print_warning "GNOME Terminal not found, skipping theme installation"
        return
    fi
    
    if ! command_exists dconf; then
        print_info "Installing dconf-cli for GNOME Terminal theming..."
        sudo apt install -y dconf-cli uuid-runtime
    fi
    
    print_info "Installing Catppuccin theme for GNOME Terminal..."
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    # Clone the catppuccin gnome-terminal theme
    git clone https://github.com/catppuccin/gnome-terminal.git
    cd gnome-terminal
    
    # Install all Catppuccin themes
    python3 install.py
    
    # Clean up
    cd - > /dev/null
    rm -rf "$tmp_dir"
    
    print_success "Catppuccin themes installed for GNOME Terminal"
    print_warning "Open GNOME Terminal → Preferences → select 'Catppuccin Mocha' profile"
}

# ============================================
# Git Configuration
# ============================================
configure_git() {
    if ! command_exists git; then
        print_info "Installing git..."
        sudo apt install -y git
    fi
    
    print_info "Configuring git global settings..."
    
    git config --global user.name "Your Name"
    git config --global user.email "you@example.com"
    
    # Set some sensible defaults
    git config --global init.defaultBranch main
    git config --global core.editor "nvim"
    git config --global pull.rebase false
    
    print_success "Git configured:"
    echo "  Name:  $(git config --global user.name)"
    echo "  Email: $(git config --global user.email)"
}

# ============================================
# Stow Dotfiles
# ============================================
backup_existing_files() {
    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    local needs_backup=false
    
    # Check for existing files that would conflict
    local home_files=(".bashrc" ".inputrc")
    for file in "${home_files[@]}"; do
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            needs_backup=true
            break
        fi
    done
    
    if [ "$needs_backup" = true ]; then
        print_info "Backing up existing files to $backup_dir..."
        mkdir -p "$backup_dir"
        
        for file in "${home_files[@]}"; do
            if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                mv "$HOME/$file" "$backup_dir/"
                print_info "Backed up $file"
            fi
        done
        
        print_success "Backup complete"
    fi
}

stow_dotfiles() {
    print_info "Stowing dotfiles..."
    
    local dotfiles_dir
    dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$dotfiles_dir"
    
    # Backup existing files that would conflict
    backup_existing_files
    
    # Stow bashrc and ssh to $HOME
    print_info "Stowing bashrc and ssh to \$HOME..."
    stow -t "$HOME" bashrc ssh
    
    # Stow other configs to ~/.config
    print_info "Stowing configs to ~/.config..."
    mkdir -p "$HOME/.config"
    stow -t "$HOME/.config" nvim starship tmux wezterm

    # Stow application launcher overrides to ~/.local/share
    print_info "Stowing application launcher overrides to ~/.local/share..."
    mkdir -p "$HOME/.local/share"
    stow -t "$HOME/.local/share" applications

    print_success "Dotfiles stowed"
}

# ============================================
# Main
# ============================================
main() {
    echo ""
    echo "========================================"
    echo "   Dotfiles Installation Script"
    echo "========================================"
    echo ""
    
    # Parse arguments
    local skip_stow=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-stow)
                skip_stow=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-stow    Install tools only, don't stow dotfiles"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    install_prerequisites
    install_linuxbrew
    install_brew_packages
    install_gh
    install_docker
    install_nvm
    install_node_ecosystem
    install_duckdb
    install_vscode
    install_vscode_extensions
    configure_vscode_settings
    install_ngrok
    install_tpm
    install_oh_my_bash
    setup_fzf
    install_nerd_font
    install_gnome_terminal_theme
    configure_git
    
    if [ "$skip_stow" = false ]; then
        stow_dotfiles
    fi
    
    # Install tmux plugins
    print_info "Installing tmux plugins..."
    if [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        "$HOME/.tmux/plugins/tpm/bin/install_plugins"
        print_success "Tmux plugins installed"
    fi
    
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Set 'GeistMono Nerd Font' as your terminal font"
    echo "  3. Select 'Catppuccin Mocha' profile in GNOME Terminal preferences"
    echo "  4. Run 'ngrok config add-authtoken <token>' if you plan to use ngrok"
    echo "  5. Run 'gh auth login' to authenticate GitHub CLI"
    echo "  6. Run 'gh extension install github/gh-copilot' for Copilot shell integration"
    echo "  7. Log out and back in for Docker group membership to take effect"
    echo ""
}

main "$@"
