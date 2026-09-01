# ~/.zshrc — PORTABLE base (host + pi devcontainer both use this).
# macOS-only bits (oh-my-zsh, brew, switcher, nvm, completions) live in
# ~/.zshrc.mac, sourced at the end only when present (i.e. on the Mac).

# --- PATH: personal bins first ---
export PATH="$HOME/.scripts:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# --- editor / locale / misc ---
export EDITOR=nvim
export LISTMAX=-1
# Prefer a UTF-8 locale that exists everywhere; the Mac overlay upgrades this.
export LC_ALL=C.UTF-8

# --- kube / cluster ---
export KUBECONFIG="${HOME}/teleport-kubeconfig.yaml"
export K9SCONFIG="$HOME/.config/k9s"
export NEMO_DEV_CLUSTER="nv-prd-nemo.teleport.sh-nemo-dev-blue"
export GITLAB_HOST=gitlab-master.nvidia.com

# --- secrets (API keys/tokens) live outside this file ---
[ -f ~/.config/secrets.env ] && source ~/.config/secrets.env

# --- pi-brain flags ---
export PI_BRAIN_TELEMETRY_PAYLOADS=on
export PI_BRAIN_VERIFY_DIRS="$HOME/Code/pi-brain/.monitored-projects"
export PI_BRAIN_CAPTURE_EVERY_N_RUNS=3
export PI_BRAIN_CMUX=1

# --- aliases (binaries present on both host + container) ---
alias lr="eza --icons -alh -snew"
alias ll="eza --icons -alh"
alias ls="eza --icons -lh"
alias lsn="command ls"
alias k="kubectl"
alias ks="switch"
alias kn="k9s"
alias vim="nvim"
alias tf="terraform"
alias kgpu="kubectl view-allocations -r nvidia.com/gpu"
alias gh-docker-login="echo \$GITHUB_TOKEN | docker login ghcr.io -u benmccown --password-stdin"

# --- git worktree helpers ---
wtadd() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wtadd <branch-name>"
        return 1
    fi
    git worktree add "../nmp-worktree/$branch_name" -b "$branch_name/bmccown" origin/main
    # portable: edit git config with git itself, not OS-specific `sed -i`
    git config --unset core.bare 2>/dev/null || true
}

wtrm() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wtrm <branch-name>"
        return 1
    fi
    git worktree remove "../nmp-worktree/$branch_name" --force
}

setopt HIST_IGNORE_SPACE

# --- kubectl completion (portable; present on both) ---
command -v kubectl >/dev/null && source <(kubectl completion zsh) 2>/dev/null

# --- macOS-only overlay (oh-my-zsh, brew, switcher, nvm, …); Mac only ---
[ -f ~/.zshrc.mac ] && source ~/.zshrc.mac
