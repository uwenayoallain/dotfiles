# Bash Configuration File with Oh My Bash

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================
# Oh My Bash Configuration
# ============================================
export OSH="$HOME/.oh-my-bash"
export DISABLE_AUTO_UPDATE="true"

# Theme - empty because we use starship prompt
OSH_THEME=""

# Case-insensitive completion
OMB_CASE_SENSITIVE="false"

# Hyphen-insensitive completion (- and _ are interchangeable)
OMB_HYPHEN_SENSITIVE="false"

# Enable command auto-correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# History timestamp format
HIST_STAMPS='yyyy-mm-dd'

# Enable sudo plugin
OMB_USE_SUDO=true

# Completions to load
completions=(
    git
    ssh
    docker
    docker-compose
    makefile
    pip
    pip3
    tmux
    system
)

# Aliases to load
aliases=(
    general
)

# Plugins to load
plugins=(
    git
    bashmarks
    sudo
    npm
)

# Load Oh My Bash
if [ -f "$OSH/oh-my-bash.sh" ]; then
    source "$OSH/oh-my-bash.sh"
fi

# ============================================
# History Configuration (Enhanced)
# ============================================
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T "
shopt -s histappend

# Save and reload history after each command (shared across terminals)
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Check window size after each command
shopt -s checkwinsize

# ============================================
# Bash Completion (Additional)
# ============================================
# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Homebrew completions
if [ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d ]; then
    for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
        [ -f "$f" ] && . "$f"
    done
fi

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================
# Environment Variables
# ============================================
export LANG=en_US.UTF-8
export EDITOR=nvim
export GOPATH="$HOME/go"
export XDG_CONFIG_HOME="$HOME/.config"
export SECURITY_TOOLS_DIR="$HOME/security"
export NVM_DIR="$HOME/.config/nvm"
export PNPM_HOME="$HOME/.local/share/pnpm"
export BUN_INSTALL="$HOME/.bun"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'

# PATH
export PATH="$HOME/.local/bin:$PNPM_HOME:$PNPM_HOME/bin:$BUN_INSTALL/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.vimpkg/bin:${GOPATH}/bin:$HOME/.cargo/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

# ============================================
# Aliases
# ============================================

# General Aliases
alias la='tree'
if command -v bat &> /dev/null; then
    alias cat='bat'
fi
if command -v zoxide &> /dev/null; then
    alias cd='z'
fi
alias py='python3'
alias cl='clear'

# VIM Alias
alias v="nvim"
alias cc="codex --yolo"
alias ccl="claude --dangerously-skip-permissions"

# Git Aliases
alias gss='git status'
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gm='git merge'
alias gcoall='git checkout -- .'
alias gr='git remote'
alias gre='git reset'

# Docker Aliases
alias dco="docker compose"
alias dps="docker ps"
alias dpa="docker ps -a"
alias dl="docker ps -l -q"
alias dx="docker exec -it"

# Directory Navigation Aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# Eza Aliases (modern ls replacement)
if command -v eza &> /dev/null; then
    alias l="eza -l --icons --git -a"
    alias ls="eza --icons --git"
    alias lt="eza --tree --level=2 --long --icons --git"
    alias ltree="eza --tree --level=2 --icons --git"
fi

# HTTP Requests with xh
if command -v xh &> /dev/null; then
    alias http="xh"
fi

# Nmap Alias
alias nm="nmap -sC -sV -oN nmap"

# Security Tools Aliases
alias gobust="gobuster dir --wordlist \$SECURITY_TOOLS_DIR/wordlists/diccnoext.txt --wildcard --url"
alias dirsearch="python dirsearch.py -w \$SECURITY_TOOLS_DIR/db/dicc.txt -b -u"
alias server="python -m http.server 4445"
alias tunnel="ngrok http 4445"
alias fuzz="ffuf -w \$SECURITY_TOOLS_DIR/SecLists/content_discovery_all.txt -mc all -u"

# ============================================
# Functions
# ============================================

# Ranger: File manager integration that changes directory on exit
ranger() {
    local IFS=$'\t\n'
    local tempfile
    tempfile="$(mktemp -t tmp.XXXXXX)"
    local ranger_cmd=(
        command
        ranger
        --cmd="map Q chain shell echo %d > \"$tempfile\"; quitall"
    )

    "${ranger_cmd[@]}" "$@"
    if [[ -f "$tempfile" ]] && [[ "$(command cat -- "$tempfile")" != "$(echo -n "$(pwd)")" ]]; then
        cd -- "$(command cat "$tempfile")" || return
    fi
    command rm -f -- "$tempfile" 2>/dev/null
}
alias rr='ranger'

# Navigation Functions
cx() { cd "$@" && l; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | xclip -in -selection clipboard; }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)"; }

# History search function
hg() { history | grep "$1"; }

# System update function - updates all package managers and tools
update() {
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local RED='\033[0;31m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color

    local status_apt=0
    local status_brew=0
    local status_omb=0
    local status_tmux=0
    local status_nvim=0
    local status_uv=0
    local status_gh=0
    local status_pnpm=0
    local status_bun=0

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Updating All Systems${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check network connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${RED}[ERROR] No internet connection detected.${NC}"
        return 1
    fi

    # Helper function for retries
    retry() {
        local n=1
        local max=3
        local delay=5
        while true; do
            if "$@"; then
                return 0
            else
                if [[ $n -lt $max ]]; then
                    ((n++))
                    echo -e "${YELLOW}Command failed. Attempt $n/$max in ${delay}s...${NC}"
                    sleep $delay
                else
                    return 1
                fi
            fi
        done
    }

    # 1. APT
    if command -v apt &> /dev/null; then
        echo -e "${BLUE}[1/9] Updating APT repositories...${NC}"
        if sudo apt update && sudo apt upgrade -y --fix-missing; then
            echo -e "${GREEN}APT update complete${NC}"
        else
            echo -e "${RED}APT update failed${NC}"
            status_apt=1
        fi
        echo ""
    fi

    # 2. Homebrew
    if command -v brew &> /dev/null; then
        echo -e "${BLUE}[2/9] Updating Homebrew...${NC}"
        if retry brew update && brew upgrade; then
            echo -e "${GREEN}Homebrew update complete${NC}"
        else
            echo -e "${RED}Homebrew update failed after retries${NC}"
            status_brew=1
        fi
        brew cleanup -q 2>/dev/null || true
        echo ""
    fi

    # 3. Oh My Bash
    if [ -d "$OSH" ]; then
        echo -e "${BLUE}[3/9] Updating Oh My Bash...${NC}"
        [ -f "$OSH/log/update.lock" ] && rm -f "$OSH/log/update.lock"
        [ -d "$OSH/log/update.lock" ] && rm -rf "$OSH/log/update.lock"

        if retry git -C "$OSH" pull --rebase --stat origin master; then
            echo -e "${GREEN}Oh My Bash update complete${NC}"
        else
            echo -e "${RED}Oh My Bash update failed after retries${NC}"
            status_omb=1
        fi
        echo ""
    fi

    # 4. Tmux plugins
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        echo -e "${BLUE}[4/9] Updating Tmux plugins...${NC}"
        if retry "$HOME/.tmux/plugins/tpm/bin/update_plugins" all; then
            echo -e "${GREEN}Tmux plugins update complete${NC}"
        else
            echo -e "${RED}Tmux plugin update failed after retries${NC}"
            status_tmux=1
        fi
        echo ""
    fi

    # 5. Neovim plugins
    if command -v nvim &> /dev/null; then
        echo -e "${BLUE}[5/9] Updating Neovim plugins...${NC}"
        if retry nvim --headless "+Lazy! sync" +qa; then
            echo -e "${GREEN}Neovim plugins update complete${NC}"
        else
            echo -e "${RED}Neovim Lazy sync failed after retries${NC}"
            status_nvim=1
        fi
        echo ""
    fi

    # 6. UV
    if command -v uv &> /dev/null; then
        echo -e "${BLUE}[6/9] Updating uv...${NC}"
        if [[ "$(command -v uv)" == *"/home/linuxbrew/.linuxbrew/bin/uv" ]]; then
            echo -e "${YELLOW}uv is managed by Homebrew, skipping self-update...${NC}"
            status_uv=0
        elif retry uv self update; then
            echo -e "${GREEN}uv self-update complete${NC}"
        else
            echo -e "${RED}uv update failed after retries${NC}"
            status_uv=1
        fi
        echo ""
    fi

    # 7. GitHub CLI Extensions
    if command -v gh &> /dev/null; then
        echo -e "${BLUE}[7/9] Updating GitHub CLI Extensions...${NC}"
        if retry gh extension upgrade --all; then
            echo -e "${GREEN}GH extensions update complete${NC}"
        else
            echo -e "${RED}GH extensions update failed after retries${NC}"
            status_gh=1
        fi
        echo ""
    fi

    # 8. pnpm
    if command -v pnpm &> /dev/null; then
        echo -e "${BLUE}[8/9] Updating pnpm...${NC}"
        if command -v corepack &> /dev/null; then
            if retry corepack install -g pnpm@latest; then
                echo -e "${GREEN}pnpm update complete (via corepack)${NC}"
            else
                echo -e "${RED}pnpm update failed after retries${NC}"
                status_pnpm=1
            fi
        elif retry pnpm self-update; then
             echo -e "${GREEN}pnpm update complete${NC}"
        else
             echo -e "${RED}pnpm update failed after retries${NC}"
             status_pnpm=1
        fi
        echo ""
    fi

    # 9. bun
    if command -v bun &> /dev/null; then
        echo -e "${BLUE}[9/9] Updating bun...${NC}"
        if retry bun upgrade; then
             echo -e "${GREEN}bun update complete${NC}"
        else
             echo -e "${RED}bun update failed after retries${NC}"
             status_bun=1
        fi
        echo ""
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Summary${NC}"
    echo -e "${BLUE}========================================${NC}"

    [ $status_apt -eq 0 ] && echo -e "${GREEN}[✓] APT${NC}" || echo -e "${RED}[✗] APT${NC}"
    [ $status_brew -eq 0 ] && echo -e "${GREEN}[✓] Homebrew${NC}" || echo -e "${RED}[✗] Homebrew${NC}"
    [ $status_omb -eq 0 ] && echo -e "${GREEN}[✓] Oh My Bash${NC}" || echo -e "${RED}[✗] Oh My Bash${NC}"
    [ $status_tmux -eq 0 ] && echo -e "${GREEN}[✓] Tmux Plugins${NC}" || echo -e "${RED}[✗] Tmux Plugins${NC}"
    [ $status_nvim -eq 0 ] && echo -e "${GREEN}[✓] Neovim Plugins${NC}" || echo -e "${RED}[✗] Neovim Plugins${NC}"
    [ $status_uv -eq 0 ] && echo -e "${GREEN}[✓] uv${NC}" || echo -e "${RED}[✗] uv${NC}"
    [ $status_gh -eq 0 ] && echo -e "${GREEN}[✓] GH Extensions${NC}" || echo -e "${RED}[✗] GH Extensions${NC}"
    [ $status_pnpm -eq 0 ] && echo -e "${GREEN}[✓] pnpm${NC}" || echo -e "${RED}[✗] pnpm${NC}"
    [ $status_bun -eq 0 ] && echo -e "${GREEN}[✓] bun${NC}" || echo -e "${RED}[✗] bun${NC}"

    echo -e "${BLUE}========================================${NC}"
    if [ $((status_apt + status_brew + status_omb + status_tmux + status_nvim + status_uv + status_gh + status_pnpm + status_bun)) -gt 0 ]; then
        echo -e "${YELLOW}Note: Some updates failed. This is often due to network instability.${NC}"
        echo -e "${YELLOW}Try running 'update' again when your connection is more stable.${NC}"
    fi
}

# ─── Terminal UI helpers ──────────────────────────────────────────────
# Animated single-line progress bar that never wraps the terminal.
# Usage: call ui_progress <current> <total> <title> [detail] repeatedly
# while working, then ui_progress_done when finished.
#   ⠸ Scanning $HOME █████████░░░░░░░░░░░░░  42% (10/24) projects
ui_progress() {
    local current=$1 total=$2 title=$3 detail=${4:-}
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    local pct=0
    [ "$total" -gt 0 ] && pct=$(( current * 100 / total ))
    (( pct > 100 )) && pct=100
    _ui_frame=$(( (${_ui_frame:-0} + 1) % 10 ))
    local counter="(${current}/${total})"
    # Shrink the bar on narrow terminals so the line never wraps
    local bar_w=$(( cols - ${#title} - ${#counter} - 13 ))
    (( bar_w > 22 )) && bar_w=22
    if (( bar_w < 5 )); then
        printf '\r\033[K \033[1;36m%s\033[0m %3d%%' "${frames:$_ui_frame:1}" "$pct"
        return
    fi
    local filled bar='' i
    filled=$(( pct * bar_w / 100 ))
    for (( i = 0; i < bar_w; i++ )); do
        if (( i < filled )); then bar+='█'; else bar+='░'; fi
    done
    # Truncate the detail text with whatever width remains
    local avail=$(( cols - ${#title} - bar_w - ${#counter} - 13 ))
    (( avail < 0 )) && avail=0
    detail=${detail:0:avail}
    printf '\r\033[K \033[1;36m%s\033[0m %s \033[32m%s\033[0m %3d%% \033[2m%s %s\033[0m' \
        "${frames:_ui_frame:1}" "$title" "$bar" "$pct" "$counter" "$detail"
}
ui_progress_done() { printf '\r\033[K'; }

# Disk cleanup function - frees space by clearing caches and safe temporary files
cleanup() {
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local RED='\033[0;31m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color

    local before_kb
    before_kb=$(df --output=avail / | tail -1 | tr -dc '0-9')

    # On ZFS, df on / only reflects the root dataset; report pool usage instead
    disk_usage_line() {
        if command -v zpool &> /dev/null && zpool list rpool &> /dev/null; then
            zpool list -H -o alloc,size,capacity rpool | awk '{printf "Disk: %s used of %s (%s)\n", $1, $2, $3}'
        else
            df -h / | tail -1 | awk '{printf "Disk: %s used of %s (%s)\n", $3, $2, $5}'
        fi
    }

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Cleaning Up Disk Space${NC}"
    echo -e "${BLUE}========================================${NC}"
    disk_usage_line
    echo ""

    # Ask for the sudo password once and keep the credential fresh
    # so later sudo steps never re-prompt
    local sudo_keepalive_pid=""
    if command -v sudo &> /dev/null; then
        if ! sudo -v; then
            echo -e "${RED}sudo authentication failed; skipping steps that need it${NC}"
        else
            sudo_keepalive_pid=$( { while true; do sudo -n true 2>/dev/null; sleep 60; done >/dev/null 2>&1 & echo $!; } )
        fi
    fi

    # 1. APT caches and orphaned packages
    if command -v apt-get &> /dev/null; then
        echo -e "${BLUE}[1/8] Cleaning APT caches...${NC}"
        if sudo -n apt-get autoremove -y --purge && sudo -n apt-get clean; then
            echo -e "${GREEN}APT cleanup complete${NC}"
        else
            echo -e "${RED}APT cleanup failed${NC}"
        fi
        echo ""
    fi

    # 2. Homebrew caches and outdated downloads
    if command -v brew &> /dev/null; then
        echo -e "${BLUE}[2/8] Cleaning Homebrew caches...${NC}"
        brew cleanup --prune=all 2>/dev/null || true
        echo -e "${GREEN}Homebrew cleanup complete${NC}"
        echo ""
    fi

    # 3. Systemd journal logs older than 7 days
    if command -v journalctl &> /dev/null; then
        echo -e "${BLUE}[3/8] Vacuuming journal logs (keeping 7 days)...${NC}"
        sudo -n journalctl --vacuum-time=7d 2>/dev/null || true
        echo -e "${GREEN}Journal cleanup complete${NC}"
        echo ""
    fi

    # 4. User cache files not touched in 30 days
    if [ -d "$HOME/.cache" ]; then
        echo -e "${BLUE}[4/8] Removing ~/.cache files older than 30 days...${NC}"
        find "$HOME/.cache" -type f -atime +30 -delete 2>/dev/null || true
        find "$HOME/.cache" -mindepth 1 -type d -empty -delete 2>/dev/null || true
        echo -e "${GREEN}User cache cleanup complete${NC}"
        echo ""
    fi

    # 5. Trash older than 30 days
    if [ -d "$HOME/.local/share/Trash" ]; then
        echo -e "${BLUE}[5/8] Emptying trash items older than 30 days...${NC}"
        find "$HOME/.local/share/Trash/files" -mindepth 1 -mtime +30 -exec rm -rf {} + 2>/dev/null || true
        find "$HOME/.local/share/Trash/info" -mindepth 1 -mtime +30 -delete 2>/dev/null || true
        echo -e "${GREEN}Trash cleanup complete${NC}"
        echo ""
    fi

    # 6. Language/package-manager caches (pip, uv, npm, pnpm, bun)
    echo -e "${BLUE}[6/8] Cleaning language package caches...${NC}"
    command -v pip &> /dev/null && pip cache purge 2>/dev/null || true
    command -v uv &> /dev/null && uv cache clean 2>/dev/null || true
    command -v npm &> /dev/null && npm cache clean --force 2>/dev/null || true
    command -v pnpm &> /dev/null && pnpm store prune 2>/dev/null || true
    [ -d "$HOME/.bun/install/cache" ] && rm -rf "$HOME/.bun/install/cache"/* 2>/dev/null || true
    echo -e "${GREEN}Package cache cleanup complete${NC}"
    echo ""

    # 7. Stale Neovim swap/undo files older than 30 days
    echo -e "${BLUE}[7/8] Removing stale Neovim swap/undo files...${NC}"
    find "$HOME/.local/state/nvim/swap" -type f -mtime +30 -delete 2>/dev/null || true
    find "$HOME/.local/state/nvim/undo" -type f -mtime +30 -delete 2>/dev/null || true
    echo -e "${GREEN}Neovim state cleanup complete${NC}"
    echo ""

    # 8. Thumbnail cache
    echo -e "${BLUE}[8/8] Clearing thumbnail cache...${NC}"
    rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
    echo -e "${GREEN}Thumbnail cleanup complete${NC}"
    echo ""

    [ -n "$sudo_keepalive_pid" ] && kill "$sudo_keepalive_pid" 2>/dev/null

    local after_kb freed_mb
    after_kb=$(df --output=avail / | tail -1 | tr -dc '0-9')
    freed_mb=$(( (after_kb - before_kb) / 1024 ))
    [ "$freed_mb" -lt 0 ] && freed_mb=0

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    disk_usage_line
    echo -e "${GREEN}Freed approximately ${freed_mb} MB${NC}"
    echo -e "${YELLOW}Tip: 'docker system prune' and 'sudo apt autoclean' can free more if needed.${NC}"
    echo ""

    # Report (but never touch) the biggest storage consumers
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Largest Storage Consumers (report only)${NC}"
    echo -e "${BLUE}========================================${NC}"
    if command -v zfs &> /dev/null && zfs list rpool &> /dev/null; then
        echo -e "${YELLOW}ZFS datasets:${NC}"
        zfs list -r -o name,used -S used rpool 2>/dev/null | head -6
        echo ""
    fi
    echo -e "${YELLOW}Top 10 directories in \$HOME:${NC}"
    local scan_dirs=() scan_tmp scan_dir scan_pid scan_i=0
    mapfile -t scan_dirs < <(find "$HOME" -mindepth 1 -maxdepth 1 -type d | sort)
    scan_tmp=$(mktemp)
    # Subshell keeps interactive job-control notices out of the output
    (
        for scan_dir in "${scan_dirs[@]}"; do
            scan_i=$((scan_i + 1))
            du -xsb "$scan_dir" >> "$scan_tmp" 2>/dev/null &
            scan_pid=$!
            while kill -0 "$scan_pid" 2>/dev/null; do
                ui_progress "$scan_i" "${#scan_dirs[@]}" 'Scanning $HOME' "${scan_dir##*/}"
                sleep 0.1
            done
            wait "$scan_pid" 2>/dev/null
        done
        ui_progress_done
    )
    sort -rn "$scan_tmp" | head -10 | while IFS=$'\t' read -r scan_bytes scan_path; do
        printf '%s\t%s\n' "$(numfmt --to=iec "$scan_bytes")" "$scan_path"
    done
    rm -f "$scan_tmp"
    echo -e "${YELLOW}Nothing above was deleted — review manually before removing.${NC}"
}

# Occasional disk space check - runs at most once a day on shell startup
# and suggests 'cleanup' when the root filesystem is nearly full
disk_check() {
    local threshold=85
    local usage
    # On ZFS, df on / only reflects the root dataset; use pool capacity instead
    if command -v zpool &> /dev/null && zpool list rpool &> /dev/null; then
        usage=$(zpool list -H -o capacity rpool | tr -dc '0-9')
    else
        usage=$(df --output=pcent / | tail -1 | tr -dc '0-9')
    fi
    if [ -n "$usage" ] && [ "$usage" -ge "$threshold" ]; then
        echo -e "\033[1;33m[!] Disk usage at ${usage}% — run 'cleanup' to free space.\033[0m"
    fi
}

_disk_check_stamp="$HOME/.cache/.disk_check_stamp"
if [ ! -f "$_disk_check_stamp" ] || [ -n "$(find "$_disk_check_stamp" -mmin +1440 2>/dev/null)" ]; then
    mkdir -p "$HOME/.cache" && touch "$_disk_check_stamp"
    disk_check
fi
unset _disk_check_stamp

# GitHub Copilot Suggest (ghcs)
ghcs() {
    local FUNCNAME="${FUNCNAME[0]}"
    local TARGET="shell"
    local GH_DEBUG="$GH_DEBUG"
    local GH_HOST="$GH_HOST"

    read -r -d '' __USAGE <<-'EOF'
Wrapper around `gh copilot suggest` to propose a command based on a natural language description.
Supports executing the suggested command if applicable.

USAGE:
    ghcs [flags] <prompt>

FLAGS:
    -d, --debug        Enable debugging.
    -h, --help         Display this help message.
        --hostname     The GitHub host to use for authentication.
    -t, --target       Target for suggestion; must be shell, gh, or git (default: "shell").

EXAMPLES:
    # Guided experience:
    $ ghcs

    # Git use cases:
    $ ghcs -t git "Undo the most recent local commits"
    $ ghcs -t git "Clean up local branches"
    $ ghcs -t git "Setup LFS for images"

    # GitHub CLI use cases:
    $ ghcs -t gh "Create pull request"
    $ ghcs -t gh "Summarize work I have done in issues and pull requests for promotion"

    # General use cases:
    $ ghcs "Kill processes holding onto deleted files"
    $ ghcs "Test for SSL/TLS issues with github.com"
    $ ghcs "Convert SVG to PNG and resize"
    $ ghcs "Convert MOV to animated PNG"
EOF

    local OPT OPTARG OPTIND
    while getopts "dht:-:" OPT; do
        if [ "$OPT" = "-" ]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#"$OPT"}"
            OPTARG="${OPTARG#=}"
        fi

        case "$OPT" in
        debug | d)
            GH_DEBUG=api
            ;;
        help | h)
            echo "$__USAGE"
            return 0
            ;;
        hostname)
            GH_HOST="$OPTARG"
            ;;
        target | t)
            TARGET="$OPTARG"
            ;;
        esac
    done

    shift "$((OPTIND - 1))"

    local TMPFILE
    TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
    trap 'rm -f "$TMPFILE"' EXIT
    if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
        if [ -s "$TMPFILE" ]; then
            local FIXED_CMD
            FIXED_CMD="$(cat "$TMPFILE")"
            history -s -- "$FIXED_CMD"
            echo
            eval -- "$FIXED_CMD"
        fi
    else
        return 1
    fi
}

# GitHub Copilot Explain (ghce)
ghce() {
    local FUNCNAME="${FUNCNAME[0]}"
    local GH_DEBUG="$GH_DEBUG"
    local GH_HOST="$GH_HOST"

    read -r -d '' __USAGE <<-'EOF'
Wrapper around `gh copilot explain` to provide a natural language explanation of a given command.

USAGE:
    ghce [flags] <command>

FLAGS:
    -d, --debug     Enable debugging.
    -h, --help      Display this help message.
        --hostname  The GitHub host to use for authentication.

EXAMPLES:
    $ ghce 'du -sh | sort -h'
    $ ghce 'git log --oneline --graph --decorate --all'
    $ ghce 'bfg --strip-blobs-bigger-than 50M'
EOF

    local OPT OPTARG OPTIND
    while getopts "dh-:" OPT; do
        if [ "$OPT" = "-" ]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#"$OPT"}"
            OPTARG="${OPTARG#=}"
        fi

        case "$OPT" in
        debug | d)
            GH_DEBUG=api
            ;;
        help | h)
            echo "$__USAGE"
            return 0
            ;;
        hostname)
            GH_HOST="$OPTARG"
            ;;
        esac
    done

    shift "$((OPTIND - 1))"

    GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}

# ============================================
# Tool Initialization
# ============================================

# NVM and Node.js
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# FZF keybindings and completion
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -f /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.bash ] && source /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.bash
[ -f /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.bash ] && source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.bash

# Initialize zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Initialize direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook bash)"
fi

# Initialize uv
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion bash)"
fi

# Machine- or person-specific additions (aliases for particular projects,
# work shortcuts) live outside this public repo, one file per topic.
if [ -d "$HOME/.bashrc.d" ]; then
    for rc in "$HOME"/.bashrc.d/*.sh; do
        [ -r "$rc" ] && . "$rc"
    done
    unset rc
fi

# Initialize starship prompt (should be at the end)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi


# Antigravity CLI
export PATH="$HOME/.local/bin:$PATH"

# Vite+ (https://viteplus.dev) — guarded so a machine without it still gets a
# working shell instead of an error on every prompt.
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"

# opencode
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
