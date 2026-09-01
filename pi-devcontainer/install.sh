#!/usr/bin/env bash
# Bring up the pi devcontainer (idempotent). This is a WORKSPACE-WIDE container:
# it mounts your whole ~/Code (all projects + *.worktrees), ~/.pi/agent (config,
# installed pi packages, auth), and ~/.config/mcp at their identical host paths,
# so symlinked extensions, worktrees, and MCP config resolve unchanged. You open
# it ONCE, not per-project.
#
# Usage:
#   ./install.sh                 # devcontainer up (build if needed) + attach hint
#   ./install.sh --build         # force rebuild the image
#   ./install.sh --exec          # open a shell in the running container
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-devcontainer
NAME=pi-agent

# Preflight: required host env.
: "${NVIDIA_INFERENCE_API_KEY:?set NVIDIA_INFERENCE_API_KEY in your host shell}"
[ -n "${GITHUB_TOKEN:-}" ] || echo "warn: GITHUB_TOKEN not set — gh will be unauthenticated" >&2

case "${1:-up}" in
  --exec) exec docker exec -it "$NAME" bash -l ;;
  --build) docker build -t "$IMG" "$HERE" ;;
  --vscode)
    # Place devcontainer.json at ~/Code/.devcontainer for VS Code "Reopen in
    # Container" on the whole ~/Code workspace.
    mkdir -p "$HOME/Code/.devcontainer"
    cp "$HERE/Dockerfile" "$HERE/devcontainer.json" "$HERE/entrypoint.sh" "$HOME/Code/.devcontainer/"
    echo "wrote ~/Code/.devcontainer — open ~/Code in VS Code -> Reopen in Container" ;;
  up|--up)
    docker image inspect "$IMG" >/dev/null 2>&1 || docker build -t "$IMG" "$HERE"
    if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
      docker start "$NAME" >/dev/null && echo "started existing $NAME"
    else
      docker run -d --name "$NAME" --cap-add NET_ADMIN \
        -v "$HOME/Code:/Users/bmccown/Code" \
        -v "$HOME/.pi/agent:/Users/bmccown/.pi/agent" \
        -v "$HOME/.config/mcp:/Users/bmccown/.config/mcp" \
        -v "$HOME/.gitconfig:/Users/bmccown/.gitconfig:ro" \
        -e NVIDIA_INFERENCE_API_KEY -e GITHUB_TOKEN \
        -e GITLAB_HOST=gitlab-master.nvidia.com \
        "$IMG" >/dev/null && echo "created $NAME"
    fi
    echo
    echo "attach:  docker exec -it $NAME bash -l    (then: cd ~/Code/<proj> && pi)"
    echo "VS Code: Dev Containers: Attach to Running Container -> $NAME"
    ;;
  *) echo "usage: $0 [up|--build|--exec]" >&2; exit 2 ;;
esac
