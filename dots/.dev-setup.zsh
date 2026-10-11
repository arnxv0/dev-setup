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
# (Alt-r). Guarded so a bare Enter does not re-append the previous command.
HISTALL="$HOME/.zsh_history_all"
_hist_mirror() {
    local last
    last=$(fc -ln -1 2>/dev/null)
    [[ -n "$last" && "$last" != "$_hist_mirror_prev" ]] || return
    _hist_mirror_prev="$last"
    print -r -- "$last" >> "$HISTALL"
}
add-zsh-hook precmd _hist_mirror

# ── fzf history pickers ──────────────────────────────────────────────────
# Two pickers: this window, and every shell that has ever run on this machine.
#
# "Every shell" has to mean more than $HISTALL. The mirror only starts at the
# moment this hook is installed, and before that /etc/zshrc held SAVEHIST at
# 1000 -- so the old global file is a 300-line stub, not years of history. The
# all-shells picker therefore unions every file zsh has ever written here:
#
#   .zsh_history_all    our mirror: every command since the hook landed
#   .zsh_history        the pre-hook global file, capped at 1000 by /etc/zshrc
#   .zsh_history.d/*    the per-window files this hook creates
#   .zsh_sessions/*     macOS's own per-session history, written by
#                       /etc/zshrc_Apple_Terminal. macOS expires these, so
#                       anything here is on borrowed time.
#
# Reading them at keypress rather than merging once means a new source (a new
# window, a restored session) is picked up with no bookkeeping.

# Normalise zsh history into "most recent timestamp<TAB>command", one line per
# distinct command. Entries carry a `: <epoch>:<duration>;` prefix under
# EXTENDED_HISTORY and nothing under the plain format, so both are handled.
# LC_ALL=C throughout: these files contain invalid UTF-8 (truncated multi-byte
# characters from killed commands) and GNU/BSD tools abort on it otherwise.
_devsetup_hist_filter() {
    LC_ALL=C awk '
        {
            ts = 0
            line = $0
            if (match(line, /^: [0-9]+:[0-9]+;/)) {
                ts = substr(line, 3)
                sub(/:.*/, "", ts)
                line = substr(line, RLENGTH + 1)
            }
            if (line == "") next
            if (!(line in best) || ts + 0 > best[line] + 0) best[line] = ts
        }
        END { for (l in best) printf "%s\t%s\n", best[l], l }
    ' | LC_ALL=C sort -n -k1,1 | LC_ALL=C cut -f2-
}

# Takes history files as arguments; missing ones are skipped. With none left,
# falls back to the shell's in-memory history so the key never does nothing.
_fzf_pick_into_buffer() {
    local -a present
    local f cmd
    for f in "$@"; do
        [[ -n "$f" && -f "$f" ]] && present+=("$f")
    done

    if (( ${#present} )); then
        cmd=$(LC_ALL=C cat -- "${present[@]}" 2>/dev/null \
              | _devsetup_hist_filter \
              | fzf --tac --reverse --preview="echo {}" --height=40% --border)
    else
        cmd=$(history | LC_ALL=C sed 's/^[ ]*[0-9]*[ ]*//' \
              | LC_ALL=C awk '!a[$0]++' \
              | fzf --tac --reverse --preview="echo {}" --height=40% --border)
    fi

    if [[ -n "$cmd" ]]; then
        BUFFER="$cmd"
        CURSOR=${#BUFFER}
        zle redisplay
    fi
}

_fzf_history_widget() { _fzf_pick_into_buffer "$HISTFILE" }

_fzf_history_all_widget() {
    # (N) is nullglob: a missing directory expands to nothing instead of erroring.
    _fzf_pick_into_buffer "$HISTALL" "$HOME/.zsh_history" \
        "$HOME"/.zsh_history.d/*(N) "$HOME"/.zsh_sessions/*.history(N)
}

zle -N _fzf_history_widget
zle -N _fzf_history_all_widget
# ^r = this window. Alt-r = every shell, ever.
#
# NOT ^g: that is zsh's send-break (abort the current line) and stealing it
# breaks a reflex people rely on. ^[r is undefined-key by default.
#
# Alt-r needs the terminal to send Option as Esc. Ghostty does not by default
# -- Option-r types ® -- so dots/.config/ghostty/config sets
# `macos-option-as-alt = left`. ^x^r is bound to the same widget as a
# terminal-independent fallback, for any terminal without that setting.
bindkey '^r' _fzf_history_widget
bindkey '^[r' _fzf_history_all_widget
bindkey '^x^r' _fzf_history_all_widget
bindkey -s '^f' "tmux-sessionizer\n"
