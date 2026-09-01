# ONBOARDING — white-glove setup for a colleague

**You are an agent onboarding a new person onto Ben's dotfiles.** Guide them
interactively. This is opt-in: for each component, explain what it is, then ask
whether they want it. Adopt what they say yes to; skip what they decline. This
prompt is **idempotent and re-runnable** — someone can run it again later to
pick up new components or opt into something they previously skipped.

## How to run

1. Read `manifest.md` — the full component inventory, each component's
   reconciler + post-step, AND its **audience** (`shareable` vs `personal`). It
   is the source of truth; trust it over anything hard-coded here.
2. Split the components by audience and treat them differently:
   - **Shareable** (e.g. MCP servers, pi-devcontainer): generally useful. Offer
     each normally — explain it, ask, apply on yes.
   - **Personal** (e.g. Ben's `~/.zshrc`, `~/.scripts`, `~/.config` — the
     `link.sh` set): these are Ben's bespoke setup and most people do NOT want
     them. **Default is SKIP.** Do not adopt them unless the person explicitly
     asks. Before offering, say plainly: "These are my personal shell/config
     files — most people bring their own and should skip these."
3. For each component the person opts into:
   - Explain in one or two plain sentences what it is and why they might want it.
   - Run the component's reconciler in **`--dry-run` first**, show the plan,
     confirm, then apply.
   - Do any post-step (tell them which env var / secret to set themselves —
     never fetch or invent secrets).
4. **Granular control for personal config:** never adopt the `link.sh` set
   wholesale by default. If they DO want some of it, go item-by-item (zshrc?
   scripts? git config? k9s?) and link only what they pick — `link.sh` is
   all-or-nothing, so for a subset, symlink the chosen items by hand rather than
   running it. Warn that adopting `~/.zshrc` replaces their shell config
   (it's backed up).
5. For MCP: the desired list is `mcp/servers.json`. For a subset, use
   `mcp/sync-mcp.sh --only <a,b,...>`. Their existing servers are never touched.
   Then `/mcp-auth`.

## Reconcile, don't clobber

Everything here reconciles desired-state against their current state. If they
already have a component, the reconciler reports "already in sync" or shows the
drift and fixes only what differs. Re-running is safe. If a colleague's config
got messed up, re-running the relevant reconciler repairs the drift.

## Rules

- **Personal config defaults to SKIP** — never adopt Ben's zshrc/scripts/config
  unless explicitly requested, and then only the specific items chosen.
- Confirm before every apply. Show the dry-run plan first.
- Never write secrets/tokens into their config or the repo. Auth is theirs to do.
- Leave anything they decline completely alone.
- End with a short summary: what was adopted, what was skipped, what auth steps
  remain for them to complete.
