# nemo-platform (dogfood run-copy)

The dedicated **NeMo Platform** instance that pi-brain dogfoods against as its
**model provider** (Pi's `nemo` provider → `http://localhost:49500`) and
**telemetry sink** (Intake). This lives out-of-tree, in dotfiles, on purpose:
running the platform is a bespoke *provider choice*, **not** a pi-brain concept.
pi-brain itself just rides Pi's model config + emits OTEL; it neither knows nor
cares that the sink here is a local NeMo Platform.

## Layout

- `platform.sh` — the idempotent lifecycle helper (clone / bootstrap / start /
  provider / smoke / status / stop). Moved here from `pi-brain/scripts/`.
- The checkout itself lives at **`../.repos/nemo-platform`** (gitignored, ~6.6G),
  managed by `platform.sh clone`.

## Usage

```sh
./platform.sh up        # clone + bootstrap + start + register provider + smoke
./platform.sh start     # start (idempotent) in tmux session `pi-brain-nemo`
./platform.sh status    # health + provider + checkout + tmux
./platform.sh smoke     # chat-completion smoke test through the gateway
./platform.sh stop      # stop (data preserved)
./platform.sh logs      # tail /tmp/pi-brain-nemo.log
```

## Data dir (isolated, NOT moved)

The platform's data lives at **`~/.local/share/nemo-pi-brain/`** (entity-store
`nhx-platform.db` + `intake-clickhouse/` + `files/` + encryption key). It is
XDG-correct, clearly named, and isolated from a raw DEV nemo instance (which uses
the default `~/.local/share/nemo/`).

**The platform reads `NHX_DATA_DIR`** (post NMP->NHX rename). `platform.sh` exports
`NHX_DATA_DIR` (from its `LOREGRAFT_NMP_DATA_DIR` knob) on every start/CLI call, so
isolation is script-enforced. This matters: without it the platform silently falls
back to the DEFAULT `~/.local/share/nemo/` and SHARES ONE SQLite DB with any other
local Helix instance — both controllers then poll the same jobs table and steal
each other's jobs (cross-wiring symptom: a job scheduled by the wrong instance, run
under the wrong executor config/port). One data dir per instance, always.
**Belt-and-suspenders:** export `NHX_DATA_DIR=~/.local/share/nemo-pi-brain` in your
shell rc so isolation holds even outside `platform.sh`.

## nvidia-direct fallback provider (resilience)

If this local platform is down, Pi has a second provider **`nvidia-direct`** in
`~/.pi/agent/models.json` pointing straight at the upstream the platform proxies
to:

- baseUrl `https://inference-api.nvidia.com/v1`, `authHeader: true`,
  `apiKey: "$NVIDIA_INFERENCE_API_KEY"`.
- model ids use the DIRECT slash shape, e.g.
  `aws/anthropic/bedrock-claude-opus-4-8` (vs. the local `nemo` provider's
  `default/aws-anthropic-bedrock-claude-opus-4-8`).

`/model` to `nvidia-direct/aws/anthropic/bedrock-claude-opus-4-8` whenever you
need to stop/move/restart this platform without stranding your agent session.
Requires `$NVIDIA_INFERENCE_API_KEY` in the environment.
