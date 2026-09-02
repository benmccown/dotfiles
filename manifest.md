# dotfiles manifest

The inventory of what this dotfiles repo manages. Both `ONBOARDING.md`
(colleague, opt-in) and `REDEPLOY.md` (me, new workstation) read this to know
the full set of components and how to reconcile each. Each component owns an
idempotent reconciler so desired-state → current-state is safe to re-run.

## Principles

- **Idempotent.** Every reconciler is safe to run repeatedly. Re-running fixes
  drift; it never double-applies.
- **Desired vs. current.** Each component keeps a desired-state record in the
  repo and a script that reconciles the live system toward it, reporting the
  plan (add / fix / already-ok) before/while applying.
- **Non-destructive to foreign state.** Reconcilers touch only what dotfiles
  declares; a colleague's own unrelated config survives.
- **Auth is never in dotfiles.** Secrets and OAuth tokens are per-machine and
  interactive. Reconcilers set up *config*; the human authenticates after.

## Components

| component | desired state | reconciler | post-step | audience |
|---|---|---|---|---|
| shell + scripts + config | `home/` `scripts/` `config/` | `link.sh [--dry-run]` | populate `~/.config/secrets.env` | personal |
| host CLI deps | `Brewfile` | `brew bundle --file=Brewfile` | — | personal |
| MCP servers | `mcp/servers.json` | `mcp/sync-mcp.sh [--dry-run] [--only a,b]` | `/mcp-auth` in pi | shareable |
| pi devcontainer | `pi-devcontainer/` | `pi-devcontainer/install.sh [project]` | set `NVIDIA_INFERENCE_API_KEY`; open in container | shareable |
| nemo-platform dogfood | `nemo-platform/` | `nemo-platform/platform.sh up` | needs `NVIDIA_INFERENCE_API_KEY` | personal |
| pi-brain worklog ext | `pi-brain/extensions.d/worklog/` | (copy into pi extensions dir) | — | shareable |

When you add a new component to dotfiles, add a row here with its reconciler,
any post-install auth/secret step, and its **audience** (`shareable` = offer to
colleagues normally; `personal` = Ben's own, default-skip in ONBOARDING) — that's
what keeps ONBOARDING and REDEPLOY complete without editing either of them.
