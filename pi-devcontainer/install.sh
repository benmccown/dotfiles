#!/usr/bin/env bash
# Bring up the pi devcontainer (idempotent). WORKSPACE-WIDE container: mounts your
# whole ~/Code (projects + *.worktrees), pi config/extensions/auth, MCP config,
# shell config, ~/.scripts, Teleport session + kubeconfig, all at identical host
# paths so symlinks, the tsh kubeconfig exec-plugin, and MCP all resolve. Open it
# ONCE, not per-project.
#
# Usage:
#   ./install.sh          # up (build if needed) + attach hint
#   ./install.sh build    # (re)build the image
#   ./install.sh up       # create + start the container (build if image missing)
#   ./install.sh down      # stop the container (keeps it; `up` restarts fast)
#   ./install.sh rm       # remove the container (forced; next `up` recreates clean)
#   ./install.sh restart  # rm + up (recreate container, no rebuild)
#   ./install.sh reload   # build + rm + up (rebuild image, then recreate)
#   ./install.sh --exec   # open a zsh shell in the running container
#   ./install.sh --vscode # write ~/Code/.devcontainer for VS Code "Reopen in Container"
#
# Rebuild + relaunch:  ./install.sh reload   (or: rm && build && up)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-devcontainer
NAME=pi-agent

: "${NVIDIA_INFERENCE_API_KEY:?set NVIDIA_INFERENCE_API_KEY in your host shell}"
[ -n "${GITHUB_TOKEN:-}" ] || echo "warn: GITHUB_TOKEN not set — gh will be unauthenticated" >&2

# host:container mounts (identical paths so symlinks/exec-plugin resolve)
mounts=(
  "$HOME/Code:/Users/bmccown/Code"
  "$HOME/.pi/agent:/Users/bmccown/.pi/agent"
  "$HOME/.config/mcp:/Users/bmccown/.config/mcp"
  "$HOME/.config/secrets.env:/Users/bmccown/.config/secrets.env:ro"
  "$HOME/.zshrc:/Users/bmccown/.zshrc:ro"
  "$HOME/.zshenv:/Users/bmccown/.zshenv:ro"
  "$HOME/.scripts:/Users/bmccown/.scripts"
  "$HOME/.config/git:/Users/bmccown/.config/git:ro"
  "$HOME/.config/k9s:/Users/bmccown/.config/k9s"
  "$HOME/.tsh:/Users/bmccown/.tsh"
  "$HOME/.ssh:/Users/bmccown/.ssh:ro"
  "$HOME/teleport-kubeconfig.yaml:/Users/bmccown/teleport-kubeconfig.yaml:ro"
)

case "${1:-up}" in
  --exec) exec docker exec -it "$NAME" zsh -l ;;
  build|--build) docker build -t "$IMG" "$HERE" ;;
  restart) "$0" rm; exec "$0" up ;;                       # recreate container, no rebuild
  reload)  "$0" build && "$0" rm; exec "$0" up ;;          # rebuild image, then recreate
  down|--down) docker stop "$NAME" >/dev/null 2>&1 && echo "stopped $NAME" || echo "$NAME not running" ;;
  rm|--rm) docker rm -f "$NAME" >/dev/null 2>&1 && echo "removed $NAME" || echo "$NAME does not exist" ;;
  --vscode)
    mkdir -p "$HOME/Code/.devcontainer"
    cp "$HERE/Dockerfile" "$HERE/devcontainer.json" "$HERE/entrypoint.sh" "$HOME/Code/.devcontainer/"
    echo "wrote ~/Code/.devcontainer — open ~/Code in VS Code -> Reopen in Container" ;;
  up|--up)
    docker image inspect "$IMG" >/dev/null 2>&1 || docker build -t "$IMG" "$HERE"
    if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
      echo "$NAME already running"
    else
      # Remove any stopped container first — `docker start` on a killed one
      # trips a stale bind-mount 'file exists' error. Recreate clean instead.
      docker rm -f "$NAME" >/dev/null 2>&1 || true
      args=(-d --name "$NAME" --cap-add NET_ADMIN --add-host=host.docker.internal:host-gateway)
      for m in "${mounts[@]}"; do args+=(-v "$m"); done
      # Container-PRIVATE node_modules. ~/.pi/agent is shared with the Mac, but ALL
      # native npm bindings live under npm/node_modules (@napi-rs/keyring, ast-grep,
      # sharp, matrix-crypto, pi-tui prebuilds...). A Linux-container `npm install`
      # would overwrite the Mac's darwin bindings -> keychain unreachable -> every
      # MCP shows "credential store locked". This named volume layers a separate
      # node_modules over the shared mount so host & container each keep their own.
      # (Populated on first start by the entrypoint if empty.)
      args+=(-v pi-agent-npm-modules:/Users/bmccown/.pi/agent/npm/node_modules)
      args+=(-e NVIDIA_INFERENCE_API_KEY -e GITHUB_TOKEN
             -e GITLAB_HOST=gitlab-master.nvidia.com
             -e KUBECONFIG=/Users/bmccown/teleport-kubeconfig.yaml)
      docker run "${args[@]}" "$IMG" >/dev/null && echo "created $NAME"
    fi
    echo
    echo "attach:  docker exec -it $NAME zsh -l     (then: cd ~/Code/<proj> && pi)"
    echo "VS Code: Dev Containers: Attach to Running Container -> $NAME"
    echo "note: local nemo-platform is at host.docker.internal:49500 (not localhost) inside the container"
    ;;
  *) echo "usage: $0 [build|up|down|rm|restart|reload|--exec|--vscode]" >&2; exit 2 ;;
esac
