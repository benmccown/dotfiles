#!/usr/bin/env bash
# pi-slack entrypoint — seeds the ISOLATED pi config, then runs pi (which
# auto-loads the Slack bridge and stays connected for the container's lifetime).
#
# Env (pass at `docker run`):
#   PI_SLACK_OWNER_ID          Slack member id (U...) allowed to use the bot (required)
#   PI_SLACK_BOT_TOKEN         xoxb-... bot token   (read by the bridge)
#   PI_SLACK_APP_TOKEN         xapp-... app token   (read by the bridge)
#   PI_SLACK_GATEWAY_HOST      local nemo gateway host:port (default host.docker.internal:49500)
set -euo pipefail

AGENT_DIR="${PI_CODING_AGENT_DIR:-/opt/pi-slack/agent}"

if [ -z "${PI_SLACK_OWNER_ID:-}" ]; then
  echo "[pi-slack] FATAL: PI_SLACK_OWNER_ID not set" >&2
  exit 1
fi

# The bridge reads its config from $HOME/.pi/msg-bridge.json — keep HOME inside
# the isolated tree so nothing lands on a host mount.
HOME="$(dirname "$AGENT_DIR")/home"
export HOME
mkdir -p "$HOME/.pi"

# Access allowlist (single trusted user, fail closed if owner id absent above).
cat > "$HOME/.pi/msg-bridge.json" <<JSON
{
  "auth": {
    "trustedUsers": ["slack:${PI_SLACK_OWNER_ID}"],
    "adminUserId": "slack:${PI_SLACK_OWNER_ID}"
  },
  "autoConnect": true,
  "showWidget": true
}
JSON
chmod 600 "$HOME/.pi/msg-bridge.json"

# Model provider: the LOCAL nemo-platform inference gateway. Inside a container
# the host gateway is reachable at host.docker.internal:49500 (NOT localhost).
# apiKey is "not-used" — the local gateway does not check it.
GATEWAY_HOST="${PI_SLACK_GATEWAY_HOST:-host.docker.internal:49500}"
if [ ! -f "$AGENT_DIR/models.json" ]; then
  cat > "$AGENT_DIR/models.json" <<JSON
{
  "providers": {
    "nemo": {
      "baseUrl": "http://${GATEWAY_HOST}/apis/inference-gateway/v2/workspaces/default/openai/-/v1",
      "api": "openai-completions",
      "apiKey": "not-used",
      "models": [
        { "id": "default/aws-anthropic-bedrock-claude-sonnet-4-6", "name": "NeMo \u00b7 Claude Sonnet 4.6" },
        { "id": "default/aws-anthropic-bedrock-claude-opus-4-8", "name": "NeMo \u00b7 Claude Opus 4.8" }
      ]
    }
  }
}
JSON
  echo "[pi-slack] seeded nemo provider -> http://${GATEWAY_HOST}"
fi

# Default model so the agent has something selected when a DM arrives.
node -e '
const fs=require("fs"), p=process.env.PI_CODING_AGENT_DIR+"/settings.json";
const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
s.defaultProvider="nemo";
s.defaultModel="default/aws-anthropic-bedrock-claude-sonnet-4-6";
fs.writeFileSync(p, JSON.stringify(s,null,2));
'

echo "[pi-slack] starting bridge for slack:${PI_SLACK_OWNER_ID} (agent dir: $AGENT_DIR)"
exec "$@"
