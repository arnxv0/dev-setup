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
  # Use fzf to search history, exclude duplicates with `awk '!a[$0]++'` to ensure unique commands
  local cmd=$(history | awk '!a[$0]++' | fzf --tac --reverse --preview="echo {}" --height=40% --border)

  # If a command was selected, execute it
  if [[ -n "$cmd" ]]; then
    # Extract the actual command part from the output (which includes the history number)
    cmd=$(echo "$cmd" | sed 's/^[ ]*[0-9]*[ ]*//')
    eval "$cmd"
  fi
}

bindkey -s ^r "search_and_run\n"
