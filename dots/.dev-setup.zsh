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

if [[ -n "$TMUX" ]]; then
    # Resolve tmux by absolute path -- $PATH may not carry Homebrew yet.
    _tmuxbin="${commands[tmux]:-}"
    if [[ -z "$_tmuxbin" ]]; then
        for _c in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
            [[ -x "$_c" ]] && _tmuxbin="$_c" && break
        done
        unset _c
    fi
    # MUST pin to $TMUX_PANE: a bare `display -p` resolves against the session's
    # *current* window, so every pane in a restored session would report the
    # same index and silently share one history file.
    _hkey=""
    [[ -n "$_tmuxbin" ]] && _hkey=$("$_tmuxbin" display -t "$TMUX_PANE" -p '#S-#I' 2>/dev/null)
    if [[ -n "$_hkey" ]]; then
        mkdir -p "$HOME/.zsh_history.d"
        HISTFILE="$HOME/.zsh_history.d/${_hkey//\//_}"
    else
        HISTFILE="$HOME/.zsh_history"
    fi
    unset _hkey _tmuxbin
else
    HISTFILE="$HOME/.zsh_history"
fi

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
autoload -Uz add-zsh-hook
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
bindkey '^r' _fzf_history_widget
bindkey '^g' _fzf_history_all_widget
bindkey -s '^f' "tmux-sessionizer\n"
