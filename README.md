# dev-setup

Use this to set it up 
``` bash
chmod +x run.sh
./run.sh
```

The neovim config isn't the best looking, I will refactor it later. (Also, thanks TJ!)

Inspired from [here](https://frontendmasters.github.io/dev-prod-2) and [here](https://github.com/theprimeagen/dev)

## Optional: LLM features

Off unless you ask for them:

```bash
./run.sh --llm      # enable on this machine (remembered; plain ./run.sh keeps it)
./run.sh --no-llm   # disable again (API key file is kept, Ollama not uninstalled)
```

`--llm` installs Ollama, creates `~/.config/dev-setup/secrets.zsh` (mode 600,
never overwritten, never in the repo) and turns on
[minuet-ai.nvim](https://github.com/milanglacier/minuet-ai.nvim) inline
completion in nvim. Put your keys in that file:

```zsh
export ANTHROPIC_API_KEY='...'   # preferred when set
export OPENAI_API_KEY='...'
export MINUET_CLOUD=openai       # prefer OpenAI when both are set
export MINUET_LOCAL_MODEL=qwen3.8-coder:latest
```

The backend is picked automatically and re-checked every 30s: cloud when a key
is set and the API is reachable, the local Ollama model when offline or keyless,
and paused if neither is available. The statusline shows `AI:claude`,
`AI:openai`, `AI:local` or `AI:none`. `:MinuetAuto` pins the current choice.

| | |
|---|---|
| `Alt-A` / `Alt-a` | accept suggestion / accept one line |
| `Alt-z` | accept N lines (type a count, then Enter) |
| `Alt-]` / `Alt-[` | next / previous suggestion (or request one) |
| `Alt-e` | dismiss |

Copilot stays installed but is off while LLM features are enabled
(`:Copilot enable` for a session). `llm-history` views and deletes local
Qwen Code / Ollama conversation data.

## tmux session persistence

Sessions, window layouts, working directories and — critically — which Claude
Code conversation each pane was running are captured automatically and restored
**selectively**, one project at a time.

| | |
|---|---|
| `prefix + f` | fzf a project. If it's in the snapshot the session is rebuilt (windows, cwds, `nvim`, `claude --resume <id>`); otherwise you get a fresh session. |
| `prefix + o` | jump to the previous session, like nvim's `Ctrl-^` for files |
| `prefix + c` / `"` / `%` | new window / split, opened in the current pane's folder |
| `prefix + S` | snapshot now (otherwise automatic every 15 min) |
| `prefix + Ctrl-s` | tmux-resurrect save |
| `^r` / `^g` | fzf this pane's history / every pane's history |

```bash
tmux-snapshot                      # capture now
tmux-restore --list                # what's saved, what's already live
tmux-restore --dry-run <session>   # show without doing
tmux-restore <session>             # rebuild one project
```

A pane whose command is only **typed and not run** keeps it. Restore a project,
press Enter in the one pane you need, and the rest still come back next time
with their command waiting — including commands the snapshot could never
reconstruct, like a leftover `npm run dev`. Two mechanisms:

- the exact prompt line is recorded per pane (`pending`), and re-typed verbatim
- a Claude pane's session id is carried forward even while it sits idle, so the
  conversation stays findable (`carried-pane` in the snapshot)

Live sessions are never clobbered — `tmux-restore` skips anything already
running. Snapshots live in `~/.local/share/tmux-state/`, outside the repo,
since they contain absolute paths and session ids.

Claude transcripts in `~/.claude/projects/` already survive reboots on their
own; what the snapshot preserves is the *mapping* from pane to conversation,
which nothing else records and which cannot be reconstructed once the pane is
gone.

### Per-window shell history

Each tmux window gets its own history file in `~/.zsh_history.d/`, keyed on
session name + window index, with everything also mirrored to
`~/.zsh_history_all` for cross-project search.

This lives in `dots/.dev-setup.zsh`, sourced from `~/.zshrc` — **not**
`.zprofile`. macOS `/etc/zshrc` runs after `.zprofile` and resets
`HISTFILE`/`HISTSIZE`/`SAVEHIST`, so history settings placed there never take
effect.

## Re-running setup

`./run.sh` is idempotent. For each tracked item it installs what's missing,
reports what already matches, and **refuses to overwrite anything that
differs**:

```bash
./scripts/setup-dots.sh --check              # report only
./scripts/setup-dots.sh                      # install missing only
./scripts/setup-dots.sh --force --only X     # apply one item, with a backup
```

A manifest at `~/.local/share/dev-setup/manifest` records the hash of each item
as installed, which is what distinguishes:

- **OK** — matches the repo
- **REPO-NEWER** — you still have exactly what was installed; the repo moved on
- **LOCAL-EDIT** — matches neither; changed by hand, never touched without `--force`
- **UNTRACKED** — differs and was never recorded, so it can't be attributed

Backups go to `~/.local/share/dev-setup/backup-<timestamp>/`. `~/.zshrc` is
never replaced — setup only appends one guarded `source` line if absent.
