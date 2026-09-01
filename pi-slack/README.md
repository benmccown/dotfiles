# pi-slack

Dedicated, long-running container that runs a `pi` agent connected to Slack via
[`pi-messenger-bridge`](https://www.npmjs.com/package/pi-messenger-bridge). DM the
bot (Pi Buddy) and the agent answers.

**This is separate from the devcontainer.** It uses its own isolated pi config
(`PI_CODING_AGENT_DIR=/opt/pi-slack/agent`), so the bridge extension never touches
your `~/.pi/agent` — your devcontainer and local `pi` stay clean.

## Run

Source your secrets, then bring it up:

```bash
source ~/.config/secrets.env      # PI_SLACK_BOT_TOKEN / PI_SLACK_APP_TOKEN /
                                  # PI_SLACK_OWNER_ID / NVIDIA_INFERENCE_API_KEY
./run.sh up                       # build if needed, start detached, stays connected
./run.sh logs                     # follow
./run.sh stop                     # tear down
```

The container is the long-running bridge process (`docker run -dit`, `--restart
unless-stopped`), so it survives daemon/host restarts and reconnects on its own.

## How it works

- `Dockerfile` installs pi + the bridge into the isolated agent dir at build time.
- `entrypoint.sh` seeds, at startup: the single-user access allowlist (from
  `PI_SLACK_OWNER_ID`), the `nvidia-direct` model provider, and `autoConnect: true`.
- Tokens are passed in as env at `docker run` (from your host env), never baked in.

## Access

Responds only to the Slack member id in `PI_SLACK_OWNER_ID`.

## Slack app

App manifest for reference: [`slack-app-manifest.yaml`](./slack-app-manifest.yaml).
