# pi-brain observability stack (local Prometheus + Grafana)

A throwaway-friendly local stack to SEE pi-brain's OTEL telemetry — per-verb token
spend, output magnitude, and durations — graphed over time. pi-brain is a pure
OTEL producer; this is one local wiring of the backend it emits to.

## What it wires

- **Prometheus** (`:9090`) with its **native OTLP receiver** enabled
  (`--web.enable-otlp-receiver`). pi-brain **pushes OTLP metrics straight into
  Prometheus** at `POST /api/v1/otlp/v1/metrics` — no collector, no scrape.
- **Grafana** (`:3000`, anonymous admin) with Prometheus pre-provisioned as a
  datasource + a starter "pi-brain verbs" dashboard.

Why push (not a Prometheus PULL scrape of pi-brain's own endpoint): a scrape
misses short-lived processes — a headless `pi -p` pass exits before/between
scrapes. pi-brain's metrics **force-flush on shutdown**, so the PUSH path
reliably delivers a one-shot pass's numbers. (Metrics default to `otlp` push.)

## Run it

```bash
cd ~/Code/dotfiles/pi-brain/observability
docker compose up -d
open http://localhost:3000    # Grafana → dashboard "pi-brain verbs"
open http://localhost:9090    # Prometheus (raw queries)
docker compose down           # stop (data persists in ./data; add -v to wipe)
```

Health checks:
```bash
curl -s localhost:9090/-/healthy       # Prometheus Server is Healthy.
curl -s localhost:3000/api/health       # {"database":"ok",...}
# OTLP receiver present (405/415 on a GET = endpoint exists):
curl -s -o /dev/null -w '%{http_code}\n' localhost:9090/api/v1/otlp/v1/metrics
```

## Point pi-brain at it

Metrics are **ON by default** (`OTEL_METRICS_EXPORTER=otlp`). You only need to set
the endpoint to Prometheus's OTLP receiver (`env > config.json > default`):

```bash
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:9090/api/v1/otlp/v1/metrics
# (or set the generic OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:9090/api/v1/otlp
#  and pi-brain derives .../v1/metrics)
```

Then run a verb/pass, e.g. a maintenance pass:

```bash
cd <the pi-brain checkout/worktree>
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:9090/api/v1/otlp/v1/metrics \
PI_BRAIN_VAULT_DIR=/Users/bmccown/Code/pi-brain/brain \
pi -p "/brain-maintain"
```

A full pass over all scopes is SLOW (model latency; can be 10+ min) — normal, not
a hang. Metrics land on shutdown regardless. To disable emission entirely:
`OTEL_METRICS_EXPORTER=none`.

## The metrics you'll see (labels: verb, run_kind, work_kind, no_op, scope)

- `pibrain_verb_runs_total` — count of verb executions.
- `pibrain_verb_work_total` — units of output (articles compiled, dupes merged…).
- `pibrain_verb_duration_ms_*` — histogram of verb wall-time.
- `pibrain_verb_input_tokens_total` / `pibrain_verb_output_tokens_total` —
  gateway-reported tokens burned per verb. **This is the token-spend number.**

Handy Prometheus queries (also in the Grafana dashboard):

```promql
sum by (verb) (pibrain_verb_input_tokens_total + pibrain_verb_output_tokens_total)
sum by (verb) (pibrain_verb_work_total)
histogram_quantile(0.95, sum by (le, verb) (rate(pibrain_verb_duration_ms_milliseconds_bucket[5m])))
```

## Files

- `docker-compose.yml` — Prometheus (OTLP receiver on) + Grafana.
- `prometheus/prometheus.yml` — OTLP resource-attr promotion + self-scrape.
- `grafana/provisioning/` — datasource + dashboard provisioning.
- `data/` — persisted Prometheus/Grafana volumes (gitignored).
