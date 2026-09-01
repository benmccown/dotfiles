# Uncomment to enable startup time profiling
#zmodload zsh/zprof

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH=$PATH:/opt/homebrew/opt/mysql-client/bin:/Users/$USER/.scripts:/Users/$USER/.cargo/bin:/Users/$USER/.local/bin:/opt/homebrew/bin

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export LISTMAX=-1

#k9s
export K9SCONFIG=$HOME/.config/k9s
export EDITOR=nvim

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#
# List taken from: https://gist.github.com/n1snt/454b879b8f0b7995740ae04c5fb5b7df
plugins=(git fast-syntax-highlighting zsh-fzf-history-search fzf-tab kubectl)
#plugins=(git zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete zsh-fzf-history-search fzf-tab kubectl)

#plugins=(git)

# Setup auto complete for homebrew
fpath=($(brew --prefix)/share/zsh/site-functions /Users/$USER/.scripts/.fpath /opt/homebrew/share/zsh/site-functions $fpath)

source $ZSH/oh-my-zsh.sh

# User configuration


# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# alias lr="eza -alhrt"
alias lr="eza --icons -alh -snew"
alias ll="eza --icons -alh"
alias lsn="ls"
alias ls="eza --icons -lh"
alias k="kubectl"
alias ks="switch"
alias kn="k9s"
alias vim="nvim"
alias tf="terraform"
alias kgpu="kubectl view-allocations -r nvidia.com/gpu"

# Git worktree helper functions
wtadd() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wtadd <branch-name>"
        return 1
    fi
    git worktree add "../nmp-worktree/$branch_name" -b "$branch_name/bmccown" origin/main
    sed -i '' '/bare = true/d' .git/config
}

wtrm() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wtrm <branch-name>"
        return 1
    fi
    git worktree remove "../nmp-worktree/$branch_name" --force
}

# export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/kubeconfig-nemollm.yaml"
export KUBECONFIG="${HOME}/teleport-kubeconfig.yaml"
export NEMO_DEV_CLUSTER="nv-prd-nemo.teleport.sh-nemo-dev-blue"
export GITLAB_HOST=gitlab-master.nvidia.com
export LC_ALL=en_US.UTF-8

# Secrets (API keys/tokens) live outside this file.
[ -f ~/.config/secrets.env ] && source ~/.config/secrets.env

# pi-brain: capture tool args/results + assistant text on telemetry spans
# (writes prompts/tool-IO to the local NeMo Intake ClickHouse; debug legibility)
export PI_BRAIN_TELEMETRY_PAYLOADS=on
# pi-brain: opt-in allow-list of dirs a `file`-sourced memory may be re-read from
# during clean.verify. The dedicated nemo-platform reference checkout lives here.
export PI_BRAIN_VERIFY_DIRS="$HOME/Code/pi-brain/.monitored-projects"
# pi-brain: run the auto-capture judge every N agent turns (matches the code default;
# raise to reduce capture frequency/noise, set 1 to judge every turn).
export PI_BRAIN_CAPTURE_EVERY_N_RUNS=3

setopt HIST_IGNORE_SPACE

# zsh-autocomplete
#source $ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# complete -o nospace -C /opt/homebrew/Cellar/tfenv/3.0.0/versions/1.1.8/terraform terraform
# Created by `pipx` on 2023-06-30 20:39:15

# kube switcher
source <(switcher init zsh)
source <(compdef _switcher switch)

# kubectl autocomplete
source <(kubectl completion zsh)
source <(k9s completion zsh)

# zsh-autosuggestions
#bindkey '\t' menu-complete "$terminfo[kcbt]" reverse-menu-complete
# zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
# zstyle ':completion:*' group-name ''
# do not try to complete lines with more than N chars
#export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
# non-blocking suggestions
#export ZSH_AUTOSUGGEST_USE_ASYNC=1

alias gh-docker-login="echo $GITHUB_TOKEN | docker login ghcr.io -u benmccown --password-stdin"

# azure cli
autoload bashcompinit && bashcompinit
source $(brew --prefix)/etc/bash_completion.d/az

eval "$(direnv hook zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"
export PATH=$PATH:$HOME/.local/bin/
# gnutar
export HOMEBREW_PREFIX="$(brew --prefix)"
export PATH="$HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnubin:$PATH"
# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"


# Uncomment to enable startup time profiling
#zprof

fpath+=~/.zfunc; autoload -Uz compinit; compinit

# opencode
export PATH=/Users/bmccown/.opencode/bin:$PATH

# pi-brain <-> cmux markdown-viewer integration (open notes/plans/worklog items in a live cmux panel)
export PI_BRAIN_CMUX=1
