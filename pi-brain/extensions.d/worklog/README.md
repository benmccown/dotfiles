# worklog — pi-brain extension

The first pi-brain **extension** (R1 / D-EXTRACT): the worklog work-item system,
extracted OUT of pi-brain core so shipped pi-brain carries no worklog assumption.
It lives here in dotfiles and is loaded only when enabled.

## What it is

A work item is just a typed memory (`type:worklog` + `wl_*` frontmatter) with a
lifecycle. This extension ships:

- **`index.ts`** — default-exports `{ descriptor, registerTools }`:
  - `descriptor` — the `type:worklog` recall behavior (hidden from ordinary
    recall, type-searchable). Mirrors `manifest.json`.
  - `registerTools(pi, api)` — registers `worklog_add` / `worklog_list` /
    `worklog_get` / `worklog_update`, the `/brain-worklog` command, and the
    flag-gated `<brain-worklog-suggest>` prompt fragment, all over the injected
    `BrainApi` (read/write/index + `appendLog` + `notifyWrite`).
- **`worklog.ts`** — the pure vocabulary/view/format helpers (no pi-brain imports).
- **`manifest.json`** — the declarative descriptor (recall-only loader fallback).

The worklog SKILLS (`worklog-capture/triage/next/execute`) and the
`worklog-distiller` AGENT already live in the user memory vault
(`brain/memory/skills/`, `brain/memory/agents/`), so they load as ordinary
user-tier skills/agents — they are not duplicated here.

## Enabling it

pi-brain discovers extensions in `$PI_BRAIN_CONFIG_DIR/extensions.d/` (default
`~/.config/pi-brain/extensions.d/`). Point that at this folder (symlink) and enable
it in `config.json`:

```jsonc
// ~/.config/pi-brain/config.json
{ "extensions": { "enabled": ["worklog"] } }   // or PI_BRAIN_EXTENSIONS_ENABLED=worklog
```

Presence ≠ enabled — the extension is inert until listed in `extensions.enabled`.
Loading rides pi's project-trust (the extension ships executable code).

Proactive capture nudge is opt-in: `PI_BRAIN_WORKLOG_SUGGEST=on`.
