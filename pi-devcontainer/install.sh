#!/usr/bin/env bash
# Drop the pi devcontainer definition into a project (idempotent).
# Copies Dockerfile + devcontainer.json + entrypoint into <project>/.devcontainer,
# so you can "Reopen in Container" (VS Code) or `devcontainer up` there.
# Re-run to refresh after editing the canonical copy here.
#
# Usage:
#   ./install.sh [project-dir]      # default: current dir
#   ./install.sh --dry-run [dir]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; [ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
DEST="${1:-$PWD}/.devcontainer"

FILES="Dockerfile devcontainer.json entrypoint.sh"
echo "pi-devcontainer install ($([ $DRY = 1 ] && echo DRY-RUN || echo APPLY)) -> $DEST"
for f in $FILES; do
  if [ $DRY = 1 ]; then
    echo "  would copy $f"
  else
    mkdir -p "$DEST"
    cp "$HERE/$f" "$DEST/$f"
    echo "  copied $f"
  fi
done
[ $DRY = 1 ] && exit 0

echo
echo "next:"
echo "  - ensure NVIDIA_INFERENCE_API_KEY is set in your host shell"
echo "  - VS Code: 'Dev Containers: Reopen in Container', or: devcontainer up --workspace-folder ."
echo "  - inside: run mcp/sync-mcp.sh then /mcp-auth to wire MaaS MCPs"
