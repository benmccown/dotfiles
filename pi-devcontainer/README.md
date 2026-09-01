# pi-devcontainer

Run the **pi coding agent** in a local, workspace-wide devcontainer — an
NVIDIA-approved deployment pattern
(`agent-security-readiness.nvidia.com/devcontainer.html`): process/filesystem
isolation, **self-managed egress**, credentials injected/read-only. This is the
sanctioned choice when Docker Sandbox's centrally-managed allowlist doesn't fit
your toolchain (it denies GitHub by default; you need GitHub + gitlab-master +
MaaS MCP + web).

## Why local (Phase 1)

The MaaS MCP gateway (`maas.prd.astra.nvidia.com`) allowlists your **laptop's**
egress but not arbitrary cluster egress IPs (verified: reachable from the laptop,
TLS-reset from the k8s dev pod). Running locally satisfies the MaaS must-have for
free. The image is portable to a remote host later (Phase 2).

## Workspace-wide, via mounts (not copies)

It mounts your real host paths **at their identical container paths**, so
symlinked extensions, worktrees, and configs resolve unchanged:

| Host | Container | Why |
|---|---|---|
| `~/Code` | `/Users/bmccown/Code` | all projects + `*.worktrees` (pi-brain, nemo-platform, nmp) |
| `~/.pi/agent` | `/Users/bmccown/.pi/agent` | pi config, installed packages/extensions, auth |
| `~/.config/mcp` | `/Users/bmccown/.config/mcp` | your MCP servers |
| `~/.config/secrets.env` | `…` (ro) | API keys/tokens (sourced by zshrc) |
| `~/.zshrc` | `…` (ro) | portable shell config (mac overlay excluded) |
| `~/.scripts` | `…` | your bin (git-wtadd, devbuild, md2pdf, …) |
| `~/.config/git` `~/.config/k9s` | `…` | git hooks/ignore, k9s config |
| `~/.tsh` + `~/teleport-kubeconfig.yaml` | `…` | Teleport session + kubeconfig → `kubectl` to `bmccown-dev` |

The `dev` user's `$HOME` is `/Users/bmccown` so `~/.pi/agent/extensions/*`
symlinks into `~/Code/pi-brain/extensions/*` resolve. You open the container
**once** and every project/worktree is inside it — not per-project.

## Shell (portable base + mac overlay)

`~/.zshrc` is the **portable base** (aliases, `wtadd`/`wtrm`, env, secrets
source, `~/.scripts` on PATH) used by BOTH host and container. macOS-only bits
(oh-my-zsh, brew, switcher, nvm, completions) live in `~/.zshrc.mac`, which the
base sources only if present — so the container gets a clean shell with no
brew/oh-my-zsh errors. `wtadd` uses `git config --unset core.bare` (portable),
not `sed -i ''` (macOS-only).

## kubectl / Teleport (bmccown-dev)

The kubeconfig's exec-plugin shells out to `tsh`, so the image ships `tsh`
(pinned to the host version) at `/usr/local/bin/tsh` and mounts your live
`~/.tsh` session — `kubectl get pods -n bmccown-dev` works in-container (no
YubiKey inside; re-auth with `tsh login` on the **host** when the ~11h session
expires — the mount picks it up live).

## Local nemo-platform

Your host's `localhost:49500` is **not** the container's localhost. The
container gets `--add-host=host.docker.internal:host-gateway`, so the running
platform is reachable at **`host.docker.internal:49500`** inside the container.
(Your default provider is `nvidia-direct`/`inference-api.nvidia.com`, which needs
none of this; only the local `nemo` provider does.)

## Egress: allow-all, but RECORD

`dnsmasq` is the container resolver and logs every DNS query (all egress starts
with one) to `~/Code/.pi-egress/egress.log`. No TLS MITM, no proxy, allow-all
upstream. Turn the log into a frequency-ranked candidate allowlist — the seed for
a future "default allowlist + ask-on-miss" posture — with:

```sh
./egress-allowlist.sh ~/Code/.pi-egress/egress.log
```

## Contents

- Ubuntu 24.04 (LTS) + Node 24 (LTS) + **Go 1.27** + pi + git + **gh**.
- Kube/infra: `kubectl`, `tsh` (Teleport), `helm`, `kubectx`/`kubens`.
- Dev/debug: `curl`, `httpie`, `jq`, `yq`, `sqlite3`, `ripgrep`, `fd`, `bat`,
  `python3`/`pipx`/`uv`, `pandoc`, `neovim`, `tree`, `dnsutils`, `netcat`, `eza`.
- `GITHUB_TOKEN` injected → `gh` auto-authenticates.
- Provider `nvidia-direct` → `inference-api.nvidia.com` (from your mounted
  `~/.pi/agent`; a fallback is seeded only if none is mounted).

Bump tool versions via the `ARG`s at the top of the Dockerfile (`GO_VERSION`,
`TSH_VERSION` — keep matching the host —, `HELM_VERSION`). Add an apt tool to the
first `RUN`; add a released-binary tool to the `TARGETARCH` `RUN` block.

## Usage

```sh
export NVIDIA_INFERENCE_API_KEY=...          # host shell (GITHUB_TOKEN too)
~/Code/dotfiles/pi-devcontainer/install.sh   # build + run container "pi-agent"
~/Code/dotfiles/pi-devcontainer/install.sh --exec   # open a zsh shell
#   then: cd ~/Code/<proj> && pi
#   VS Code: install.sh --vscode  → open ~/Code → Attach/Reopen in Container
```

MCP servers are already mounted; run `/mcp-auth` in pi to (re)authorize them.
`./verify.sh` runs a full smoke test (versions, tools, mounts, extensions, gh,
kube→bmccown-dev, host nemo-platform, egress) — all green.

## Policy notes

- Writes to sources of truth (repos, Jira, NVBugs) need human review — you land
  via PRs, which satisfies this.
- Credentials are injected via env / mounted read-only; not written to the
  agent-visible FS beyond your own mounted `~/.pi`.
- On anything unexpected or suspected prompt-injection: rotate creds,
  **preserve** the container (don't kill/clean), report csirt@nvidia.com.

## Phase 2 (later): remote host

Same image on the k8s dev pod / Omnistation. Open item: MaaS reaches only from
laptop-network egress, so remote needs a laptop-side reverse tunnel or a MaaS
allowlist request (#cdd-ai-clis) for the host's egress IP.
