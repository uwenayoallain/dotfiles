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
    npm
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
[ -d "$HOME/flutter/bin" ] && export PATH="$HOME/flutter/bin:$PATH"
[ -d /opt/android-studio/bin ] && export PATH="$PATH:/opt/android-studio/bin"

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

# Initialize starship prompt (should be at the end)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

work_compose_file="$HOME/projects/work/work-project/docker-compose.common.yml"
if [ -f "$work_compose_file" ]; then
    alias d="docker compose -f $work_compose_file"
    alias dr='d up -d --remove-orphans --no-build'
    alias drb='d up -d --remove-orphans --build'
    alias drf='d down --remove-orphans && d build && d up -d --remove-orphans'
fi
unset work_compose_file

# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"
