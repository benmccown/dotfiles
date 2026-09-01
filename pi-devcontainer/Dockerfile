# Pi agent devcontainer — Ubuntu 24.04 (current LTS) + Node 24 (current LTS) + pi,
# with egress logging. Approved deployment pattern
# (agent-security-readiness.nvidia.com/devcontainer.html): process/fs isolation,
# self-managed egress, creds mounted read-only.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
# Core + common debugging/inspection tools (jq/yq/sqlite/ripgrep/fd/pandoc/etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git gnupg jq dnsmasq \
      python3 python3-venv python3-pip pipx \
      sqlite3 ripgrep fd-find bat tree file unzip zip xz-utils \
      pandoc vim less openssh-client iproute2 dnsutils netcat-openbsd \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

# yq (YAML/JSON/XML query) — single static binary, not in apt
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
      -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Node 24 (current LTS "Krypton"); pi needs >= 22.19
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm i -g @earendil-works/pi-coding-agent

# gh (GitHub CLI). glab (internal GitLab CLI) intentionally omitted — optional,
# and its release-asset URL is fragile to script; install by hand if needed.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Non-root dev user whose HOME matches the host path, so mounted ~/.pi symlinks
# (extensions -> ~/Code/pi-brain/...) and ~/.config resolve unchanged.
ARG USERNAME=dev
ARG DEV_HOME=/Users/bmccown
RUN userdel -r ubuntu 2>/dev/null || true; \
    mkdir -p ${DEV_HOME} && \
    useradd -s /bin/bash -u 1000 -d ${DEV_HOME} ${USERNAME} && \
    chown ${USERNAME} ${DEV_HOME}
# fd/bat ship as fdfind/batcat on Debian — add friendly names
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd 2>/dev/null || true; \
    ln -sf "$(command -v batcat)" /usr/local/bin/bat 2>/dev/null || true

COPY entrypoint.sh /usr/local/bin/pi-entrypoint
RUN chmod +x /usr/local/bin/pi-entrypoint

# Entrypoint runs as ROOT to set up egress logging (rewrite resolv.conf), then
# drops to `dev` via setpriv (util-linux, already installed) to exec the command.
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pi-entrypoint"]
CMD ["sleep", "infinity"]
