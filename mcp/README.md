# MCP servers

Reusable record of the MCP servers this dotfiles setup manages, plus an
idempotent reconciler that installs them into pi's MCP config.

## Files

- **`servers.json`** — desired-state server list (the durable record). Same
  shape as pi's live MCP config (`~/.config/mcp/mcp.json`), so it's just a
  copy you can diff.
- **`sync-mcp.sh`** — idempotent reconciler. Deep-merges `servers.json` into
  the live config: adds missing servers, fixes drifted ones, leaves any
  *foreign* servers (yours, not in this list) untouched. `--dry-run` to preview,
  `--only a,b` to install a subset (opt-in).

## Usage

```sh
./sync-mcp.sh --dry-run              # show the reconcile plan
./sync-mcp.sh                        # apply (add/fix desired servers)
./sync-mcp.sh --only maas-slack,maas-gitlab   # opt into a subset
```

After a sync, **authenticate** new servers: run `/mcp-auth` in pi (or restart
pi). Auth is per-machine and interactive (OAuth browser flow) — never stored in
dotfiles.

## The MaaS pattern (NVIDIA giza_ai MCP servers)

NVIDIA's MaaS MCP servers all follow one shape:

```json
"maas-<name>": {
  "url": "https://maas.prd.astra.nvidia.com/maas/<name>/mcp",
  "auth": "oauth",
  "oauth": { "clientId": "eci-prd-pub-9ab40d21-b129-4075-8e82-842df4cb5045" },
  "protocolVersion": "auto"
}
```

- **URL:** `https://maas.prd.astra.nvidia.com/maas/<server>/mcp` (prod).
- **clientId** is per *client type*, not per server:
  - `eci-prd-pub-9ab40d21-b129-4075-8e82-842df4cb5045` — Cursor / Claude Code / pi (what we use)
  - `eci-prd-pub-160c4545-f84f-4483-bf7c-d2450e5c0216` — OpenAI Codex
- **Catalog** of ~110 available servers + per-server docs:
  https://ipp-safety-tools.gitlab-master-pages.nvidia.com/giza-llm-tools/giza_ai/docs/category/maas-mcp-servers-user-guide
- Some servers have versioned paths (e.g. `gdrive_v2` supersedes `gdrive`,
  `confluence_v2` supersedes `confluence`) — check the server's doc page.
- A bare `GET` to a live endpoint returns HTTP `405` (wrong method) — handy
  liveness check: `curl -s -o /dev/null -w '%{http_code}' <url>`.

## Currently managed

| server | endpoint | notes |
|---|---|---|
| `linear` | `mcp.linear.app/mcp` | not MaaS; Linear's own hosted MCP |
| `maas-outlook` | `/maas/outlook/mcp` | email/calendar |
| `maas-gitlab` | `/maas/gitlab/mcp` | |
| `maas-nvbugs` | `/maas/nvbugs/mcp` | bug tracker |
| `maas-slack` | `/maas/slack/mcp` | |
| `maas-teams` | `/maas/teams/mcp` | |
| `maas-nvinfo` | `/maas/nvinfo/mcp` | employee/org/rooms lookup |
| `maas-gdrive` | `/maas/gdrive_v2/mcp` | v2 (v1 legacy) |

To add more: pick from the catalog, append to `servers.json` following the
MaaS pattern, run `./sync-mcp.sh`, then `/mcp-auth`.
