#!/usr/bin/env bash
# Build + run the dedicated pi-slack bridge container (long-running, isolated).
#
#   ./run.sh build     # build the image
#   ./run.sh up        # (build if needed) start the bridge detached, stays connected
#   ./run.sh logs      # follow the bridge logs
#   ./run.sh stop      # stop + remove the container
#   ./run.sh restart   # stop then up
#
# Tokens + owner id are read from your host env (source ~/.config/secrets.env
# first). The agent talks to your LOCAL nemo-platform gateway via
# host.docker.internal:49500. Tokens are passed in at runtime, never baked in.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=pi-slack
NAME=pi-slack

: "${PI_SLACK_BOT_TOKEN:?set PI_SLACK_BOT_TOKEN (source ~/.config/secrets.env)}"
: "${PI_SLACK_APP_TOKEN:?set PI_SLACK_APP_TOKEN}"
: "${PI_SLACK_OWNER_ID:?set PI_SLACK_OWNER_ID}"

case "${1:-up}" in
  build) docker build -t "$IMG" "$HERE" ;;
  logs)  exec docker logs -f "$NAME" ;;
  stop)  docker rm -f "$NAME" 2>/dev/null && echo "stopped $NAME" || echo "not running" ;;
  restart) "$0" stop; exec "$0" up ;;
  up|--up)
    docker image inspect "$IMG" >/dev/null 2>&1 || docker build -t "$IMG" "$HERE"
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    # -dit: detached, but WITH a TTY so pi's interactive session stays alive
    # (this is the clean version of the old `script` PTY hack). --restart keeps
    # it up across daemon restarts.
    docker run -dit --name "$NAME" --restart unless-stopped \
      --add-host=host.docker.internal:host-gateway \
      -e PI_SLACK_BOT_TOKEN -e PI_SLACK_APP_TOKEN -e PI_SLACK_OWNER_ID \
      "$IMG" >/dev/null
    echo "started $NAME (bridge for slack:$PI_SLACK_OWNER_ID)"
    echo "logs: $0 logs   stop: $0 stop"
    ;;
  *) echo "usage: $0 [build|up|logs|stop|restart]" >&2; exit 2 ;;
esac
