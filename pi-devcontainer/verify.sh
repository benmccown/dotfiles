#!/usr/bin/env bash
# Smoke-test the pi devcontainer: build, then check the load-bearing bits with
# your REAL mounts (versions, debugging tools, mounted projects/extensions/mcp,
# gh auth, egress logging). Idempotent, uses a throwaway container.
#
# Usage: ./verify.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-devcontainer:verify

echo "== build =="; docker build -q -t "$IMG" "$HERE" >/dev/null && echo "  ok"

docker run --rm --cap-add NET_ADMIN \
  -v "$HOME/Code:/Users/bmccown/Code" \
  -v "$HOME/.pi/agent:/Users/bmccown/.pi/agent" \
  -v "$HOME/.config/mcp:/Users/bmccown/.config/mcp" \
  -e NVIDIA_INFERENCE_API_KEY=fake -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  "$IMG" bash -lc '
set -e
echo "== versions =="; node --version; pi --version | head -1
echo "== tools =="; for b in jq yq sqlite3 rg fd bat python3 pandoc gh curl; do command -v "$b" >/dev/null || { echo "  MISSING: $b"; exit 1; }; done; echo "  all present"
echo "== mounts =="
test -d ~/Code/pi-brain && test -d ~/Code/nemo-platform && echo "  projects ok" || { echo "  projects MISSING"; exit 1; }
test -e ~/.pi/agent/extensions/pi-brain-memory && echo "  extension symlink resolves" || { echo "  extension BROKEN"; exit 1; }
test -f ~/.config/mcp/mcp.json && echo "  mcp config present" || { echo "  mcp MISSING"; exit 1; }
echo "== egress =="; curl -s -o /dev/null -m 8 https://github.com; sleep 1
test -s ~/Code/.pi-egress/egress.log && echo "  recorded" || { echo "  egress EMPTY"; exit 1; }
echo "ALL GREEN"
'
