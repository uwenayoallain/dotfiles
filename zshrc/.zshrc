# Reevaluate the prompt string each time it's displaying a prompt
setopt prompt_subst
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
autoload bashcompinit && bashcompinit
autoload -Uz compinit
compinit
source <(kubectl completion zsh)
complete -C '/usr/local/bin/aws_completer' aws  # CHECK PATH: Verify if aws_completer is at /usr/local/bin, adjust if needed. You might need to install awscli and its zsh completion separately.

source /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh # CHECK PATH: If using linuxbrew zsh-autosuggestions, verify this path. Otherwise, adjust path if installed differently or remove if not using.
bindkey '^w' autosuggest-execute
bindkey '^e' autosuggest-accept
bindkey '^u' autosuggest-toggle
bindkey '^L' vi-forward-word
bindkey '^k' up-line-or-search
bindkey '^j' down-line-or-search

eval "$(starship init zsh)"
export STARSHIP_CONFIG=~/.config/starship/starship.toml # CHECK PATH:  Ensure you have starship.toml at ~/.config/starship/ for custom prompt.

# You may need to manually set your language environment
export LANG=en_US.UTF-8

export EDITOR=/usr/bin/nvim # CHECK PATH: Adjust to your preferred editor's path, e.g., /usr/bin/vim, /usr/bin/nano, /usr/local/bin/code

alias la=tree
alias cat=bat
alias cd=z

# Git
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias gst="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gcoall='git checkout -- .'
alias gr='git remote'
alias gre='git reset'

# Docker
alias dco="docker compose"
alias dps="docker ps"
alias dpa="docker ps -a"
alias dl="docker ps -l -q"
alias dx="docker exec -it"

# Dirs
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# GO
export GOPATH='/home/rcaa/go' # ADJUST PATH: Change to your Go workspace path if needed.

# VIM
alias v="/usr/bin/nvim" # ADJUST PATH: Adjust if your nvim is in a different location

# Nmap
alias nm="nmap -sC -sV -oN nmap"

# PATH - Review and adjust carefully!
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/home/rcaa/.vimpkg/bin:${GOPATH}/bin:/home/rcaa/.cargo/bin:/home/linuxbrew/.linuxbrew/bin

alias cl='clear'

# K8S
export KUBECONFIG=~/.kube/config # CHECK PATH:  Verify path to your kubeconfig file.
alias k="kubectl"
alias ka="kubectl apply -f"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kl="kubectl logs"
alias kgpo="kubectl get pod"
alias kgd="kubectl get deployments"
alias kc="kubectx"
alias kns="kubens"
alias kl="kubectl logs -f"
alias ke="kubectl exec -it"
alias kcns='kubectl config set-context --current --namespace'
alias podname=''

# HTTP requests with xh!
alias http="xh"

# VI Mode!!!
bindkey jj vi-cmd-mode

# Eza
alias l="eza -l --icons --git -a"
alias ls="eza --icons --git"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"

# SEC STUFF - ADJUST PATHS BELOW TO YOUR SECURITY TOOL LOCATIONS AND WORDLISTS!
alias gobust='gobuster dir --wordlist ~/security/wordlists/diccnoext.txt --wildcard --url' # ADJUST WORDLIST PATH: Update to your wordlist path.
alias dirsearch='python dirsearch.py -w db/dicc.txt -b -u' # ADJUST PATHS: Update wordlist path, python path if needed, dirsearch path if not in PATH.
alias massdns='~/hacking/tools/massdns/bin/massdns -r ~/hacking/tools/massdns/lists/resolvers.txt -t A -o S bf-targets.txt -w livehosts.txt -s 4000' # ADJUST PATHS: Update paths for massdns, resolvers, etc.
alias server='python -m http.server 4445' # ADJUST PATH: Python path if needed.
alias tunnel='ngrok http 4445' # ENSURE PATH: Ensure ngrok is in PATH or adjust path here if needed.
alias fuzz='ffuf -w ~/hacking/SecLists/content_discovery_all.txt -mc all -u' # ADJUST WORDLIST PATH: Update wordlist path.
alias gr='~/go/src/github.com/tomnomnom/gf/gf' # ADJUST PATH: Update gf path if needed.

### FZF ###
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# alias mat='osascript -e "tell application \"System Events\" to key code 126 using {command down}" && tmux neww "cmatrix"'  # REMOVED: macOS specific, no direct Linux replacement in this config.

# Nix! - LINES BELOW ARE REMOVED BY DEFAULT AS PER ASSUMPTION OF NO NIX USAGE.
#       - UNCOMMENT AND KEEP IF YOU ARE USING NIX PACKAGE MANAGER.
# export NIX_CONF_DIR=$HOME/.config/nix
# export PATH=/run/current-system/sw/bin:$PATH
# if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
#     . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
# fi
# # End Nix


function ranger {
    local IFS=$'\t\n'
    local tempfile="$(mktemp -t tmp.XXXXXX)"
    local ranger_cmd=(
        command
        ranger
        --cmd="map Q chain shell echo %d > "$tempfile"; quitall"
    )

    ${ranger_cmd[@]} "$@"
    if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
        cd -- "$(cat "$tempfile")" || return
    fi
    command rm -f -- "$tempfile" 2>/dev/null
}
alias rr='ranger'

# navigation
cx() { cd "$@" && l; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | xclip -in -selection clipboard } # Using xclip for clipboard, install xclip if needed (sudo apt install xclip or equivalent) - OR - use 'xsel -ib' instead of 'xclip -in -selection clipboard' if you prefer xsel (install xsel if needed).  To just print to terminal without clipboard, remove '| xclip ...' part.
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)" }


export XDG_CONFIG_HOME="/home/rcaa/.config"

eval "$(zoxide init zsh)"
eval "$(atuin init zsh)" # Keep if you are using atuin
eval "$(direnv hook zsh)" # Keep if you are using direnv
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" # REMOVE IF NOT USING LINUXBREW: Remove this line if you are not using linuxbrew (Homebrew for Linux)
