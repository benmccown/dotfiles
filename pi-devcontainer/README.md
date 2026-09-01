# pi-devcontainer

Run the **pi coding agent** inside a local devcontainer — an NVIDIA-approved
deployment pattern (`agent-security-readiness.nvidia.com/devcontainer.html`):
process/filesystem isolation, **self-managed egress**, credentials mounted
read-only, project-only FS mounts. This is the sanctioned choice when Docker
Sandbox's centrally-managed allowlist doesn't fit your toolchain (it denies
GitHub by default; you need GitHub + gitlab-master + MaaS MCP + web).

## Why local (Phase 1)

The MaaS MCP gateway (`maas.prd.astra.nvidia.com`) allowlists your **laptop's**
egress but not arbitrary cluster egress IPs — verified: MaaS is reachable from
the laptop (405) but TLS-reset from the k8s dev pod. Running the devcontainer
**locally** satisfies the MaaS must-have for free. The same image is portable to
a remote host later (Phase 2) once the MaaS egress gap is solved there.

## Egress posture: allow-all, but RECORD

Phase 1 is **allow-all outbound** (you own the box) with **every reached host
logged**. `dnsmasq` runs as the container's resolver and logs every DNS query
(all egress starts with one) to `/workspace/.pi-egress/egress.log`. No TLS MITM,
no proxy. After a few months, `egress-allowlist.sh` turns that log into a
frequency-ranked candidate allowlist — the seed for a future Phase-2
"default allowlist + ask-on-miss" posture, populated from real usage instead of
guesswork.

```sh
./egress-allowlist.sh                 # ranked hosts the agent actually reached
```

## Files

- `Dockerfile` — Ubuntu 24.04 + Node 22 + pi + git/gh + dnsmasq.
- `devcontainer.json` — mounts project only (not `$HOME`); pi config/auth in a
  named volume; `~/.gitconfig` read-only; injects `NVIDIA_INFERENCE_API_KEY`.
- `entrypoint.sh` — starts egress logging; seeds the `nvidia-direct` provider
  (`inference-api.nvidia.com`) if a key is present.
- `egress-allowlist.sh` — log → candidate allowlist.
- `install.sh` — drop `.devcontainer/` into any project (idempotent).

## Usage

```sh
export NVIDIA_INFERENCE_API_KEY=...          # in your host shell
cd ~/my-project
~/Code/dotfiles/pi-devcontainer/install.sh   # writes ./.devcontainer
# VS Code: "Dev Containers: Reopen in Container"
#   or:    devcontainer up --workspace-folder .
```

Inside the container, wire the MCP servers:

```sh
~/Code/dotfiles/mcp/sync-mcp.sh              # reconcile ~/.config/mcp/mcp.json
# then in pi:  /mcp-auth                     # OAuth each MaaS server
```

## Model endpoint

Provider is `nvidia-direct` → `https://inference-api.nvidia.com/v1` (the real,
reachable NVIDIA endpoint; "integrate-api" does not resolve anywhere). The API
key is injected from the host env, **never baked into the image**.

## Policy notes

- Writes to sources of truth (repos, Jira, NVBugs) need human review — you land
  changes via PRs, which satisfies this.
- Credentials are mounted read-only / injected via env; not written to the
  agent-visible FS beyond the isolated `~/.pi` volume.
- If the agent does anything unexpected or you suspect prompt-injection: rotate
  creds, **preserve** the container (don't kill/clean), report csirt@nvidia.com.

## Phase 2 (later): remote host

Same image on the k8s dev pod / Omnistation. Open item: MaaS reaches only from
laptop-network egress, so remote needs a laptop-side reverse tunnel or a MaaS
allowlist request (#cdd-ai-clis) for the host's egress IP.
