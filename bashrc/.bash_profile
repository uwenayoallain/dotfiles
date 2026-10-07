# Login shell entry point. Everything interactive lives in ~/.bashrc.

# Antigravity CLI
export PATH="$HOME/.local/bin:$PATH"

# Vite+ (https://viteplus.dev)
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
