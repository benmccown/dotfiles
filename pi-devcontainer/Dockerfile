# Pi agent devcontainer — Ubuntu 24.04 + Node 22 + pi, with egress logging.
# Approved deployment pattern (agent-security-readiness.nvidia.com/devcontainer.html):
# process/fs isolation, self-managed egress, creds mounted read-only.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg jq dnsmasq \
      python3 python3-venv \
      openssh-client less ripgrep \
 && rm -rf /var/lib/apt/lists/*

# Node 22 (NodeSource) — pi needs >= 22.19
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm i -g @earendil-works/pi-coding-agent

# gh + glab CLIs (GitHub / internal GitLab)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Non-root dev user matching the typical host uid (1000)
ARG USERNAME=dev
RUN userdel -r ubuntu 2>/dev/null || true; \
    useradd -m -s /bin/bash -u 1000 ${USERNAME}

COPY entrypoint.sh /usr/local/bin/pi-entrypoint
RUN chmod +x /usr/local/bin/pi-entrypoint

# Entrypoint runs as ROOT to set up egress logging (rewrite resolv.conf), then
# drops to `dev` via setpriv (util-linux, already installed) to exec the command.
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pi-entrypoint"]
CMD ["sleep", "infinity"]
