#!/usr/bin/env bash

# Quick setup script using stow
# For full installation with tool setup, run: ./install.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Backup existing files that would conflict
backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
home_files=(".bashrc" ".inputrc")
needs_backup=false

for file in "${home_files[@]}"; do
    if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
        needs_backup=true
        break
    fi
done

if [ "$needs_backup" = true ]; then
    echo "Backing up existing files to $backup_dir..."
    mkdir -p "$backup_dir"
    
    for file in "${home_files[@]}"; do
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            mv "$HOME/$file" "$backup_dir/"
            echo "Backed up $file"
        fi
    done
fi

# Stow bashrc and ssh files to $HOME
echo "Stowing bashrc and ssh to \$HOME..."
stow -t "$HOME" bashrc ssh

# Stow other configs to ~/.config
echo "Stowing configs to ~/.config..."
mkdir -p "$HOME/.config"
stow -t "$HOME/.config" nvim starship tmux wezterm

echo "Stowing application launcher overrides to ~/.local/share..."
mkdir -p "$HOME/.local/share"
stow -t "$HOME/.local/share" applications

# Install uv if brew is available but uv is missing
if command -v brew &> /dev/null && ! command -v uv &> /dev/null; then
    echo "Installing uv via Homebrew..."
    brew install uv
fi

extensions_file="$DOTFILES_DIR/vscode/extensions.txt"
if command -v code &> /dev/null && [ -f "$extensions_file" ]; then
    echo "Installing VS Code extensions..."
    while IFS= read -r extension || [ -n "$extension" ]; do
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue
        code --install-extension "$extension" --force
    done < "$extensions_file"
fi

echo "Done! Restart your terminal or run: source ~/.bashrc"
