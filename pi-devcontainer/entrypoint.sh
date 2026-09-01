#!/usr/bin/env bash
# Devcontainer entrypoint. Runs as ROOT: sets up egress logging (allow-all, but
# RECORD every host reached via dnsmasq query logging), then drops to `dev` to
# seed pi config and exec the command.
#
# Egress logging: dnsmasq becomes the container resolver and logs every DNS
# query (all egress starts with one) to the egress log. Allow-all upstream — we
# record, we don't block. After a few months the log IS your allowlist seed
# (see egress-allowlist.sh). No TLS MITM, no proxy.
set -euo pipefail

DEV_USER=dev
DEV_HOME=/home/dev
LOG_DIR="${PI_EGRESS_LOG_DIR:-/workspace/.pi-egress}"
EGRESS_LOG="$LOG_DIR/egress.log"

# ---- privileged setup (root) ----
if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$LOG_DIR"; chown "$DEV_USER" "$LOG_DIR" 2>/dev/null || true
  UPSTREAM="$(grep -m1 '^nameserver' /etc/resolv.conf | awk '{print $2}' || true)"
  if command -v dnsmasq >/dev/null 2>&1 && [ -n "${UPSTREAM:-}" ] && [ "$UPSTREAM" != "127.0.0.1" ]; then
    dnsmasq --log-queries --log-facility="$EGRESS_LOG" \
            --server="$UPSTREAM" --listen-address=127.0.0.1 --bind-interfaces 2>/dev/null || true
    if echo "nameserver 127.0.0.1" > /etc/resolv.conf 2>/dev/null; then
      echo "[pi-entrypoint] egress logging -> $EGRESS_LOG (allow-all, recording)"
    else
      echo "[pi-entrypoint] WARN: could not rewrite resolv.conf; egress not logged" >&2
    fi
  fi
  # drop to dev for the rest
  exec setpriv --reuid="$DEV_USER" --regid="$DEV_USER" --init-groups \
       env HOME="$DEV_HOME" PI_EGRESS_LOG_DIR="$LOG_DIR" "$0" "$@"
fi

# ---- unprivileged (dev) ----
# Seed pi provider -> the real NVIDIA endpoint. Key from env, never in the image.
KEY="${PI_INFERENCE_KEY:-${NVIDIA_INFERENCE_API_KEY:-}}"
PI_DIR="$HOME/.pi/agent"
if [ -n "$KEY" ] && [ ! -f "$PI_DIR/models.json" ]; then
  mkdir -p "$PI_DIR"
  cat > "$PI_DIR/models.json" <<JSON
{
  "providers": {
    "nvidia-direct": {
      "baseUrl": "https://inference-api.nvidia.com/v1",
      "api": "openai-completions",
      "authHeader": true
    }
  }
}
JSON
  echo "[pi-entrypoint] seeded nvidia-direct provider (inference-api.nvidia.com)"
fi

exec "$@"
