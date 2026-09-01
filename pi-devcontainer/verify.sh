#!/usr/bin/env bash
# Smoke-test the pi devcontainer image: build, then check the load-bearing bits
# (pi/node/tooling present, egress logging records, provider seeds). Idempotent.
#
# Usage: ./verify.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-devcontainer:verify
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "== build =="
docker build -q -t "$IMG" "$HERE" >/dev/null && echo "  ok"

echo "== tooling =="
docker run --rm "$IMG" bash -lc 'node --version && pi --version | head -1 && git --version && gh --version | head -1' \
  | sed 's/^/  /'

echo "== egress logging + provider seed =="
docker run --rm --cap-add NET_ADMIN -v "$TMP:/workspace/.pi-egress" -e NVIDIA_INFERENCE_API_KEY=fake "$IMG" \
  bash -lc 'curl -s -o /dev/null -m 8 https://github.com; sleep 1; test -s /workspace/.pi-egress/egress.log && echo "  egress: recorded" || { echo "  egress: EMPTY"; exit 1; }; test -f ~/.pi/agent/models.json && echo "  provider: seeded" || { echo "  provider: MISSING"; exit 1; }'

echo "== allowlist extractor =="
"$HERE/egress-allowlist.sh" "$TMP/egress.log" | grep -q github.com && echo "  ok" || { echo "  FAILED"; exit 1; }

echo "ALL GREEN"
