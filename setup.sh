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

if command -v python3 &> /dev/null; then
    settings_file="$HOME/.config/Code/User/settings.json"
    rg_path="/home/linuxbrew/.linuxbrew/bin/rg"
    if [ ! -x "$rg_path" ] && command -v rg &> /dev/null; then
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
    echo "Configured VS Code Todo Tree ripgrep path: $rg_path"
fi

echo "Done! Restart your terminal or run: source ~/.bashrc"
