# REDEPLOY — rehydrate my workstation from dotfiles

**You are an agent rehydrating Ben's full config onto a workstation** (new box,
or repairing drift on the current one). Unlike onboarding, this adopts
**everything** — this is my setup, restore all of it. Still confirm before
destructive or credential steps. **Idempotent and re-runnable**: run it on a
fresh box to install everything, or on an existing box to detect and fix drift.

## How to run

1. Read `manifest.md` — the full component inventory + each reconciler +
   post-step. Trust it over anything hard-coded here.
2. For each component, run its reconciler in **`--dry-run` first** to show the
   plan (what's missing / drifted / already-ok), then apply. No per-item opt-in
   prompt — apply all mine — but pause on anything that needs a secret or would
   overwrite non-dotfiles state.
3. Do each component's post-step:
   - MCP: after `mcp/sync-mcp.sh`, run `/mcp-auth` in pi (or restart pi) to
     re-authenticate every server (OAuth is per-machine).
   - nemo-platform: ensure `NVIDIA_INFERENCE_API_KEY` (or the configured env
     var) is set, then `nemo-platform/platform.sh up`.
   - Anything else the manifest lists.
4. Report drift explicitly: if a component was already present but differed,
   say what differed and that it was reconciled.

## Reconcile, don't clobber

Every reconciler compares desired-state (this repo) against current-state and
fixes only the delta. Re-running is safe and is the intended way to repair a
messed-up config: run REDEPLOY (or just the one component's reconciler) and it
pulls the live system back to the dotfiles-declared state without disturbing
unrelated things.

## Rules

- Show the dry-run plan before applying each component.
- Never hard-code or fetch secrets — prompt me to set the env vars / run the
  interactive auth flows myself.
- End with a summary: components restored, drift fixed, and the auth/secret
  steps I still need to complete by hand.
