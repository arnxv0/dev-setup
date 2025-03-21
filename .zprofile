[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Fuzzy find command history and execute it
fzf_run_command() {
    selected_command=$(history | fzf --tac | sed -E 's/^[ ]*[0-9]+[ ]*//')
    if [ -n "$selected_command" ]; then
        eval "$selected_command"
    fi
}

# Register the function as a Zsh widget
zle -N fzf_run_command

# Bind Ctrl + R to invoke fzf_run_command function
bindkey '^R' fzf_run_command

