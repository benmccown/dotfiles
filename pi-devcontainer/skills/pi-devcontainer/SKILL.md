---
name: pi-devcontainer
description: "Work in Ben's pi-agent devcontainer — the NVIDIA-policy-compliant local sandbox that runs pi with his full toolset, MCPs, kube/Teleport access, and worktrees. Use when Ben says 'start the devcontainer', 'run pi in the container', 'pi-dev', wants a sandboxed pi session, spins up a parallel worktree session that should run in the container, or hits a devcontainer gotcha (localhost vs host.docker.internal, tsh session expiry, a missing tool, kube not reachable)."
---

# pi-devcontainer

Ben runs pi inside a local devcontainer (`pi-agent`) — the NVIDIA-approved
deployment pattern (isolation + self-managed egress). Lives in
`~/Code/dotfiles/pi-devcontainer/`. This skill is how to operate in it.

## When to Use

- Bringing the container up / attaching / opening a pi session in it.
- Running a per-worktree pi session in the container (cmux + `pi-dev`).
- Diagnosing a devcontainer gotcha (see Gotchas).
- Updating what's in the image (tools, versions).

## Bring-up & attach

```sh
export NVIDIA_INFERENCE_API_KEY=... GITHUB_TOKEN=...   # host shell
~/Code/dotfiles/pi-devcontainer/install.sh            # build (first time) + run "pi-agent"
~/Code/dotfiles/pi-devcontainer/install.sh --exec     # zsh shell inside
# VS Code: install.sh --vscode  → open ~/Code → Attach/Reopen in Container
```

Idempotent: re-running `install.sh` starts the existing container or creates it.
`./verify.sh` smoke-tests the whole surface.

## Running pi: the `pi-dev` wrapper

`pi-dev` (in `~/.scripts`, on PATH) runs pi **inside** the container at your
current dir. `~/Code` is mounted at identical paths, so `$PWD` is valid inside
unchanged.

```sh
pi-dev                 # pi in the current dir, in the container
pi-dev --version       # args pass through to pi
pi-dev --shell         # zsh in the container at $PWD
pi-dev -- <cmd> ...    # any command in the container at $PWD
```

It auto-detects if you're already inside the container (runs pi directly, no
nested docker) and forwards `PI_*` env through (e.g. pi-brain vault pinning).

## Worktrees + cmux (multi-session)

cmux is a host macOS app; it stays on the host and just launches sessions INTO
the container. The pi-brain `worktree-agent` spawn already takes `--launch`:

```sh
brain/skills/worktree-agent/scripts/spawn.sh <branch> --launch pi-dev
```

Each cmux workspace then runs `pi-dev` in that worktree's dir (mounted, so the
path is identical inside). Teardown is unchanged (`merge.sh ... --close-cmux`),
and the worktree-agent teardown-ordering rules still apply (tear down from
OUTSIDE the workspace being removed; close cmux LAST).

## kube / Teleport (bmccown-dev)

`kubectl` works in-container against `bmccown-dev` via the mounted `~/.tsh`
session + kubeconfig (the image ships `tsh` at `/usr/local/bin/tsh`). No YubiKey
inside. When the ~11h session expires, run **`tsh login` on the HOST** — the
mount picks it up live, no container restart.

## Local nemo-platform

Inside the container it's at **`host.docker.internal:49500`**, NOT `localhost`
(that's the container's own loopback). Ben's default provider
(`nvidia-direct` → `inference-api.nvidia.com`) needs none of this.

## Updating / extending the image

- Tool versions: `ARG`s at the top of `Dockerfile` (`GO_VERSION`, `TSH_VERSION`
  — keep matching the host tsh —, `HELM_VERSION`).
- Add an apt tool → first `RUN`; a released-binary tool → the `TARGETARCH` `RUN`.
- Rebuild: `install.sh --build`, then `verify.sh`.
- New mount: add to BOTH `devcontainer.json` `mounts` and `install.sh` `mounts`.

## Gotchas

- **localhost ≠ container** — host services are at `host.docker.internal`.
- **tsh session expires (~11h)** — `kubectl`/MaaS-style failures → `tsh login`
  on the host.
- **Mac shell overlay is absent in-container** — `~/.zshrc.mac` (brew/oh-my-zsh/
  switcher/nvm) is not mounted; the container uses the portable `~/.zshrc` base.
  Don't rely on mac-only aliases/completions inside.
- **macOS binaries in `~/.scripts` won't run** (e.g. `buildifier`, x86_64
  Mach-O) — the shell scripts do; native mac binaries don't.
- **Shared `~/.pi`** — the container mounts the host `~/.pi/agent`, so pi auth /
  MCP OAuth tokens are shared with the host. Fine for a personal box.
- **MaaS MCP works because it's LOCAL** — the MaaS gateway allowlists the
  laptop's egress, not arbitrary cluster IPs. A remote host (Phase 2) would need
  a tunnel or an allowlist request.
- **Egress is allow-all but logged** — `~/Code/.pi-egress/egress.log`; turn it
  into a candidate allowlist with `pi-devcontainer/egress-allowlist.sh`.
