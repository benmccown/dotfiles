# pi-brain global extension provisioning

pi-brain ships extensions under `~/Code/pi-brain/extensions/`
(`scratch-space`, `memory`, `hello-world`). They are **project** extensions —
registered in pi-brain's own `package.json` `pi.extensions` — but several must
load **globally**, from any cwd (e.g. while working in `~/Code/nemo-platform`),
not just when pi runs inside the pi-brain repo.

pi discovers global extensions as directories under `~/.pi/agent/extensions/`.
So each pi-brain extension dir is symlinked into that global dir:

```
~/.pi/agent/extensions/pi-brain-scratch -> ~/Code/pi-brain/extensions/scratch-space
~/.pi/agent/extensions/pi-brain-memory  -> ~/Code/pi-brain/extensions/memory
~/.pi/agent/extensions/pi-brain-hello   -> ~/Code/pi-brain/extensions/hello-world
```

## Why this exists (the bug it fixes)

Without the symlink, an extension only loads inside the pi-brain checkout. That
silently broke **scratch-space**: its `before_agent_start` hook injects the
session's scratch dir path into the system prompt, but from a non-pi-brain cwd
the extension never loaded, so the path was never announced and the agent
guessed a wrong location (`.scratch/`). The symlinks were originally created by
hand and scratch's was simply missing — this script makes provisioning
reproducible so a fresh machine / devcontainer gets all of them.

## Usage

```bash
./link-extensions.sh            # apply (idempotent)
./link-extensions.sh --dry-run  # preview
```

Set `PI_BRAIN_DIR` to override the default `~/Code/pi-brain` checkout location.

The list of linked extensions lives in the `LINKS` array in
`link-extensions.sh`. When pi-brain adds a new global extension, add a row
there.
