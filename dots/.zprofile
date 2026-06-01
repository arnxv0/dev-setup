VIM="nvim"
alias vim="nvim"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

addToPath() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$PATH:$1
    fi
}

addToPath $HOME/.local/custom_setup_bin

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

bindkey -s ^f "tmux-sessionizer\n"

_fzf_history_widget() {
    local cmd
    if [[ -f "$HOME/.zsh_history" ]]; then
        cmd=$(sed -E 's/^: [0-9]+:[0-9]+;//' "$HOME/.zsh_history" \
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
        zle accept-line
    fi
}
zle -N _fzf_history_widget
bindkey '^r' _fzf_history_widget

parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'
}
COLOR_DEF='%f'
COLOR_USR='%F{243}'
COLOR_DIR='%F{197}'
COLOR_GIT='%F{39}'
NEWLINE=$'\n'
setopt PROMPT_SUBST
export PROMPT='${COLOR_USR}%n@%M ${COLOR_DIR}%d ${COLOR_GIT}$(parse_git_branch)${COLOR_DEF}${NEWLINE}%% '
