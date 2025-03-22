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

