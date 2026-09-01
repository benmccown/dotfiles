#!/usr/bin/env bash
# Devcontainer entrypoint. Runs as ROOT: sets up egress logging (allow-all, but
# RECORD every host reached via dnsmasq query logging), then drops to `dev` to
# exec the command. Your real pi config, MCP config, extensions, and Code dirs
# are MOUNTED in at their host paths — this script does not copy or clobber them.
#
# Egress logging: dnsmasq becomes the container resolver and logs every DNS
# query (all egress starts with one). Allow-all upstream — record, don't block.
# The log is the seed for a future allowlist (see egress-allowlist.sh).
set -euo pipefail

DEV_USER=dev
DEV_HOME=/Users/bmccown
LOG_DIR="${PI_EGRESS_LOG_DIR:-$DEV_HOME/Code/.pi-egress}"
EGRESS_LOG="$LOG_DIR/egress.log"

# ---- privileged setup (root) ----
if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$LOG_DIR"; chown "$DEV_USER" "$LOG_DIR" 2>/dev/null || true
  # Ensure ~/.pi exists and is dev-owned (only ~/.pi/agent is a mount; the parent
  # is created root-owned otherwise, blocking e.g. the Slack bridge config write).
  mkdir -p "$DEV_HOME/.pi"; chown "$DEV_USER" "$DEV_HOME/.pi" 2>/dev/null || true
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
  exec setpriv --reuid="$DEV_USER" --regid="$DEV_USER" --init-groups \
       env HOME="$DEV_HOME" PI_EGRESS_LOG_DIR="$LOG_DIR" "$0" "$@"
fi

# ---- unprivileged (dev) ----
# gh auth uses $GITHUB_TOKEN from the env automatically. Your ~/.pi/agent (config,
# installed packages, auth) and ~/.config/mcp are MOUNTED — nothing to seed.
# Provider only seeded as a fallback if no mounted models.json exists.
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
  echo "[pi-entrypoint] seeded fallback nvidia-direct provider (no mounted models.json)"
fi

exec "$@"
