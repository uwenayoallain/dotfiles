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
        unzip
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
    
    git config --global user.name "UWENAYO Alain Pacifique"
    git config --global user.email "uwenayoallain@gmail.com"
    
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
    echo ""
}

main "$@"
