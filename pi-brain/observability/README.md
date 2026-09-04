# pi-brain observability stack (local Prometheus + Grafana)

A throwaway-friendly local stack to SEE pi-brain's OTEL telemetry — per-verb token
spend, output magnitude, and durations — graphed over time. pi-brain is a pure
OTEL producer; this is one local wiring of the backends it emits to.

## What it wires

- **Prometheus** (`:9090`) scrapes pi-brain's OTEL **Prometheus metrics endpoint**
  (the `PrometheusExporter`, default `host:9464`) — the PULL metrics signal.
- **Grafana** (`:3000`, anonymous admin) with Prometheus pre-provisioned as a
  datasource + a starter "pi-brain verbs" dashboard.
- (Optional) point pi-brain's **traces** at an OTLP collector / nemo Intake
  separately; this stack is the metrics half.

## Run it

```bash
cd ~/Code/dotfiles/pi-brain/observability
docker compose up -d          # start Prometheus + Grafana
# ... run a pi-brain pass with metrics ON (see below) ...
open http://localhost:3000    # Grafana (anonymous)  → dashboard "pi-brain verbs"
open http://localhost:9090    # Prometheus (raw queries)
docker compose down           # stop (data persists in ./data unless you -v)
```

## Turn ON pi-brain metrics for a pass

pi-brain emits nothing to metrics unless you select a metrics exporter. For the
PULL (Prometheus) path, set these before running a maintenance pass / `brain`
verb — env wins over config.json wins over the default (`none`):

```bash
export OTEL_METRICS_EXPORTER=prometheus                       # PULL scrape endpoint
export PI_BRAIN_TELEMETRY_METRICS_PROMETHEUS_HOST=0.0.0.0     # so Docker can reach it
export PI_BRAIN_TELEMETRY_METRICS_PROMETHEUS_PORT=9464
# traces (optional): OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

Then run the verb you want to measure, e.g. a maintenance pass. Because the
Prometheus reader serves a scrape endpoint, the pi process must be **alive when
Prometheus scrapes** (every 5s here). A one-shot `pi -p` pass that exits
immediately may finish before the first scrape — for a first look, run an
interactive/longer pass, or use the OTLP push path instead (see below).

## The metrics you'll see (labels: verb, run_kind, work_kind, no_op, scope)

- `pibrain_verb_runs_total` — count of verb executions.
- `pibrain_verb_work_total` — units of output (articles compiled, dupes merged…).
- `pibrain_verb_duration_ms` — histogram of verb wall-time.
- `pibrain_verb_input_tokens_total` / `pibrain_verb_output_tokens_total` —
  gateway-reported tokens burned per verb. **This is the token-spend number.**

Handy Prometheus queries (also in the Grafana dashboard):

```promql
sum by (verb) (pibrain_verb_input_tokens_total + pibrain_verb_output_tokens_total)
sum by (verb) (pibrain_verb_work_total)
histogram_quantile(0.95, sum by (le, verb) (rate(pibrain_verb_duration_ms_bucket[5m])))
```

## Alternative: OTLP push (survives a short-lived `pi -p`)

If a pass exits too fast for the PULL scrape, use the PUSH path instead: run an
OTLP collector that Prometheus scrapes, and set
`OTEL_METRICS_EXPORTER=otlp` + `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`. Not wired in
this minimal stack by default — see `docker-compose.otlp.yml` if present, or add
an `otel/opentelemetry-collector` service.

## Files

- `docker-compose.yml` — Prometheus + Grafana.
- `prometheus/prometheus.yml` — scrape config (host.docker.internal:9464).
- `grafana/provisioning/` — datasource + dashboard provisioning.
- `data/` — persisted Prometheus/Grafana volumes (gitignored).
