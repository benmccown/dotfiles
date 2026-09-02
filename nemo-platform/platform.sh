#!/usr/bin/env bash
# dotfiles nemo-platform helper — idempotent lifecycle for the dedicated NeMo
# Platform instance that pi-brain dogfoods against as its model provider +
# telemetry sink. Lives out-of-tree (dotfiles) per the pi-brain shareability split:
# the running platform is a bespoke provider choice, not a pi-brain concept.
#
# Covers: clone -> bootstrap -> run -> health -> register inference provider ->
# smoke test, plus status/stop/logs/url. Every step is safe to re-run.
#
# Usage:
#   scripts/platform.sh up        # do everything: clone, bootstrap, start, register provider, smoke test
#   scripts/platform.sh clone     # shallow-clone the dedicated nemo-platform checkout
#   scripts/platform.sh bootstrap # make bootstrap-python (Python deps only)
#   scripts/platform.sh start     # start services in a tmux session (idempotent)
#   scripts/platform.sh wait      # block until /health/ready is 200
#   scripts/platform.sh provider  # register the nvidia-inference provider (idempotent)
#   scripts/platform.sh smoke     # chat-completion smoke test through the gateway
#   scripts/platform.sh studio    # build the Studio web UI assets (Intake/Insights UI at $BASE_URL)
#   scripts/platform.sh status    # health + provider + tmux status
#   scripts/platform.sh logs      # tail the platform log
#   scripts/platform.sh url       # print NMP_BASE_URL
#   scripts/platform.sh stop      # stop the tmux session (leaves data intact)
#   scripts/platform.sh reload    # alias for redeploy (pull latest main + restart, data intact)
#   scripts/platform.sh redeploy  # stop, git pull latest main, start again (data intact)
#
# Config (override via env):
#   PI_BRAIN_NMP_PORT       (default 49500)  bespoke port in the RFC 6335 dynamic range
#   PI_BRAIN_NMP_DATA_DIR   (default ~/.local/share/nemo-pi-brain)  isolated from dev instances
#   PI_BRAIN_NMP_DIR        (default <dotfiles>/.repos/nemo-platform)  the dedicated checkout (also a verify ground-truth source)
#   PI_BRAIN_NMP_SHALLOW_SINCE (default 1 month ago)  clone depth
#   PI_BRAIN_INFERENCE_KEY_ENV (default NVIDIA_INFERENCE_API_KEY)  env var holding the provider key
#   PI_BRAIN_INFERENCE_HOST_URL (default https://inference-api.nvidia.com/v1)
#   PI_BRAIN_WORKSPACE      (default default)
#   PI_BRAIN_PROVIDER       (default nvidia-inference)
#   PI_BRAIN_SMOKE_MODEL    (default default/aws-anthropic-bedrock-claude-sonnet-4-6)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # = dotfiles repo root (parent of nemo-platform/)
NMP_PORT="${PI_BRAIN_NMP_PORT:-49500}"
NMP_DATA_DIR="${PI_BRAIN_NMP_DATA_DIR:-$HOME/.local/share/nemo-pi-brain}"
NMP_DIR="${PI_BRAIN_NMP_DIR:-$REPO_DIR/.repos/nemo-platform}"
SHALLOW_SINCE="${PI_BRAIN_NMP_SHALLOW_SINCE:-$(date -v-1m +%Y-%m-%d 2>/dev/null || date -d '1 month ago' +%Y-%m-%d)}"
KEY_ENV="${PI_BRAIN_INFERENCE_KEY_ENV:-NVIDIA_INFERENCE_API_KEY}"
HOST_URL="${PI_BRAIN_INFERENCE_HOST_URL:-https://inference-api.nvidia.com/v1}"
WORKSPACE="${PI_BRAIN_WORKSPACE:-default}"
PROVIDER="${PI_BRAIN_PROVIDER:-nvidia-inference}"
SECRET_NAME="${PROVIDER}-key"
SMOKE_MODEL="${PI_BRAIN_SMOKE_MODEL:-default/aws-anthropic-bedrock-claude-sonnet-4-6}"
REPO_URL="git@github.com:NVIDIA-NeMo/nemo-platform.git"
TMUX_SESSION="pi-brain-nemo"
LOG_FILE="/tmp/pi-brain-nemo.log"
BASE_URL="http://localhost:${NMP_PORT}"

log()  { printf '\033[1;34m[pi-brain]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[pi-brain]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[pi-brain]\033[0m %s\n' "$*" >&2; exit 1; }

# Run a nemo CLI command inside the flox-activated checkout, with the right env.
nemo_cli() {
  ( cd "$NMP_DIR" && NMP_DATA_DIR="$NMP_DATA_DIR" NMP_BASE_URL="$BASE_URL" \
      flox -q activate --dir . -- uv run nemo "$@" )
}

health_code() {
  curl -s -m 3 -o /dev/null -w "%{http_code}" "$BASE_URL/health/ready" 2>/dev/null || echo "000"
}

cmd_clone() {
  if [ -d "$NMP_DIR/.git" ]; then
    log "checkout already present at $NMP_DIR (skipping clone)"
    return 0
  fi
  command -v git >/dev/null || die "git not found"
  log "shallow-cloning nemo-platform (since $SHALLOW_SINCE) -> $NMP_DIR"
  git clone --shallow-since="$SHALLOW_SINCE" "$REPO_URL" "$NMP_DIR"
}

cmd_bootstrap() {
  [ -d "$NMP_DIR" ] || die "no checkout; run: $0 clone"
  if [ -x "$NMP_DIR/.venv/bin/python" ] || [ -d "$NMP_DIR/.venv" ]; then
    log "venv present; running bootstrap-python to sync (idempotent)"
  else
    log "bootstrapping Python deps (first run builds native deps; several minutes)"
  fi
  command -v flox >/dev/null || die "flox not found — install from https://flox.dev/docs/install-flox/install"
  ( cd "$NMP_DIR" && make bootstrap-python )
}

cmd_start() {
  [ -d "$NMP_DIR/.venv" ] || die "not bootstrapped; run: $0 bootstrap"
  if [ "$(health_code)" = "200" ]; then
    log "platform already healthy at $BASE_URL (skipping start)"
    return 0
  fi
  if lsof -nP -iTCP:"$NMP_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    die "port $NMP_PORT is in use but /health/ready is not 200 — investigate (lsof -iTCP:$NMP_PORT)"
  fi
  command -v tmux >/dev/null || die "tmux not found"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  log "starting platform on $BASE_URL (data dir: $NMP_DATA_DIR, tmux: $TMUX_SESSION)"
  tmux new-session -d -s "$TMUX_SESSION" -c "$NMP_DIR" \
    "export NMP_DATA_DIR='$NMP_DATA_DIR' NMP_BASE_URL='$BASE_URL'; flox -q activate --dir . -- uv run nemo services run --port $NMP_PORT > '$LOG_FILE' 2>&1"
  cmd_wait
}

cmd_wait() {
  log "waiting for $BASE_URL/health/ready (first run pulls ClickHouse; can take ~1-2 min)"
  for i in $(seq 1 60); do
    code="$(health_code)"
    if [ "$code" = "200" ]; then log "platform ready (after ~$((i*5))s)"; return 0; fi
    # surface obvious fatal exit early
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null && [ -f "$LOG_FILE" ]; then
      warn "tmux session gone; last log lines:"; tail -15 "$LOG_FILE" >&2; die "platform failed to start"
    fi
    sleep 5
  done
  warn "still not ready; last log lines:"; tail -20 "$LOG_FILE" >&2
  die "timed out waiting for platform"
}

cmd_provider() {
  [ "$(health_code)" = "200" ] || die "platform not healthy; run: $0 start"
  local key="${!KEY_ENV:-}"
  [ -n "$key" ] || die "\$$KEY_ENV is empty — export your inference API key first"

  # secret (idempotent via --exist-ok if supported, else tolerate 409)
  if nemo_cli secrets get "$SECRET_NAME" --workspace "$WORKSPACE" >/dev/null 2>&1; then
    log "secret '$SECRET_NAME' already exists (skipping)"
  else
    log "creating secret '$SECRET_NAME' from \$$KEY_ENV"
    printf '%s' "$key" | nemo_cli secrets create "$SECRET_NAME" --from-file - --workspace "$WORKSPACE" >/dev/null
  fi

  # provider (idempotent: create with --exist-ok; skip if already present)
  if nemo_cli inference providers get "$PROVIDER" --workspace "$WORKSPACE" >/dev/null 2>&1; then
    log "provider '$PROVIDER' already exists (skipping create)"
  else
    log "registering provider '$PROVIDER' -> $HOST_URL"
    nemo_cli inference providers create "$PROVIDER" \
      --workspace "$WORKSPACE" --host-url "$HOST_URL" \
      --api-key-secret-name "$SECRET_NAME" --exist-ok >/dev/null
  fi
  nemo_cli wait inference provider "$PROVIDER" --workspace "$WORKSPACE" || true
  local n
  n="$(nemo_cli inference providers get "$PROVIDER" --workspace "$WORKSPACE" --output-format json 2>/dev/null \
      | python3 -c 'import sys,json;d=json.load(sys.stdin);print(len(d.get("served_models") or []))' 2>/dev/null || echo '?')"
  log "provider '$PROVIDER' ready; $n served models discovered"
}

cmd_smoke() {
  [ "$(health_code)" = "200" ] || die "platform not healthy; run: $0 start"
  log "smoke-testing chat completion via gateway (model: $SMOKE_MODEL)"
  local out
  out="$(curl -s -X POST \
    "$BASE_URL/apis/inference-gateway/v2/workspaces/$WORKSPACE/openai/-/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$SMOKE_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: pi-brain online\"}],\"max_tokens\":32}" 2>/dev/null)"
  echo "$out" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("[pi-brain] gateway reply:",repr(d["choices"][0]["message"]["content"]))' \
    || die "smoke test failed; raw: $out"
}

cmd_status() {
  echo "base url:   $BASE_URL"
  echo "health:     $(health_code)"
  echo "data dir:   $NMP_DATA_DIR"
  echo "checkout:   $NMP_DIR $( [ -d "$NMP_DIR/.git" ] && echo '(present)' || echo '(missing)')"
  echo -n "tmux:       "; tmux has-session -t "$TMUX_SESSION" 2>/dev/null && echo "$TMUX_SESSION (running)" || echo "(not running)"
  if [ "$(health_code)" = "200" ]; then
    echo -n "provider:   "
    nemo_cli inference providers get "$PROVIDER" --workspace "$WORKSPACE" --output-format json 2>/dev/null \
      | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("status"),"-",len(d.get("served_models") or []),"models")' 2>/dev/null \
      || echo "(not registered)"
  fi
}

cmd_logs() { tail -n "${2:-40}" "$LOG_FILE" 2>/dev/null || die "no log at $LOG_FILE"; }
cmd_url()  { echo "$BASE_URL"; }

# Build the Studio web UI assets (pnpm install + vite build) so the running
# platform serves the UI (incl. Intake/Insights) at $BASE_URL. Idempotent: skips
# if a dist is already present unless FORCE=1. The running server picks up built
# assets without a restart.
cmd_studio() {
  [ -d "$NMP_DIR" ] || die "no checkout; run: $0 up"
  command -v flox >/dev/null || die "flox not found"
  local dist="$NMP_DIR/web/packages/studio/dist"
  if [ -d "$dist" ] && [ "${FORCE:-0}" != "1" ]; then
    log "Studio assets already built ($dist). Set FORCE=1 to rebuild."
  else
    log "building Studio web assets (pnpm install + vite build; several minutes)"
    ( cd "$NMP_DIR" && make bootstrap-studio )
  fi
  if [ "$(health_code)" = "200" ]; then
    log "Studio should now be served at $BASE_URL (open it in a browser)"
  else
    log "assets built; start the platform with '$0 start' then open $BASE_URL"
  fi
}
cmd_stop() {
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null && log "stopped $TMUX_SESSION (data preserved at $NMP_DATA_DIR)" || log "not running"
}

# Stop -> pull latest main -> start again. Data (NMP_DATA_DIR) is preserved.
cmd_redeploy() {
  [ -d "$NMP_DIR/.git" ] || die "no checkout; run: $0 up"
  cmd_stop
  log "pulling latest main in $NMP_DIR"
  ( cd "$NMP_DIR" && git checkout main && git pull --ff-only )
  cmd_start
  log "redeploy done — running latest main at $BASE_URL"
}

cmd_up() {
  cmd_clone
  cmd_bootstrap
  cmd_start
  cmd_provider
  cmd_smoke
  log "done — pi-brain platform is up. NMP_BASE_URL=$BASE_URL"
  log "point Pi at it via ~/.pi/agent/models.json (provider 'nemo', baseUrl .../workspaces/$WORKSPACE/openai/-/v1)"
}

case "${1:-up}" in
  up) cmd_up ;;
  clone) cmd_clone ;;
  bootstrap) cmd_bootstrap ;;
  start) cmd_start ;;
  wait) cmd_wait ;;
  provider) cmd_provider ;;
  smoke) cmd_smoke ;;
  studio) cmd_studio ;;
  status) cmd_status ;;
  logs) cmd_logs "$@" ;;
  url) cmd_url ;;
  stop) cmd_stop ;;
  reload|redeploy) cmd_redeploy ;;
  *) die "unknown command: $1 (see header for usage)" ;;
esac
