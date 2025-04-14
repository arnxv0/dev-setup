VIM="nvim"
alias vim="nvim"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


addToPath() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$PATH:$1
    fi
}

addToPath $HOME/.local/custom_setup_bin


bindkey -s ^f "tmux-sessionizer\n"

search_and_run() {
    local cmd

    if [[ -n "$ZSH_VERSION" && -f "$HOME/.zsh_history" ]]; then
        # Zsh: clean metadata
        cmd=$(sed -E 's/^: [0-9]+:[0-9]+;//' "$HOME/.zsh_history" | awk '!a[$0]++' | \
              fzf --tac --reverse --preview="echo {}" --height=40% --border)
    elif [[ -n "$BASH_VERSION" && -f "$HOME/.bash_history" ]]; then
        # Bash: plain lines
        cmd=$(cat "$HOME/.bash_history" | awk '!a[$0]++' | \
              fzf --tac --reverse --preview="echo {}" --height=40% --border)
    else
        # Fallback for other shells
        cmd=$(history | sed 's/^[ ]*[0-9]*[ ]*//' | awk '!a[$0]++' | \
              fzf --tac --reverse --preview="echo {}" --height=40% --border)
    fi

    if [[ -n "$cmd" ]]; then
        eval "$cmd"
    fi
}

bindkey -s ^r "search_and_run\n"

parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'
}
COLOR_DEF='%f'
COLOR_USR='%F{243}'
COLOR_DIR='%F{197}'
COLOR_GIT='%F{39}'
# About the prefixed `$`: https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_03.html#:~:text=Words%20in%20the%20form%20%22%24',by%20the%20ANSI%2DC%20standard.
NEWLINE=$'\n'
# Set zsh option for prompt substitution
setopt PROMPT_SUBST
export PROMPT='${COLOR_USR}%n@%M ${COLOR_DIR}%d ${COLOR_GIT}$(parse_git_branch)${COLOR_DEF}${NEWLINE}%% '
