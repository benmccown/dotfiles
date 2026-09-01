# pi-slack — dedicated long-running pi + Slack bridge container.
#
# This image is SELF-CONTAINED and ISOLATED: it uses its own pi config dir
# (PI_CODING_AGENT_DIR=/opt/pi-slack/agent), so it never touches the host's
# ~/.pi/agent (your devcontainer + local pi stay clean). The container IS the
# long-running bridge process — run it detached with a TTY and it stays connected.
FROM node:24-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates git tini \
 && rm -rf /var/lib/apt/lists/*

# Isolated pi config dir — the bridge + its packages live ONLY here.
ENV PI_CODING_AGENT_DIR=/opt/pi-slack/agent
ENV PI_SKIP_VERSION_CHECK=1

# pi + the Slack bridge, installed into the isolated agent dir.
ARG PI_VERSION=latest
ARG BRIDGE_VERSION=0.4.0
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION} \
 && mkdir -p "$PI_CODING_AGENT_DIR" \
 && pi install npm:pi-messenger-bridge@${BRIDGE_VERSION}

WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/pi-slack-entrypoint
RUN chmod +x /usr/local/bin/pi-slack-entrypoint

# tini reaps zombies + forwards signals; entrypoint seeds config then execs pi.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/pi-slack-entrypoint"]
CMD ["pi"]
