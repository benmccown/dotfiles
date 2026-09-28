# `cv` — clipboard → nvim → clipboard

A one-keystroke "edit the clipboard in an editor, then put the result back on
the clipboard" flow. Built for the pi workflow: `ctrl+x` in pi copies the last
agent message, then `cv` pops nvim to tweak the markdown, `:wq` lands the edited
text back on the clipboard ready to paste into Slack / a PR / wherever.

## Pieces

| piece | path | role |
|---|---|---|
| the script | `scripts/cv` (on PATH via `~/.scripts/cv`) | reads clipboard → nvim in a fresh Ghostty window → copies result back |
| Ghostty config | `config/cv.ghostty` | isolated window behavior (no session restore, no clipboard prompt, close-on-exit); passed with `--config-file` so it never touches the global / cmux Ghostty |
| Alfred workflow | `alfred/cv.workflow.plist` | the `cv` keyword trigger → Run Script `/Users/bmccown/.scripts/cv` |

## How it works

1. `cv` reads `pbpaste`. Empty clipboard → notification + exit.
2. Writes the content to `~/.cache/cv/cv-edit-<ts>.md` (a plain, non-TCC-gated
   path — `$TMPDIR` under `/var/folders` triggers a macOS folder-permission
   prompt, so we avoid it).
3. Writes a self-contained runner script and hands Ghostty's `-e` exactly that
   ONE path. (Passing `-e bash -c "$wrapper" arg…` leaks the extra positional
   args into a shell and spawns a stray login-shell tab — the runner-file form
   avoids that entirely.)
4. Ghostty opens one window running `nvim -c "set number"` (your `~/.config/nvim`
   config + forced line numbers), foregrounded via `osascript … activate`.
5. `:wq` → the buffer is `pbcopy`'d back + a "✎ copied" notification.
   `:cq` (or a nvim error) → abort, clipboard untouched. Tempfiles cleaned up.

## Reproduce on a new machine

- `scripts/cv` + `config/cv.ghostty` come with the dotfiles checkout; `cv` is on
  PATH once `~/.scripts` → `scripts/` is linked (`link.sh`). No extra linking —
  `cv` finds its config by relative path.
- Requires standalone **Ghostty.app** in `/Applications` (falls back to `open -t`
  otherwise, without auto-copy).
- **Alfred workflow** (lives in Alfred's sync folder, not auto-linked):
  1. Alfred Preferences → Workflows → import `alfred/cv.workflow.plist`, OR
  2. re-create: Blank Workflow → **Keyword** input `cv` (no argument) →
     **Run Script** (`/bin/bash`) with body `/Users/bmccown/.scripts/cv` → wire
     them together.
  - Keyword `cv` must not collide with an app Alfred fuzzy-matches (e.g. "DCV
    Viewer" matched `cv` — uninstalled it so `cv` wins).

## Gotchas hit while building

- `env -i` (fully stripped env) made macOS treat the launch as untrusted (TCC
  folder prompt) and slowed cold start. Dropped it — the "lightweight" goal is
  met by the runner's `#!/bin/bash` (non-login, skips zshrc/oh-my-zsh), not by
  nuking the whole process env.
- The stray second tab + leaked `<path>; exit` text were both the `-e bash -c …`
  arg-leak, not a Ghostty window-restore issue — fixed by the single-runner form.
