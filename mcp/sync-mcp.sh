#!/usr/bin/env bash
# Idempotent MCP server reconciler. Deep-merges the desired server list
# (mcp/servers.json) into the live pi MCP config (~/.config/mcp/mcp.json),
# reconciling desired-state against current-state:
#   - server missing from live  -> added
#   - server present but drifted -> reported (and fixed unless --dry-run)
#   - server present & identical -> left alone
#   - foreign servers in live    -> NEVER touched (a colleague keeps their own)
#
# Auth (OAuth browser flow) is NOT done here — it is per-machine and interactive.
# After a sync, run `/mcp-auth` in pi (or restart pi) to authenticate new servers.
#
# Usage:
#   ./sync-mcp.sh                 # apply: add/fix desired servers, report the plan
#   ./sync-mcp.sh --dry-run       # show the reconcile plan, change nothing
#   ./sync-mcp.sh --only a,b      # only reconcile these desired servers (opt-in subset)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESIRED="$HERE/servers.json"
LIVE="${MCP_CONFIG:-$HOME/.config/mcp/mcp.json}"

DRY=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --only) ONLY="$2"; shift ;;
    --only=*) ONLY="${1#--only=}" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -f "$DESIRED" ] || { echo "missing desired state: $DESIRED" >&2; exit 1; }

DRY="$DRY" ONLY="$ONLY" LIVE="$LIVE" DESIRED="$DESIRED" python3 - <<'PY'
import json, os, sys

desired_path = os.environ["DESIRED"]
live_path    = os.environ["LIVE"]
dry          = os.environ["DRY"] == "1"
only         = {s.strip() for s in os.environ["ONLY"].split(",") if s.strip()}

desired = json.load(open(desired_path)).get("mcpServers", {})
if only:
    desired = {k: v for k, v in desired.items() if k in only}

if os.path.exists(live_path):
    live_doc = json.load(open(live_path))
else:
    live_doc = {}
live = live_doc.setdefault("mcpServers", {})

add, fix, keep = [], [], []
for name, spec in desired.items():
    if name not in live:
        add.append(name)
        if not dry: live[name] = spec
    elif live[name] != spec:
        fix.append(name)
        if not dry: live[name] = spec
    else:
        keep.append(name)

foreign = sorted(set(live) - set(desired))

def line(tag, names):
    if names: print(f"  {tag}: {', '.join(sorted(names))}")

print(f"MCP reconcile ({'DRY-RUN' if dry else 'APPLY'})  live={live_path}")
line("add ", add)
line("fix ", fix)
line("ok  ", keep)
line("foreign (untouched)", foreign)
if not (add or fix):
    print("  already in sync.")

if not dry and (add or fix):
    os.makedirs(os.path.dirname(live_path), exist_ok=True)
    tmp = live_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(live_doc, f, indent=2); f.write("\n")
    os.replace(tmp, live_path)
    print(f"\nwrote {live_path}")
    print("next: run /mcp-auth in pi (or restart pi) to authenticate new servers.")
PY
