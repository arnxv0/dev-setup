# dev-setup: history + fzf history widgets
#
# THIS MUST BE SOURCED FROM ~/.zshrc, NOT ~/.zprofile.
# macOS ships /etc/zshrc, which runs AFTER ~/.zprofile and unconditionally sets
#   HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
#   HISTSIZE=2000
#   SAVEHIST=1000
# so anything set in .zprofile is silently overwritten. ~/.zshrc runs after
# /etc/zshrc, which is the first point where these values stick.

# ── per-window history ───────────────────────────────────────────────────────
# One history file per tmux window, so each project keeps its own commands
# instead of 100+ panes clobbering a single global file.
#
# Keyed on session name + window index, NOT $TMUX_PANE: pane ids (%47) are
# reassigned when a session is restored, which would orphan every history file
# on the first restart. session+window is what a restore rebuilds.
HISTSIZE=50000
SAVEHIST=50000

# Resolving the key needs a `tmux display` call, and that MUST NOT happen while
# the shell is starting up. tmux's server is single-threaded: a shell it is
# spawning that asks the server a question can block until the server finishes
# creating that very pane -- which it cannot, because it is waiting on the
# shell. The result is a new pane (prefix+c) that hangs until Ctrl-C.
#
# So default to the global file, then resolve the real one on the FIRST prompt,
# by which point new-window has returned and the server is free.
HISTFILE="$HOME/.zsh_history"

autoload -Uz add-zsh-hook

_devsetup_resolve_histfile() {
    # one-shot: unhook immediately so this never costs anything again
    add-zsh-hook -d precmd _devsetup_resolve_histfile
    [[ -n "$TMUX" ]] || return 0

    local tmuxbin="${commands[tmux]:-}"
    if [[ -z "$tmuxbin" ]]; then
        local c
        for c in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
            [[ -x "$c" ]] && tmuxbin="$c" && break
        done
    fi
    [[ -n "$tmuxbin" ]] || return 0

    # MUST pin to $TMUX_PANE: a bare `display -p` resolves against the
    # session's *current* window, so every pane in a restored session would
    # report the same index and silently share one history file.
    local key
    key=$("$tmuxbin" display -t "$TMUX_PANE" -p '#S-#I' 2>/dev/null) || return 0
    [[ -n "$key" ]] || return 0

    mkdir -p "$HOME/.zsh_history.d" 2>/dev/null || return 0
    HISTFILE="$HOME/.zsh_history.d/${key//\//_}"
    # zsh already read the global file at startup; load this pane's own history
    # now that we know which file it is.
    fc -R "$HISTFILE" 2>/dev/null
}
add-zsh-hook precmd _devsetup_resolve_histfile

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

# ── global mirror ────────────────────────────────────────────────────────────
# Every command also lands in one file so cross-project search still works
# (^g). Guarded so a bare Enter does not re-append the previous command.
HISTALL="$HOME/.zsh_history_all"
_hist_mirror() {
    local last
    last=$(fc -ln -1 2>/dev/null)
    [[ -n "$last" && "$last" != "$_hist_mirror_prev" ]] || return
    _hist_mirror_prev="$last"
    print -r -- "$last" >> "$HISTALL"
}
add-zsh-hook precmd _hist_mirror

# ── fzf history pickers ──────────────────────────────────────────────────────
_fzf_pick_into_buffer() {
    local src="$1" cmd
    if [[ -f "$src" ]]; then
        cmd=$(sed -E 's/^: [0-9]+:[0-9]+;//' "$src" \
              | awk '!a[$0]++' \
              | fzf --tac --reverse --preview="echo {}" --height=40% --border)
    else
        cmd=$(history | sed 's/^[ ]*[0-9]*[ ]*//' \
              | awk '!a[$0]++' \
              | fzf --tac --reverse --preview="echo {}" --height=40% --border)
    fi
    if [[ -n "$cmd" ]]; then
        BUFFER="$cmd"
        CURSOR=${#BUFFER}
        zle redisplay
    fi
}
_fzf_history_widget()     { _fzf_pick_into_buffer "$HISTFILE" }   # this pane
_fzf_history_all_widget() { _fzf_pick_into_buffer "$HISTALL" }    # everything

zle -N _fzf_history_widget
zle -N _fzf_history_all_widget
# ^r = this pane. Alt-r = every pane.
# NOT ^g: that is zsh's send-break (abort the current line) and stealing it
# breaks a reflex people rely on. ^[r is undefined-key by default.
bindkey '^r' _fzf_history_widget
bindkey '^[r' _fzf_history_all_widget
bindkey -s '^f' "tmux-sessionizer\n"
