#!/usr/bin/env bash
# Idempotent dotfiles symlinker. Reconciles the repo's committed config into
# your home dir as symlinks, so editing in-repo is live everywhere and
# `git status` shows drift. Backs up any pre-existing real file once.
#
# Secrets are NOT handled here — they live in ~/.config/secrets.env (gitignored),
# sourced by the linked ~/.zshrc.
#
# Usage:
#   ./link.sh            # apply (create/refresh symlinks)
#   ./link.sh --dry-run  # show what would change
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

# src (in repo)            -> dest (in $HOME)
LINKS=(
  "home/.zshrc:$HOME/.zshrc"
  "scripts:$HOME/.scripts"
  "config/git:$HOME/.config/git"
  "config/k9s:$HOME/.config/k9s"
)

link() {
  local src="$HERE/$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  ok    $dest"
    return
  fi
  if [ $DRY = 1 ]; then
    echo "  link  $dest -> $src$([ -e "$dest" ] && echo '  (backs up existing)')"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.pre-dotfiles.$(date +%s)"
    echo "  backed up existing $dest"
  fi
  ln -sfn "$src" "$dest"
  echo "  linked $dest -> $src"
}

echo "dotfiles link ($([ $DRY = 1 ] && echo DRY-RUN || echo APPLY))"
for pair in "${LINKS[@]}"; do link "${pair%%:*}" "${pair##*:}"; done

[ $DRY = 1 ] && exit 0
echo
echo "note: secrets live in ~/.config/secrets.env (gitignored), sourced by ~/.zshrc"
