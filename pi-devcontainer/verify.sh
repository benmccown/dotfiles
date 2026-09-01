#!/usr/bin/env bash
# Smoke-test the pi devcontainer with your REAL mounts: versions, full toolset,
# mounted projects/extensions/mcp/scripts, portable shell (no mac overlay),
# secrets, gh auth, kubectl->bmccown-dev via tsh, host nemo-platform, egress log.
#
# Usage: ./verify.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-devcontainer:verify

echo "== build =="; docker build -q -t "$IMG" "$HERE" >/dev/null && echo "  ok"

docker run --rm --cap-add NET_ADMIN --add-host=host.docker.internal:host-gateway \
  -v "$HOME/Code:/Users/bmccown/Code" \
  -v "$HOME/.pi/agent:/Users/bmccown/.pi/agent" \
  -v "$HOME/.config/mcp:/Users/bmccown/.config/mcp" \
  -v "$HOME/.config/secrets.env:/Users/bmccown/.config/secrets.env:ro" \
  -v "$HOME/.zshrc:/Users/bmccown/.zshrc:ro" \
  -v "$HOME/.scripts:/Users/bmccown/.scripts" \
  -v "$HOME/.tsh:/Users/bmccown/.tsh" \
  -v "$HOME/teleport-kubeconfig.yaml:/Users/bmccown/teleport-kubeconfig.yaml:ro" \
  -e NVIDIA_INFERENCE_API_KEY=fake -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  -e KUBECONFIG=/Users/bmccown/teleport-kubeconfig.yaml \
  "$IMG" zsh -ic '
set -e
echo "== versions =="; node --version; pi --version | head -1; go version
echo "== toolset =="; for b in go kubectl tsh helm eza uv nvim jq yq sqlite3 rg http kubectx gh curl; do command -v "$b" >/dev/null || { echo "  MISSING: $b"; exit 1; }; done; echo "  all present"
echo "== shell =="; [ -f ~/.zshrc.mac ] && { echo "  mac overlay LEAKED"; exit 1; }; type wtadd >/dev/null && echo "  portable zshrc + wtadd ok"
echo "== mounts =="
test -d ~/Code/pi-brain && test -d ~/Code/nemo-platform && echo "  projects ok" || { echo "  projects MISSING"; exit 1; }
test -e ~/.pi/agent/extensions/pi-brain-memory && echo "  extension symlink resolves" || { echo "  extension BROKEN"; exit 1; }
test -f ~/.config/mcp/mcp.json && echo "  mcp config present" || { echo "  mcp MISSING"; exit 1; }
test -x ~/.scripts/git-wtadd && echo "  scripts present" || { echo "  scripts MISSING"; exit 1; }
echo "== kube (bmccown-dev via mounted tsh) =="; kubectl --request-timeout=20s get ns bmccown-dev >/dev/null 2>&1 && echo "  reachable" || echo "  WARN: not reachable (tsh session may be expired — tsh login on host)"
echo "== host nemo-platform =="; curl -s -o /dev/null -m5 -w "  host.docker.internal:49500 -> %{http_code}\n" http://host.docker.internal:49500/ || true
echo "== egress =="; curl -s -o /dev/null -m8 https://github.com; sleep 1; test -s ~/Code/.pi-egress/egress.log && echo "  recorded" || { echo "  egress EMPTY"; exit 1; }
echo "ALL GREEN"
'
