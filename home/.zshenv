[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"


# Secrets (API keys/tokens) — sourced here (not just .zshrc) so NON-interactive
# login shells (e.g. `zsh -lc`, as pi-dev uses) get them too.
[ -f ~/.config/secrets.env ] && source ~/.config/secrets.env

# Inside the devcontainer only: the host ~/.ssh/config points at the 1Password SSH
# agent, whose socket doesn't exist in the container. Force git's SSH to use the
# mounted on-disk key directly (bypassing that agent) so git push over SSH works.
if [ -f /.dockerenv ]; then
  export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o IdentityAgent=none"
fi
