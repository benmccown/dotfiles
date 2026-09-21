#!/usr/bin/env bash
# Idempotent provisioner for pi-brain's shareable extensions.
#
# pi-brain ships extensions (extensions/scratch-space, extensions/memory, ...)
# that are PROJECT extensions but must be loaded GLOBALLY — pi discovers global
# extensions as dirs under ~/.pi/agent/extensions/. So each pi-brain extension
# dir is symlinked into that global dir. Without this, an extension only loads
# when pi runs *inside* the pi-brain repo (its package.json pi.extensions),
# NOT from other cwds like ~/Code/nemo-platform — which is exactly how the
# scratch-space path injection silently went missing.
#
# This lives in dotfiles (machine setup), not pi-brain, because it's a
# cross-repo, per-machine linking step — pi-brain owns the extension code, the
# machine owns where it's globally loaded from. Safe to re-run.
#
# Usage:
#   ./link-extensions.sh            # apply
#   ./link-extensions.sh --dry-run  # show what would change
set -euo pipefail

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

PI_BRAIN="${PI_BRAIN_DIR:-$HOME/Code/pi-brain}"
DEST_DIR="$HOME/.pi/agent/extensions"

# global-symlink-name : pi-brain-relative-extension-dir
#   hello-world is a demo extension; kept to match current provisioning.
LINKS=(
  "pi-brain-hello:extensions/hello-world"
  "pi-brain-memory:extensions/memory"
  "pi-brain-scratch:extensions/scratch-space"
)

if [ ! -d "$PI_BRAIN" ]; then
  echo "pi-brain checkout not found at $PI_BRAIN (set PI_BRAIN_DIR to override)" >&2
  exit 1
fi

link() {
  local name="$1" rel="$2"
  local src="$PI_BRAIN/$rel" dest="$DEST_DIR/$name"
  if [ ! -d "$src" ]; then
    echo "  MISSING src $src (skipping $name)" >&2
    return
  fi
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  ok    $dest"
    return
  fi
  if [ $DRY = 1 ]; then
    echo "  link  $dest -> $src$([ -e "$dest" ] && echo '  (replaces existing)')"
    return
  fi
  mkdir -p "$DEST_DIR"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.pre-dotfiles.$(date +%s)"
    echo "  backed up existing $dest"
  fi
  ln -sfn "$src" "$dest"
  echo "  linked $dest -> $src"
}

echo "pi-brain extension link ($([ $DRY = 1 ] && echo DRY-RUN || echo APPLY))"
echo "  pi-brain: $PI_BRAIN"
for pair in "${LINKS[@]}"; do link "${pair%%:*}" "${pair##*:}"; done
