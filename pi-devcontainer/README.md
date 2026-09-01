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
| `~/.config/mcp` | `/Users/bmccown/.config/mcp` | your 8 MCP servers |
| `~/.gitconfig` | `…/.gitconfig` (ro) | identity, read-only |

The `dev` user's `$HOME` is `/Users/bmccown` so `~/.pi/agent/extensions/*`
symlinks into `~/Code/pi-brain/extensions/*` resolve. You open the container
**once** and every project/worktree is inside it — not per-project.

## Egress: allow-all, but RECORD

`dnsmasq` is the container resolver and logs every DNS query (all egress starts
with one) to `~/Code/.pi-egress/egress.log`. No TLS MITM, no proxy, allow-all
upstream. Turn the log into a frequency-ranked candidate allowlist — the seed for
a future "default allowlist + ask-on-miss" posture — with:

```sh
./egress-allowlist.sh ~/Code/.pi-egress/egress.log
```

## Contents

- Ubuntu 24.04 (LTS) + Node 24 (LTS) + pi + git + **gh**.
- Debugging tools: `curl`, `jq`, `yq`, `sqlite3`, `ripgrep`, `fd`, `bat`,
  `python3`/`pipx`, `pandoc` (markdown), `tree`, `dnsutils`, `netcat`, etc.
- `GITHUB_TOKEN` injected → `gh` auto-authenticates.
- Provider `nvidia-direct` → `inference-api.nvidia.com` (comes from your mounted
  `~/.pi/agent`; a fallback is seeded only if none is mounted).

## Usage

```sh
export NVIDIA_INFERENCE_API_KEY=...          # host shell (GITHUB_TOKEN too)
~/Code/dotfiles/pi-devcontainer/install.sh   # build + run container "pi-agent"
docker exec -it pi-agent bash -l             # then: cd ~/Code/<proj> && pi
#   or: install.sh --exec
#   VS Code: install.sh --vscode  → open ~/Code → Reopen in Container
```

MCP servers are already mounted; run `/mcp-auth` in pi to (re)authorize them.
`./verify.sh` runs a full smoke test (versions, tools, mounts, extensions, gh,
egress) — all green.

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
