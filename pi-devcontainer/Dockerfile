# Pi agent devcontainer — Ubuntu 24.04 (LTS) + Node 24 (LTS) + Go + pi, with the
# tools Ben actually uses (history-derived) and Teleport/kubectl for bmccown-dev.
# Approved deployment pattern (agent-security-readiness.nvidia.com/devcontainer.html):
# process/fs isolation, self-managed egress, creds mounted read-only.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Tool versions — bump here; keep tsh matching the host (kubeconfig exec plugin).
ARG GO_VERSION=1.27.0
ARG TSH_VERSION=18.6.4
ARG HELM_VERSION=v4.2.4

# Core + debugging/inspection tools. zsh + git for Ben's shell; python/jq/yq/
# sqlite/rg/fd/bat/pandoc for inspection; httpie from apt; neovim (his $EDITOR).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git gnupg jq dnsmasq zsh \
      python3 python3-venv python3-pip pipx httpie \
      sqlite3 ripgrep fd-find bat tree file unzip zip xz-utils \
      pandoc neovim vim less openssh-client iproute2 dnsutils netcat-openbsd \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
# Fall back to dpkg arch when TARGETARCH isn't set (plain `docker build`).
RUN set -eux; ARCH="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    # yq (YAML/JSON/XML query)
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq; \
    # Go
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz; \
    # kubectl (latest stable)
    curl -fsSL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl; \
    # tsh (Teleport) — pinned to host version; kubeconfig exec plugin needs it at /usr/local/bin/tsh
    curl -fsSL "https://cdn.teleport.dev/teleport-v${TSH_VERSION}-linux-${ARCH}-bin.tar.gz" | tar -C /tmp -xz && install -m755 /tmp/teleport/tsh /usr/local/bin/tsh && rm -rf /tmp/teleport; \
    # helm
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | tar -C /tmp -xz && install -m755 "/tmp/linux-${ARCH}/helm" /usr/local/bin/helm && rm -rf "/tmp/linux-${ARCH}"; \
    # eza (Ben's ls); GitHub release tarball (not in apt 24.04)
    curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_$(uname -m)-unknown-linux-gnu.tar.gz" | tar -C /usr/local/bin -xz 2>/dev/null || true

ENV PATH=/usr/local/go/bin:/root/go/bin:${PATH}

# kubectx / kubens (thin scripts)
RUN curl -fsSL https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -o /usr/local/bin/kubectx \
 && curl -fsSL https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens  -o /usr/local/bin/kubens \
 && chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens

# uv (Python package/runtime manager — Ben's 2nd-most-used command)
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Node 24 (current LTS) + pi (needs Node >= 22.19)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm i -g @earendil-works/pi-coding-agent

# Slack bridge extension, installed OFF the auto-discovery path (/opt/slack-bridge).
# It stays inert — normal `pi`/`pi-dev` sessions never load it. Only the opt-in
# `pi-slack-dev` launcher loads it for ONE session via `pi -e`. This keeps the
# per-cmux-workspace devcontainer sessions clean; exactly one may run the bridge.
RUN mkdir -p /opt/slack-bridge
WORKDIR /opt/slack-bridge
RUN npm init -y >/dev/null 2>&1 \
 && npm i pi-messenger-bridge@0.4.0 \
 && chmod -R a+rX /opt/slack-bridge
WORKDIR /Users/bmccown/Code

# gh (GitHub CLI). glab omitted — optional; install by hand if needed.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Non-root dev user whose HOME matches the host path, so mounted ~/.pi symlinks
# (extensions -> ~/Code/pi-brain/...), ~/.zshrc, ~/.scripts, and ~/.config resolve.
ARG USERNAME=dev
ARG DEV_HOME=/Users/bmccown
RUN userdel -r ubuntu 2>/dev/null || true; \
    mkdir -p ${DEV_HOME} && \
    useradd -s /usr/bin/zsh -u 1000 -d ${DEV_HOME} ${USERNAME} && \
    chown ${USERNAME} ${DEV_HOME}
# fd/bat ship as fdfind/batcat on Debian — add friendly names
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd 2>/dev/null || true; \
    ln -sf "$(command -v batcat)" /usr/local/bin/bat 2>/dev/null || true

COPY entrypoint.sh /usr/local/bin/pi-entrypoint
RUN chmod +x /usr/local/bin/pi-entrypoint

# Entrypoint runs as ROOT to set up egress logging (rewrite resolv.conf), then
# drops to `dev` via setpriv to exec the command.
WORKDIR /Users/bmccown/Code
ENTRYPOINT ["/usr/local/bin/pi-entrypoint"]
CMD ["sleep", "infinity"]
