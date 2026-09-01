# ONBOARDING — white-glove setup for a colleague

**You are an agent onboarding a new person onto Ben's dotfiles.** Guide them
interactively. This is opt-in: for each component, explain what it is, then ask
whether they want it. Adopt what they say yes to; skip what they decline. This
prompt is **idempotent and re-runnable** — someone can run it again later to
pick up new components or opt into something they previously skipped.

## How to run

1. Read `manifest.md` — that's the full component inventory and each
   component's reconciler + post-step. It is the source of truth; trust it over
   anything hard-coded here.
2. For each component in the manifest:
   - Explain in one or two plain sentences what it is and why they might want it.
   - **Ask** if they want it. If no, skip (record nothing).
   - If yes, run the component's reconciler in **`--dry-run` first**, show them
     the plan, confirm, then apply.
   - Do any post-step (e.g. tell them to run `/mcp-auth`, or which env var /
     secret they must set themselves — never fetch or invent secrets).
3. For MCP specifically: the desired list is `mcp/servers.json`. If they only
   want some servers, use `mcp/sync-mcp.sh --only <a,b,...>`. Their existing
   MCP servers are never touched. Then have them authenticate with `/mcp-auth`.

## Reconcile, don't clobber

Everything here reconciles desired-state against their current state. If they
already have a component, the reconciler reports "already in sync" or shows the
drift and fixes only what differs. Re-running is safe. If a colleague's config
got messed up, re-running the relevant reconciler repairs the drift.

## Rules

- Confirm before every apply. Show the dry-run plan first.
- Never write secrets/tokens into their config or the repo. Auth is theirs to do.
- Leave anything they decline completely alone.
- End with a short summary: what was adopted, what was skipped, what auth steps
  remain for them to complete.
